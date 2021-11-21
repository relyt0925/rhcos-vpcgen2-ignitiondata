#!/bin/bash

# shellcheck disable=SC1091
source scripts/utils.sh

check_cluster() {
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	# Give the node some time to get to Ready
	sleep 240
	check_nodes
	NODE_STATUS="$?"
	get_pods
	POD_STATUS=$?
	delete_pods_test
	DELETE_STATUS=$?
	export NODE_STATUS
	export POD_STATUS
	export DELETE_STATUS
}

get_pods() {
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	mkdir -p "$GOPATH/tmp/podcheckfiles"
	all_pods=$(retry "oc get pods --all-namespaces")
	echo "$all_pods" | base64 -w 0 >>"$GOPATH/tmp/podcheckfiles/podinfo"
	echo "" >>"$GOPATH/tmp/podcheckfiles/podinfo"
	echo "$all_pods" >"$ARTIFACTS_DIR/allpodsoutput.txt"
	if echo "$all_pods" | grep ImagePullBackOff; then
		echo "TEST FAILED pods in image backoff (base64 encoded content)" >>"$GOPATH/tmp/podcheckfiles/podinfo"
		add_test_comment "$GOPATH/tmp/podcheckfiles/podinfo"
		return 1
	fi
	if echo "$all_pods" | grep -v ibm-keepalived-watcher | grep CrashLoopBackOff; then
		echo "TEST FAILED pods in crash loop backoff (base64 encoded content)" >>"$GOPATH/tmp/podcheckfiles/podinfo"
		add_test_comment "$GOPATH/tmp/podcheckfiles/podinfo"
		return 1
	fi
	# shellcheck disable=SC2126
	PENDING_POD_COUNT=$(echo "$all_pods" | grep Pending | wc -l)
	# shellcheck disable=SC2126
	CONTAINER_CREATING_POD_COUNT=$(echo "$all_pods" | grep ContainerCreating | wc -l)
	# shellcheck disable=SC2126
	TERMINATING_POD_COUNT=$(echo "$all_pods" | grep Terminating | wc -l)
	TERMINATING_POD_THRESHOLD=9
	CONTAINER_CREATING_THRESHOLD=9
	PENDING_POD_THRESHOLD=8
	if ((TERMINATING_POD_COUNT > TERMINATING_POD_THRESHOLD)); then
		echo "TEST FAILED more than $TERMINATING_POD_THRESHOLD pods terminating" >>"$GOPATH/tmp/podcheckfiles/podinfo"
		add_test_comment "$GOPATH/tmp/podcheckfiles/podinfo"
		return 1
	fi
	if ((CONTAINER_CREATING_POD_COUNT > CONTAINER_CREATING_THRESHOLD)); then
		echo "TEST FAILED more than $CONTAINER_CREATING_THRESHOLD pods creating" >>"$GOPATH/tmp/podcheckfiles/podinfo"
		add_test_comment "$GOPATH/tmp/podcheckfiles/podinfo"
		return 1
	fi
	if ((PENDING_POD_COUNT > PENDING_POD_THRESHOLD)); then
		echo "TEST FAILED more than $PENDING_POD_THRESHOLD pods pending" >>"$GOPATH/tmp/podcheckfiles/podinfo"
		add_test_comment "$GOPATH/tmp/podcheckfiles/podinfo"
		return 1
	fi
	echo "TEST PASSED Pod Check passed (base64 encoded content)" >>"$GOPATH/tmp/podcheckfiles/podinfo"
	add_test_comment "$GOPATH/tmp/podcheckfiles/podinfo"
	return 0
}

delete_pods_test() {
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	mkdir -p "$GOPATH/tmp/deletepodcheckfiles"
	if ! oc delete pods -n openshift-console -l component=downloads --wait=true --request-timeout=120s >"$GOPATH/tmp/deletepodcheckfiles/deletepodoutput"; then
		# shellcheck disable=SC2002
		cat "$GOPATH/tmp/deletepodcheckfiles/deletepodoutput" | base64 -w 0 >"$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
		echo "" >>"$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
		echo "TEST FAILED couldn't delete pods in time" >>"$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
		add_test_comment "$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
		return 1
	fi
	# shellcheck disable=SC2002
	cat "$GOPATH/tmp/deletepodcheckfiles/deletepodoutput" | base64 -w 0 >"$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
	echo "" >>"$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
	echo "TEST PASSED deleted pods in time" >>"$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
	add_test_comment "$GOPATH/tmp/deletepodcheckfiles/deletepodoutputbase64"
	return 0
}

get_nodes() {
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	NODES=$(retry "oc get nodes")
	status=$?
	return $status
}

check_nodes() {
	mkdir -p "$GOPATH/tmp/nodecheckfiles"
	if ! get_nodes; then
		echo "TEST FAILED failure getting nodes in test" >"$GOPATH/tmp/nodecheckfiles/nodegetdata"
		add_test_comment "$GOPATH/tmp/nodecheckfiles/nodegetdata"
		return 1
	fi
	echo "$NODES" | base64 -w 0 >"$GOPATH/tmp/nodecheckfiles/nodegetdata"
	echo "$NODES" >"$ARTIFACTS_DIR/allnodesoutput.txt"
	echo "" >>"$GOPATH/tmp/nodecheckfiles/nodegetdata"
	if echo "$NODES" | grep NotReady; then
		echo "TEST FAILED found a not ready node. failing test" >>"$GOPATH/tmp/nodecheckfiles/nodegetdata"
		add_test_comment "$GOPATH/tmp/nodecheckfiles/nodegetdata"
		return 1
	fi
	echo "TEST PASSED Node check test passed" >>"$GOPATH/tmp/nodecheckfiles/nodegetdata"
	add_test_comment "$GOPATH/tmp/nodecheckfiles/nodegetdata"
	return 0
}
