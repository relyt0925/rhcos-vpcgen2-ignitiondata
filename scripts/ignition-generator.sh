#!/usr/bin/env bash

set -xe

process() {
	# Create output file path and the file
	final_file="tmp/machine-configs/"$(basename "$1")
	mkdir -p tmp/machine-configs
	cp "$1" "$final_file"
	spruce merge "$final_file" >"$final_file.based"
	rm "$final_file"
}

#Run for each base template filefile and create Level 1 spruced file with base64 contents
# shellcheck disable=SC2045
for file in $(ls machine-config-templates); do
	process "machine-config-templates/$file"
done
# For testing uncomment the line below and it'll do local templating. Don't commit the uncomment change
#spruce merge services/rhcos-vpcgen2-ignitiondata/deployment.yaml > services/rhcos-vpcgen2-ignitiondata/production.yaml
