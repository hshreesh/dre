#!/bin/sh
set -e

union=prism_4km_NFWF_union
centers=centers_NFWF_prism_4km
v.centerpoint $union out=$centers
v.db.addcolumn $union col="prism_value double"


for i in ppt tmax tmin; do
	echo "date,value" > NFWF_$i.txt
	for rast in $(g.list rast pat=PRISM_${i}_*); do
		v.what.rast $centers rast=$rast col=prism_value
		v.db.update $union col=prism_value qcol="(select prism_value from $centers where $union.cat=$centers.cat)"
		date=$(echo $rast | sed 's/.*_//')
		db.select -c "select $date,sum(prism_value * subbasin_cell_area) / sum(subbasin_cell_area) from $union" sep=comma >> NFWF_$i.txt
	done
done
