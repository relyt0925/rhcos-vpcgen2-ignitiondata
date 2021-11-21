#!/bin/bash
set -xe
# shellcheck disable=SC1091
source scripts/order-vpc.sh
source scripts/e2e-test.sh

template_bootstrap_worker_metadata() {
	export BOOTSTRAP_WORKER_FILE_PATH=/tmp/ibm-bootstrap-worker-metdata-cm
	cat <<EOF >$BOOTSTRAP_WORKER_FILE_PATH
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-machinemetadata-$INSTANCE_NAME
  namespace: openshift-infra
data:
  providerid: "ibm://accountid1///$TEST_CLUSTER_ID/$INSTANCE_NAME"
EOF
}

get_user_data() {
	export USERDATA_FILE_PATH="/tmp/userdata-$TEST_CLUSTER_ID"
	# clear existing secrets out
	kubectl get secret -n "master-$TEST_CLUSTER_ID" | grep "user-data-$TEST_CLUSTER_ID" | awk '{print $1}' | xargs -I {} kubectl delete secret -n "master-$TEST_CLUSTER_ID" {}
	#give time for secret to regenerate
	sleep 30
	user_data_secret=$(kubectl get secret -n "master-$TEST_CLUSTER_ID" | grep user-data | awk '{print $1;}')
	kubectl get secret -n "master-$TEST_CLUSTER_ID" "$user_data_secret" -o jsonpath='{.data.value}' | base64 --decode >"$USERDATA_FILE_PATH"
	if [ -s "$USERDATA_FILE_PATH" ]; then
		echo "user data successfully exported"
	else
		echo "user data is empty"
		return 1
	fi
	return 0

}

add_node_to_cluster() {
	get_user_data
	if [[ -z "$INSTANCE_NAME" ]]; then
		INSTANCE_NAME="bpr-${TEST_CLUSTER_ID}-$(date +"%s")"
		export INSTANCE_NAME
	fi
	create_vm
	template_bootstrap_worker_metadata
	kubectl --kubeconfig "$USER_CLUSTER_KUBECONFIG" apply -f "$BOOTSTRAP_WORKER_FILE_PATH"
	# give time for node to fully bootstrap
	check_node_ready() {
		kubectl --kubeconfig "$USER_CLUSTER_KUBECONFIG" get csr | awk '{print $1}' | xargs -I {} kubectl --kubeconfig "$USER_CLUSTER_KUBECONFIG" certificate approve {}
		kubectl --kubeconfig "$USER_CLUSTER_KUBECONFIG" get node "${INSTANCE_NAME}" >"/tmp/${INSTANCE_NAME}.status"
		# shellcheck disable=SC2181
		if [[ $? == 0 ]]; then
			node_status=$(tail -n 1 "/tmp/${INSTANCE_NAME}.status" | awk '{print $2}')
			if [[ "$node_status" == "Ready" ]]; then
				return 0
			fi
		fi
		return 1
	}
	export MAX_ATTEMPTS=60
	export RETRY_WAIT=10
	if ! retry_function_v2 check_node_ready; then
		return 1
	fi
	unset MAX_ATTEMPTS
	unset RETRY_WAIT
	# give node time to complete node registration
	sleep 120
	echo "Nodes succesfully attached to Hosted cluster $TEST_CLUSTER_ID"
	create_labels
}
