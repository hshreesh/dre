#!/bin/bash

for zip in *.zip; do
	unzip $zip
	bil=$(echo $zip | sed 's/zip$/bil/')
	output_name=$(echo $bil | sed 's/.bil//g; s/_\(provisional\|stable\)//')
#	echo $output_name
	r.import input="$bil" output="$output_name" --overwrite
done
