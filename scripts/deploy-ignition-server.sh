#!/bin/bash
set -xe
# shellcheck disable=SC1091
source scripts/order-vpc.sh
source scripts/e2e-test.sh

retry_function_v2() {
	if [ -z "$MAX_ATTEMPTS" ]; then
		MAX_ATTEMPTS=30
	fi
	if [ -z "$RETRY_WAIT" ]; then
		RETRY_WAIT=5
	fi
	for ((c = 0; c <= MAX_ATTEMPTS; c++)); do
		$1
		#REASON FOR DISABLE: doesn't run command properly if follow shellcheck suggestions
		# shellcheck disable=SC2181
		if [[ $? == 0 ]]; then
			echo "$1 completed successfully"
			return 0
		fi
		echo "Attempt number $c to $1"
		sleep ${RETRY_WAIT}
	done
	echo "unable to $1"
	return 1
}

template_create_nodepool() {
	export NODEPOOL_FILE_PATH=/tmp/nodepool.yaml
	# shellcheck disable=SC2002
	RELEASE_IMAGE_RAW=$(cat services/rhcos-vpcgen2-ignitiondata/deployment.yaml | grep "releaseimage:" | awk -F ': "' '{print $2}' | awk -F '"' '{print $1}')
	RELEASE_IMAGE=${RELEASE_IMAGE_RAW//\{\{ DOCKER_REGISTRY \}\}/us.icr.io}
	cat <<EOF >$NODEPOOL_FILE_PATH
apiVersion: hypershift.openshift.io/v1alpha1
kind: NodePool
metadata:
  name: $TEST_CLUSTER_ID-mynodepool
  namespace: master
  labels:
    clusterid: "$TEST_CLUSTER_ID"
spec:
  clusterName: $TEST_CLUSTER_ID
  nodeCount: 2
  nodePoolManagement:
    upgradeType: Replace
    replace:
      strategy: OnDelete
  platform:
    type: IBMCloud
  release:
    image: "${RELEASE_IMAGE}"
EOF
}

template_create_managementcluster_config() {
	make rhcos-management-cluster-config
	cd ../rhcos-management-cluster-config
	export RHCOS_MANAGEMENT_CONFIG_PATH="/tmp/rhcos-management-config.yaml"
	spruce merge services/rhcos-management-cluster-config/deployment.yaml >"$RHCOS_MANAGEMENT_CONFIG_PATH"
	sed -i "s/{{ DOCKER_REGISTRY }}/registry.ng.bluemix.net/g" "$RHCOS_MANAGEMENT_CONFIG_PATH"
	IMAGE_COMMIT_TO_USE=$(git rev-parse HEAD)
	IMAGE_TO_USE="registry.ng.bluemix.net/armada-master/rhcos-management-cluster-config:${IMAGE_COMMIT_TO_USE}"
	sed -i "s#image:.*registry.ng.bluemix.net/armada-master/rhcos-management-cluster-config.*#image: ${IMAGE_TO_USE}#g" "$RHCOS_MANAGEMENT_CONFIG_PATH"
	cd ../rhcos-vpcgen2-ignitiondata
}

template_create_rolebinding() {
	make rhcos-incluster-config
	cd ../rhcos-incluster-config
	export ROLEBINDING_FILE_PATH="/tmp/rolebinding.yaml"
	spruce merge services/rhcos-incluster-config/deployment.yaml >$ROLEBINDING_FILE_PATH
	cd ../rhcos-vpcgen2-ignitiondata
}

check_status_verify() {
	retreive_verify_pods_state() {
		kubectl get pods -n "master-$TEST_CLUSTER_ID" -o wide -l app=ignition-server --no-headers >"/tmp/verifier-pods"

	}
	retreive_verify_pods_state
	total_finished_verification_pods=$(grep -c Running /tmp/verifier-pods)
	if ((total_finished_verification_pods == 1)); then
		echo "machine config server successfully deployed"
	fi
	return 0
}

deploy_ignition_data() {
	make runignitiontemplating
	spruce merge services/rhcos-vpcgen2-ignitiondata/deployment.yaml >services/rhcos-vpcgen2-ignitiondata/production.yaml
	sed -i "s/{{managed_cluster_tail}}/$TEST_CLUSTER_ID/g" services/rhcos-vpcgen2-ignitiondata/production.yaml
	sed -i "s/{{ kubx-masters.armada-info-configmap.ICR_REGISTRY_URL }}/us.icr.io/g" services/rhcos-vpcgen2-ignitiondata/production.yaml
	sed -i "s/{{ DOCKER_REGISTRY }}/registry.ng.bluemix.net/g" services/rhcos-vpcgen2-ignitiondata/production.yaml
	sed -i "s/{{#is_rhcos_on_satellite}}//g" services/rhcos-vpcgen2-ignitiondata/production.yaml
	sed -i "s#{{/is_rhcos_on_satellite}}##g" services/rhcos-vpcgen2-ignitiondata/production.yaml
	sed -i "s#image:.*registry.ng.bluemix.net/armada-master/rhcos-vpcgen2-ignitiondata.*#image: ${PRTEST_RHCOS_VPCGEN2_IGNITIONDATA_IMAGE_FULLPATH}#g" services/rhcos-vpcgen2-ignitiondata/production.yaml

	kubectl apply -f services/rhcos-vpcgen2-ignitiondata/production.yaml
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

deploy_config_server() {
	template_create_nodepool
	kubectl delete --ignore-not-found=true -f ${NODEPOOL_FILE_PATH}
	kubectl apply -f ${NODEPOOL_FILE_PATH}
	template_create_managementcluster_config
	kubectl apply -f "$RHCOS_MANAGEMENT_CONFIG_PATH"
	template_create_rolebinding
	cd ../armada-openshift-master
	cd ../rhcos-vpcgen2-ignitiondata
	kubectl --kubeconfig "$USER_CLUSTER_KUBECONFIG" apply -f "$ROLEBINDING_FILE_PATH"
	deploy_ignition_data
	# give time for config job to run and update nodepool appropriately
	sleep 300
	check_status_verify
}
