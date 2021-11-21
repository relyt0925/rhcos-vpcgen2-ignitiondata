#!/bin/bash

set -xe

source scripts/common.sh

cd ../armada-openshift-master
#Run Destroy
if [ -f "/tmp/${TEST_CLUSTER_ID}.status" ]; then
	export MOLECULE_CMD_TO_RUN=${MANAGED_CLUSTER_TYPE:-openshift}-cluster
	run_cmd "Running Destroy" "molecule destroy -s ${MOLECULE_CMD_TO_RUN}"
else
	echo "Hosted Cluster ${TEST_CLUSTER_ID} not created"
fi
