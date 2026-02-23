#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  simw_line_sum_pure.sh elevation=RASTER dx=RASTER dy=RASTER man=MAP_OR_VALUE rain=FLOAT \
    niterations=INT output_step=INT nprocs=INT outprefix=NAME \
    x1=FLOAT y1=FLOAT x2=FLOAT y2=FLOAT buffer=FLOAT

Example:
  ./simw_line_sum_pure.sh elevation=dem_3m_mod dx=dx_mod dy=dy_mod man=n_low rain=23 \
    niterations=60 output_step=60 nprocs=4 outprefix=2y1h_mod \
    x1=-1030077.45 y1=1125099.50 x2=-1030095.74 y2=1125112.07 buffer=3
EOF
}

# Defaults (optional)
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
    x1=*)          x1="${arg#*=}" ;;
    y1=*)          y1="${arg#*=}" ;;
    x2=*)          x2="${arg#*=}" ;;
    y2=*)          y2="${arg#*=}" ;;
    buffer=*)      buffer="${arg#*=}" ;;
    --help|-h)     usage; exit 0 ;;
    *)
      echo "ERROR: Unknown argument: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

# Required checks
need() { # need varname
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
need x1
need y1
need x2
need y2
need buffer

# Make sure we are inside GRASS
if ! command -v g.region >/dev/null 2>&1; then
  echo "ERROR: GRASS commands not found. Run inside GRASS or via 'grass ... --exec'." >&2
  exit 3
fi

depth_base="depth_${outprefix}"
q_base="q_${outprefix}"
last_t="${niterations}"
q_map="${q_base}.${last_t}"

line_vec="line_${outprefix}"
line_buf_vec="linebuf_${outprefix}"
buf_rast="buf_${buffer}m_${outprefix}"
q_on_buf="q_on_buf_${outprefix}.${last_t}"

# Run r.sim.water
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

# Check discharge raster exists (robust)
if ! g.findfile element=cell file="${q_map}" >/dev/null 2>&1; then
  echo "ERROR: Expected discharge raster '${q_map}' not found." >&2
  echo "Tip: r.sim.water outputs only at output_step intervals; last map exists only if niterations is a multiple of output_step." >&2
  echo "Available discharge maps:" >&2
  g.list type=raster pattern="${q_base}.*" >&2
  exit 4
fi

# Create 2-point line vector (NO temp file; stdin pipe)
printf 'L 2\n%s %s\n%s %s\n' "$x1" "$y1" "$x2" "$y2" | \
  v.in.ascii -n input=- output="${line_vec}" format=standard --o

# Set region to discharge raster grid
g.region raster="${q_map}"

# Buffer VECTOR line then rasterize buffer polygon
v.buffer input="${line_vec}" output="${line_buf_vec}" distance="${buffer}" --o
v.to.rast input="${line_buf_vec}" output="${buf_rast}" use=val value=1 --o

# Ensure buffer raster is not empty
buf_n="$(r.univar -g "${buf_rast}" 2>/dev/null | awk -F= '$1=="n"{print $2}')"
if [ "${buf_n:-0}" -eq 0 ]; then
  echo "ERROR: Buffer raster '${buf_rast}' has no cells (all NULL). Check coords/buffer." >&2
  exit 5
fi

# Extract discharge values inside buffer
r.mapcalc "${q_on_buf} = if(!isnull(${buf_rast}), ${q_map}, null())" --o

# Sum
r.univar -g "${q_on_buf}" | grep '^sum='
