#!/bin/bash
set +e
export PROFILE_NAME="bx2d-4x16"
export IMAGE_ID="r006-832e78df-378a-452e-9d76-6c75a61e107b"
export vm_private_ip=""
export instance_id=""

install_plugins() {
	# ibmcloud cli
	if ! ibmcloud --version >/dev/null; then
		curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
	else
		ibmcloud plugin update -all
	fi
	ibmcloud plugin install cloud-object-storage -f
	ibmcloud plugin install vpc-infrastructure -f

}

install_python3() {
	sudo apt-get update
	sudo apt-get install -y python3-pip python3-setuptools python3-wheel \
		glib2.0 pkg-config libpixman-1-dev flex
	sudo apt-get install -y jq
	sudo apt-get install -y qemu
	sudo apt install qemu-utils
}
install_git() {
	sudo apt-get update
	sudo apt-get install -y build-essential libffi-dev libssl-dev git
}

waitforvsrunning() {

	DESIREDSTATE="running"
	ACTUALSTATE=""
	LIMIT=10
	SLEEP_TIME=30

	repeat=0

	instance_id=$1
	repeat=0
	echo "instance_id = $instance_id"
	while [ $repeat -lt $LIMIT ] && [ "$ACTUALSTATE" != "$DESIREDSTATE" ]; do
		ACTUALSTATE=$(ibmcloud is instance "$instance_id" --output JSON | jq -r .status)
		echo "The Virtual Server  instance: $instance_id still in proviisoning state.... waiting for  provision to complete"
		sleep $SLEEP_TIME
		repeat=$((repeat + 1))
	done
}

create_vs_vm() {

	instance_id=$(ibmcloud is instance-create "${INSTANCE_NAME}" "${TEST_VPC_ID}" \
		"${VPC_TEST_SUBNET_ZONE}" "${PROFILE_NAME}" "${TEST_VPC_SUBNET}" --image-id "${IMAGE_ID}" \
		--user-data "$(cat "$USERDATA_FILE_PATH")" --output JSON | jq -r .id)
	waitforvsrunning "$instance_id"
	vm_private_ip=$(ibmcloud is instance "$instance_id" --output JSON | jq -r '.network_interfaces[].primary_ipv4_address')
	export vm_private_ip

}

create_labels() {
	cd ../armada-openshift-master || return 1
	KUBECONFIG_PATH="$(pwd)/lib/roks4/pki"
	BOOTSTRAPPING_KUBECONFIG_FILE_PATH="$KUBECONFIG_PATH/admin.kubeconfig"
	NODE_NAME=$INSTANCE_NAME
	FAILURE_ZONE=$VPC_TEST_SUBNET_ZONE
	REGION=$VPC_TEST_ACCOUNT_REGION
	PROVIDER="vpc-gen2"

	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" failure-domain.beta.kubernetes.io/region="$REGION" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/region="$REGION" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" failure-domain.beta.kubernetes.io/zone="$FAILURE_ZONE" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/zone="$FAILURE_ZONE" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" arch=amd64 --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" beta.kubernetes.io/instance-type=$PROFILE_NAME --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/machine-type=$PROFILE_NAME --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/internal-ip="$vm_private_ip" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/worker-id="$INSTANCE_NAME" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/iaas-provider="$PROVIDER" --overwrite
	#TODO WORKER_VERSION MIGHT BE DIFFERENT FROM MASTER VERSION
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" node-role.kubernetes.io/master="" --overwrite
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" node-role.kubernetes.io/worker="" --overwrite

	WORKER_BOM_VERSION=$(kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" get node "$NODE_NAME" -o jsonpath='{.metadata.annotations.ibm-cloud\.kubernetes\.io/worker-version}')
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" label nodes "$NODE_NAME" ibm-cloud.kubernetes.io/worker-version="$WORKER_BOM_VERSION" --overwrite

	echo "DONE WITH LABELS WILL PRINT NOW"
	sleep 30
	kubectl --kubeconfig="$BOOTSTRAPPING_KUBECONFIG_FILE_PATH" get nodes --show-labels
}

clean_iaas_resources() {
	install_plugins || return 1
	ibmcloud login -a https://cloud.ibm.com --apikey "$VPC_TEST_ACCOUNT_API_KEY" -r "$VPC_TEST_ACCOUNT_REGION" || return 1
	ibmcloud is instances | grep "bpr-${TEST_CLUSTER_ID}" >/tmp/iaasresourcefile
	while read -r itr_line; do
		iaas_instance_id=$(echo "$itr_line" | awk '{print $1}')
		ibmcloud is instance-delete "$iaas_instance_id" -f
	done </tmp/iaasresourcefile
}

create_vm() {
	install_plugins || return 1
	ibmcloud login -a https://cloud.ibm.com --apikey "$VPC_TEST_ACCOUNT_API_KEY" -r "$VPC_TEST_ACCOUNT_REGION" || return 1
	create_vs_vm || return 1
}

# Intall the required packages
install_git
install_python3
