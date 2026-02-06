#!/bin/sh
set -e

union=prism_4km_NFWF_union

# create the union of PRISM and watershed shapefile
v.overlay ainput=prism_4km_grid binput=site_shp oper=and output=$union --overwrite
# calculate the area of each irregular rectangle
v.to.db $union op=area col=subbasin_cell_area
