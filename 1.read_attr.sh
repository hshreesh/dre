#!/bin/sh
proj=$1
kmz=$2

v.import "$kmz" out=${proj}_kmz
for i in $(v.db.connect  ${proj}_kmz -g | sed 's#/.*##'); do
	v.to.rast ${proj}_kmz out=${proj}_kmz_$i use=cat layer=$i --o
done
for i in $(
	for i in $(v.db.connect  ${proj}_kmz -g | sed 's#/.*##'); do
		count=$(r.stats -cn ${proj}_kmz_$i | awk '{a+=$2}END{print a}')
		[ "$count" = "" ] || echo "$i $count"
	done 2> /dev/null | awk '{print $1}'
	); do
	echo "==== $i ===="; v.db.select ${proj}_kmz layer=$i
done
