#!/bin/bash
set -xe

source scripts/order-vpc.sh

template_create_nodepool() {
 export NODEPOOL_FILE_PATH=/tmp/nodepool.yaml
 cat <<EOF >$NODEPOOL_FILE_PATH
apiVersion: hypershift.openshift.io/v1alpha1
kind: NodePool
metadata:
  name: $TEST_CLUSTER_ID-mynodepool
  namespace: master
spec:
  clusterName: $TEST_CLUSTER_ID
  nodeCount: 2
  nodePoolManagement:
    upgradeType: Replace
    recreate:
      strategy: OnDelete
  platform:
    type: IBMCloud
  release:
    image: "${NODEPOOL_IMAGE}"
EOF
}

template_create_rolebinding() {
  make rhcos-incluster-config
  cd ../rhcos-incluster-config
  export ROLEBINDING_FILE_PATH="/tmp/rolebinding.yaml"
  spruce merge services/rhcos-incluster-config/deployment.yaml >$ROLEBINDING_FILE_PATH
}


template_bootstrap_worker_metadata(){
export BOOTSTRAP_WORKER_FILE_PATH=/tmp/ibm-bootstrap-worker-metdata-cm
cat <<EOF >$BOOTSTRAP_WORKER_FILE_PATH
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-machinemetadata-$INSTANCE_NAME
  namespace: openshift-infra
data:
  workerid: "$INSTANCE_NAME"
  accountid: "accountid1"
  clusterid: "clusterid1"
  providerid: "ibm://accountid1///clusterid1/$INSTANCE_NAME"
EOF
}

check_status_verify() {
 	retreive_verify_pods_state() {
		kubectl get pods -n "master-$TEST_CLUSTER_ID" -o wide -l app=ignition-server --no-headers > "/tmp/verifier-pods"
        
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
 spruce merge services/rhcos-vpcgen2-ignitiondata/deployment.yaml > services/rhcos-vpcgen2-ignitiondata/production.yaml
 sed -i "s/{{managed_cluster_tail}}/$TEST_CLUSTER_ID/g" services/rhcos-vpcgen2-ignitiondata/production.yaml
 kubectl apply -f services/rhcos-vpcgen2-ignitiondata/production.yaml 
 kubectl get configmap ignition-config-98-ibm-registry-mirror -n "master-$TEST_CLUSTER_ID" -o yaml > registry-mirror.yaml && sed -i "s/{{ kubx-masters.armada-info-configmap.ICR_REGISTRY_URL }}/us.icr.io/g" registry-mirror.yaml && kubectl replace -f registry-mirror.yaml
 config_server_pod=$(kubectl get pods -n "master-$TEST_CLUSTER_ID" | grep ignition-server | awk '{print $1;}')
 kubectl delete pod "$config_server_pod" -n "master-$TEST_CLUSTER_ID" 
}

get_user_data() {
  export USERDATA_FILE_PATH="/tmp/userdata-$TEST_CLUSTER_ID"
  user_data_secret=$(kubectl get secret -n "master-$TEST_CLUSTER_ID" |grep user-data | awk '{print $1;}')
  kubectl get secret -n "master-$TEST_CLUSTER_ID"  "$user_data_secret" -o jsonpath='{.data.value}'  | base64 --decode >"$USERDATA_FILE_PATH"
  if [ -s "$USERDATA_FILE_PATH" ] 
  then
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
    sleep 30
    check_status_verify
    deploy_ignition_data 
    get_user_data
    template_create_rolebinding
    cd ../armada-openshift-master
    KUBECONFIG_PATH="$(pwd)/lib/roks4/pki"
    
    
    kubectl --kubeconfig  "$KUBECONFIG_PATH/admin.kubeconfig" apply -f "$ROLEBINDING_FILE_PATH"
    create_vm
    template_bootstrap_worker_metadata
    kubectl --kubeconfig "$KUBECONFIG_PATH/admin.kubeconfig" apply -f "$BOOTSTRAP_WORKER_FILE_PATH"
    sleep 600
    #kubectl --kubeconfig  "$KUBECONFIG_PATH/admin.kubeconfig" get node >"/tmp/node"
    node_name=$(kubectl --kubeconfig  "$KUBECONFIG_PATH/admin.kubeconfig" get node |  awk 'NR==2' | awk -F' ' '{print $1}')
    echo "$node_name"
    #cat "/tmp/node"
    #node_name=cat "/tmp/node" |  awk 'NR==2' | awk -F' ' '{print $1}'
    if [ "$node_name" = "${INSTANCE_NAME}" ]; then
    echo "Nodes succesfully attached to Hosted cluster $TEST_CLUSTER_ID"
    else
    echo "Error in attaching node to hosted cluster for $TEST_CLUSTER_ID "
    fi
    destroy_vs_vm
    return $?
}