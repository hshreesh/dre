#!/bin/sh
set -e

# set the region to PRISM
eval $(g.region rast=$(g.list rast pat=PRISM* | head -1) -apg | sed  '/rows\|cols/!d')
# create PRISM grid
v.mkgrid prism_4km_grid grid=$rows,$cols --overwrite
