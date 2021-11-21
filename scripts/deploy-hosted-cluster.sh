#!/bin/bash

set -xe

source scripts/common.sh
source scripts/utils.sh
source scripts/order-vpc.sh
source scripts/basic-validation-test.sh
source scripts/e2e-test.sh
export MOLECULE_CMD_TO_RUN=${MANAGED_CLUSTER_TYPE:-openshift}-cluster
cd ../armada-openshift-master || return 1
echo "Prepare hypershift deploy.."
run_cmd "Running Prepare" "molecule prepare --force -s ${MOLECULE_CMD_TO_RUN}"
echo "1" >"/tmp/${TEST_CLUSTER_ID}.status"
echo "Converge hypershift deploy.."
run_cmd "Running Converge" "molecule converge -s ${MOLECULE_CMD_TO_RUN}"
echo "Verify hypershift deploy.."
cd ../armada-openshift-master || return 1
#run_cmd "Running Verify" "molecule verify -s ${MOLECULE_CMD_TO_RUN}"
USER_CLUSTER_KUBECONFIG="$(pwd)/lib/roks4/pki/admin.kubeconfig"
export USER_CLUSTER_KUBECONFIG
cd ../rhcos-vpcgen2-ignitiondata
source scripts/deploy-ignition-server.sh
deploy_config_server
source scripts/add-rhcos-worker-node.sh
add_node_to_cluster
unset INSTANCE_NAME
add_node_to_cluster
find_ibm_pr_link
check_cluster
if [[ "$EXECUTE_OPENSHIFT_E2E" == "true" ]]; then
	e2e_setup "$KUBECONFIG_PATH/admin.kubeconfig"
	run_e2e "$KUBECONFIG_PATH/admin.kubeconfig"
fi
