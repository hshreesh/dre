# Rio Grande Project Drought Resilience Efforts (DRE) Initiative

Modeling for the Rio Grande Project Drought Resilience Efforts (DRE) Initiative

## Repo overview

This repo contains a minimal setup for running a rainfall/runoff workflow with gridded inputs.

- `run.sh`  
  main runner script containing the shell commands for running grass modules in sequence.

- `data/`  
  rainfall depth inputs (text files), e.g. `rain_1h_depths.txt`, `rain_24h_depths.txt`.

- `spatial_data/`  
  geospatial rasters used by the workflow:
  - `dem.tif`: original dem
  - `dem_modified.tif`: processed dem used for modeling
  - `esa.tif`: land cover raster
  - `n_low.tif`: manning n (low roughness) raster
  - `hsg.md`: notes/metadata for hydrologic soil group inputs

- `LICENSE`  
  project license.
  
  
## PRISM rainfall processing workflow

This repo also includes a GRASS + Bash + R workflow to download PRISM climate rasters and compute area-weighted watershed time series for precipitation and temperature.

### Scripts

- `import_prism_rasters.sh` — import PRISM zip rasters into GRASS  
- `create_prism_grid_4km.sh` — build PRISM 4 km grid vector  
- `union_prism_area_grid.sh` — intersect grid with watershed and compute cell areas  
- `calc_weighted_avg_prism.sh` — compute area-weighted daily ppt/tmax/tmin  
- `prec_analysis.R` — precipitation statistics and plots

### Run order

Run inside an active GRASS GIS session:

```bash
# 1. Download PRISM rasters
m.prism.download dataset=0,2,4 start_date=1990-01-01 end_date=2023-12-31

# 2. Import and process
bash import_prism_rasters.sh
sh create_prism_grid_4km.sh
sh union_prism_area_grid.sh
sh calc_weighted_avg_prism.sh

# 3. R analysis
Rscript prec_analysis.R

## SIMWE discharge sum along a user-defined line (GRASS + Bash)

This repo includes a Bash script that automates a SIMWE (`r.sim.water`) run and then computes the **sum of discharge raster values** within a buffered corridor around a **line defined by two coordinates**.

### What it does

Given gridded inputs (DEM, dx, dy, Manning’s n) and a rainfall intensity:

1. Runs `r.sim.water` to generate depth and discharge rasters.
2. Builds a 2-point line vector from `(x1, y1)` → `(x2, y2)`.
3. Buffers the line **as a vector polygon** (robust for short lines).
4. Rasterizes the buffered polygon to create a mask.
5. Extracts discharge values where the mask is present.
6. Calculates the **sum** of extracted discharge values for the **last output timestep** (equal to `niterations`).

> Note: The “last timestep” discharge map `q_<outprefix>.<niterations>` exists only if `niterations` is a multiple of `output_step`.

### Script

- `simw_line_sum_pure.sh` — pure Bash (no `g.parser`) SIMWE + line-buffer + discharge-sum workflow

### Requirements

- GRASS GIS (with `r.sim.water`, `v.in.ascii`, `v.buffer`, `v.to.rast`, `r.mapcalc`, `r.univar`)
- A GRASS Location/Mapset containing the rasters:
  - `elevation` (DEM)
  - `dx`, `dy`
  - `man` (Manning’s n raster or constant)
- Coordinates `x1,y1,x2,y2` in the **same CRS** as your GRASS Location.

### Usage

Run inside an active GRASS session:

```bash
chmod +x simw_line_sum_pure.sh

./simw_line_sum_pure.sh \
  elevation=dem_3m_mod dx=dx_mod dy=dy_mod man=n_low \
  rain=23 niterations=60 output_step=60 nprocs=4 \
  outprefix=2y1h_mod \
  x1=-1030077.451885954 y1=1125099.4959982967 \
  x2=-1030095.7392827778 y2=1125112.068581797 \
  buffer=3
