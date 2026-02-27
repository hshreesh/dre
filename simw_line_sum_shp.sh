#!/usr/bin/env bash
# Pure bash GRASS workflow (no g.parser):
# - Run r.sim.water once
# - Import one shapefile containing 3 line features
# - Extract each line feature
# - Buffer each line as vector polygon
# - Rasterize each buffer
# - Extract discharge at last timestep (niterations)
# - Print individual sums and total sum

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  simw_line_sum_1shp_3lines.sh elevation=RASTER dx=RASTER dy=RASTER man=MAP_OR_VALUE rain=FLOAT \
    niterations=INT output_step=INT nprocs=INT outprefix=NAME \
    lines=/path/to/3lines.shp buffer=FLOAT

Example:
  ./simw_line_sum_1shp_3lines.sh elevation=dem_3m_mod dx=dx_mod dy=dy_mod man=n_low rain=23 \
    niterations=60 output_step=60 nprocs=4 outprefix=2y1h_mod \
    lines=lines/three_locations.shp buffer=3
EOF
}

# ---- Parse key=value args (pure bash) ----
man="n_low"
buffer="3"

for arg in "$@"; do
  case "$arg" in
    elevation=*)   elevation="${arg#*=}" ;;
    dx=*)          dx="${arg#*=}" ;;
    dy=*)          dy="${arg#*=}" ;;
    man=*)         man="${arg#*=}" ;;
    rain=*)        rain="${arg#*=}" ;;
    niterations=*) niterations="${arg#*=}" ;;
    output_step=*) output_step="${arg#*=}" ;;
    nprocs=*)      nprocs="${arg#*=}" ;;
    outprefix=*)   outprefix="${arg#*=}" ;;
    lines=*)       lines="${arg#*=}" ;;
    buffer=*)      buffer="${arg#*=}" ;;
    --help|-h)     usage; exit 0 ;;
    *)
      echo "ERROR: Unknown argument: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

# ---- Required checks ----
need() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: Missing required argument: ${name}=..." >&2
    usage
    exit 2
  fi
}

need elevation
need dx
need dy
need rain
need niterations
need output_step
need nprocs
need outprefix
need lines
need buffer

if [ ! -f "$lines" ]; then
  echo "ERROR: Shapefile not found: $lines" >&2
  exit 2
fi

# Make sure we are inside GRASS
if ! command -v g.region >/dev/null 2>&1; then
  echo "ERROR: GRASS commands not found. Run inside GRASS or via 'grass ... --exec'." >&2
  exit 3
fi

# ---- Names for SIMWE outputs ----
depth_base="depth_${outprefix}"
q_base="q_${outprefix}"
last_t="${niterations}"
q_map="${q_base}.${last_t}"

# Imported line shapefile (all 3 features)
lines_all_vec="lines_all_${outprefix}"

# ---- 1) Run r.sim.water ----
r.sim.water -t \
  elevation="${elevation}" \
  dx="${dx}" \
  dy="${dy}" \
  rain_value="${rain}" \
  man="${man}" \
  depth="${depth_base}" \
  discharge="${q_base}" \
  niterations="${niterations}" \
  output_step="${output_step}" \
  nprocs="${nprocs}" \
  --o

# ---- 2) Check discharge raster exists ----
if ! g.findfile element=cell file="${q_map}" >/dev/null 2>&1; then
  echo "ERROR: Expected discharge raster '${q_map}' not found." >&2
  echo "Tip: r.sim.water outputs only at output_step intervals; last map exists only if niterations is a multiple of output_step." >&2
  echo "Available discharge maps:" >&2
  g.list type=raster pattern="${q_base}.*" >&2
  exit 4
fi

# ---- 3) Import shapefile with 3 line features ----
# v.import handles reprojection into current GRASS location if needed
v.import input="${lines}" output="${lines_all_vec}" --o

# Optional sanity check: confirm 3 line features exist
line_count="$(v.info -t "${lines_all_vec}" | awk -F= '$1=="lines"{print $2}')"
if [ "${line_count:-0}" -ne 3 ]; then
  echo "ERROR: Expected 3 line features in '${lines}', but found lines=${line_count:-0}." >&2
  echo "Check the shapefile geometry and feature count." >&2
  exit 5
fi

# Get the internal GRASS category IDs (cat) for the three features
# (v.import usually creates/maintains a table with 'cat')
mapfile -t cats < <(
  v.db.select -c map="${lines_all_vec}" columns=cat 2>/dev/null \
    | awk 'NF' \
    | sort -n \
    | uniq
)

if [ "${#cats[@]}" -ne 3 ]; then
  echo "ERROR: Could not determine exactly 3 feature categories from '${lines_all_vec}'." >&2
  echo "Found cats: ${cats[*]:-(none)}" >&2
  exit 6
fi

# ---- 4) Align region to discharge raster grid ----
#g.region raster="${q_map}"

# ---- 5) Process each line feature ----
declare -a line_sums
total_sum="0"

for idx in $(seq 0 2); do
  i=$((idx + 1))
  cat_id="${cats[$idx]}"

  # Names for this feature
  line_vec="line${i}_${outprefix}"
  line_buf_vec="line${i}buf_${outprefix}"
  buf_rast="buf_${buffer}m_line${i}_${outprefix}"
  q_on_buf="q_on_buf_line${i}_${outprefix}.${last_t}"

  # Extract one line feature by category
  v.extract input="${lines_all_vec}" output="${line_vec}" cats="${cat_id}" --o

  # Buffer vector line -> raster mask
  v.buffer input="${line_vec}" output="${line_buf_vec}" distance="${buffer}" --o
  v.to.rast input="${line_buf_vec}" output="${buf_rast}" use=val value=1 --o

  # Ensure buffer raster is not empty
  buf_n="$(r.univar -g "${buf_rast}" 2>/dev/null | awk -F= '$1=="n"{print $2}')"
  if [ "${buf_n:-0}" -eq 0 ]; then
    echo "WARNING: Buffer raster '${buf_rast}' is empty. Setting line${i} sum = 0." >&2
    line_sums[$idx]="0"
    continue
  fi

  # Extract discharge values inside buffer
  r.mapcalc "${q_on_buf} = if(!isnull(${buf_rast}), ${q_map}, null())" --o

  # Get stats (handle no-overlap as 0)
  stats="$(r.univar -g "${q_on_buf}" 2>/dev/null || true)"
  q_n="$(printf '%s\n' "${stats}" | awk -F= '$1=="n"{print $2}')"
  q_sum="$(printf '%s\n' "${stats}" | awk -F= '$1=="sum"{print $2}')"

  if [ "${q_n:-0}" -eq 0 ] || [ -z "${q_sum:-}" ] || [ "${q_sum}" = "nan" ]; then
    echo "WARNING: No non-NULL discharge overlap for line${i} (cat=${cat_id}). Setting sum = 0." >&2
    q_sum="0"
  fi

  line_sums[$idx]="${q_sum}"

  # Floating-point accumulation
  total_sum="$(awk -v a="${total_sum}" -v b="${q_sum}" 'BEGIN{printf "%.15g", a+b}')"
done

# ---- 6) Print results ----
echo "line1_cat=${cats[0]}"
echo "line1_sum=${line_sums[0]:-0}"
echo "line2_cat=${cats[1]}"
echo "line2_sum=${line_sums[1]:-0}"
echo "line3_cat=${cats[2]}"
echo "line3_sum=${line_sums[2]:-0}"
echo "total_sum=${total_sum}"
