#!/bin/sh
proj=$1
# 8,0.06 14,0.11
shift

for i; do
	layer=$(echo $i | cut -d, -f1)
	n=$(echo $i | cut -d, -f2)
	r.mapcalc ex="${proj}_n_$layer=if(isnull(${proj}_kmz_$layer),null(),$n)" --o
done

r.patch input=$(g.list rast pat=${proj}_n_* sep=comma) output=${proj}_n_post_only --o
r.mapcalc ex="${proj}_n_post=if(isnull(${proj}_n_post_only),n_low,${proj}_n_post_only)" --o
