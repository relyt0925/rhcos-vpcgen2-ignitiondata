#!/bin/bash

set -xe

source scripts/common.sh

echo "Prepare hypershift deploy.."
run_cmd "Running Prepare" "molecule prepare --force -s openshift-cluster"
echo "1" > "/tmp/${TEST_CLUSTER_ID}.status"
echo "Converge hypershift deploy.."
run_cmd "Running Converge" "molecule converge -s openshift-cluster"
echo "Verify hypershift deploy.."
#run_cmd "Running Verify" "molecule verify -s openshift-cluster"

cd ../rhcos-vpcgen2-ignitiondata
source scripts/deploy-ignition-server.sh
deploy_config_server