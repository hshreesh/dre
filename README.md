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
