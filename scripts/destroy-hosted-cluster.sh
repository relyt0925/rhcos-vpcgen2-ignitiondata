#!/bin/bash

set -xe

source scripts/common.sh

#Run Destroy
if [ -f "/tmp/${TEST_CLUSTER_ID}.status" ]; then
    run_cmd "Running Destroy" "molecule destroy -s openshift-cluster"
else
    echo "Hosted Cluster ${TEST_CLUSTER_ID} not created"
fi
