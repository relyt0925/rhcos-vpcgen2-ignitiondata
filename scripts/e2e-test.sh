#!/bin/bash
set -xe

fetch_kubeconfig_of_metrics_collector() {
	mkdir -p /tmp/ibm-gate-test-secrets/
	set +x
	echo "$USERCLUSTER_INGRESSINFO_KUBECONFIG64" | base64 -d >/tmp/ibm-gate-test-secrets/usercluster-ingressinfo-kubeconfig.yaml
	set -x
}

get_node_describe() {
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	NODE_DESCRIBE=$(retry "oc describe nodes $1")
	export NODE_DESCRIBE
}

retry() {
	local retryMax=10
	local timeout=10
	local retryCount=0
	local returnCode=1
	while [ "$returnCode" != 0 ]; do
		if [[ "$retryCount" == "$retryMax" ]]; then
			return 1
		fi
		result=$($1)
		returnCode="$?"
		if [[ "$returnCode" == 0 ]]; then
			echo "$result"
			break 1
		fi
		retryCount=$((retryCount + 1))
		sleep "$timeout"
	done
}

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

setup_user_cluster_oc_router_certs() {
	fetch_kubeconfig_of_metrics_collector
	USER_CLUSTER_KUBECONFIG=$1
	export KUBECONFIG=/tmp/ibm-gate-test-secrets/usercluster-ingressinfo-kubeconfig.yaml
	USER_OC_ROUTER_CERT_NAME=$(kubectl get cm -n kube-system ibm-cloud-cluster-ingress-info -o jsonpath='{.data.ingress-secret}')
	mkdir -p "$GOPATH/tmp/ocroutercertdir"
	USER_OC_ROUTER_SUBDOMAIN=$(kubectl get cm -n kube-system ibm-cloud-cluster-ingress-info -o jsonpath='{.data.ingress-subdomain}')
	export USER_OC_ROUTER_SUBDOMAIN
	kubectl get secret -n openshift-ingress "$USER_OC_ROUTER_CERT_NAME" -o yaml >"$GOPATH/tmp/ocroutercertdir/certsecret.yaml"
	kubectl get secret -n openshift-ingress "$USER_OC_ROUTER_CERT_NAME" -o jsonpath='{.data.tls\.crt}' >"$GOPATH/tmp/ocroutercertdir/subdomainingresscert64.crt"
	kubectl get secret -n openshift-ingress "$USER_OC_ROUTER_CERT_NAME" -o jsonpath='{.data.tls\.key}' >"$GOPATH/tmp/ocroutercertdir/subdomainingresskey64.key"
	# shellcheck disable=SC2002
	cat "$GOPATH/tmp/ocroutercertdir/subdomainingresskey64.key" | base64 -d >"$GOPATH/tmp/ocroutercertdir/subdomainingresskey.key"
	# shellcheck disable=SC2002
	cat "$GOPATH/tmp/ocroutercertdir/subdomainingresscert64.crt" | base64 -d >"$GOPATH/tmp/ocroutercertdir/subdomainingresscert.crt"
	sed -i "s/namespace:.*/namespace: openshift-ingress/g" "$GOPATH/tmp/ocroutercertdir/certsecret.yaml"
	export KUBECONFIG=$USER_CLUSTER_KUBECONFIG
	oc apply -f "$GOPATH/tmp/ocroutercertdir/certsecret.yaml"
	cat >"$GOPATH/tmp/ocroutercertdir/ingresscontrollerpatchapply.yaml" <<EOF
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  defaultCertificate:
    name: "${USER_OC_ROUTER_CERT_NAME}"
EOF
	oc apply -f "$GOPATH/tmp/ocroutercertdir/ingresscontrollerpatchapply.yaml"
}

e2e_setup() {
	USER_CLUSTER_KUBECONFIG=$1
	setup_user_cluster_oc_router_certs "$USER_CLUSTER_KUBECONFIG"
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	oc version
	kubectl version
	cat "../openshift-4-worker-automation/e2e-yamls/registry-crd.yaml"
	oc apply -f "../openshift-4-worker-automation/e2e-yamls/registry-crd.yaml"
	kubectl delete jobs --ignore-not-found -n openshift-image-registry registry-pvc-permissions
	kubectl delete pvc --ignore-not-found -n openshift-image-registry image-registry-storage
	#kubectl delete jobs --ignore-not-found -n openshift-image-registry registry-pvc-permissions
	# get a public ip from one of the two nodes. and then use that value in the new yaml then apply the new yaml
	private_ip=$(kubectl get nodes | awk '{ print $1 }' | head -2 | tail -1)
	echo "$private_ip"
	get_node_describe "$private_ip"
	# public_ip=$(echo "$NODE_DESCRIBE" | grep external-ip | cut -d'=' -f2)
	public_ip=$(echo "$NODE_DESCRIBE" | grep InternalIP | awk -F ':' '{print $2}' | awk '{print $1}')
	sed -i "s/public_ip/- $public_ip/g" "../openshift-4-worker-automation/e2e-yamls/ingress-service.yaml"
	cat "../openshift-4-worker-automation/e2e-yamls/ingress-service.yaml"
	# shellcheck disable=SC2086
	wait_for_router_patch() {
		# shellcheck disable=SC2086
		kubectl patch -n openshift-ingress service/router-default --type merge --patch "$(cat ../openshift-4-worker-automation/e2e-yamls/ingress-service.yaml)"
	}
	export MAX_ATTEMPTS=120
	export RETRY_WAIT=30
	set +e
	retry_function_v2 "wait_for_router_patch"
	set -e
	# TODO before next test
	# add the new sa to the scc privilege
	## fix storage class default
	kubectl patch storageclass ibmc-block-gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
	kubectl apply -f "../openshift-4-worker-automation/e2e-yamls/hostpath.yaml"
	kubectl apply -f "../openshift-4-worker-automation/e2e-yamls/pv-dir-setup-ds.yaml"
	oc adm policy add-scc-to-group privileged system:serviceaccounts:local-path-storage-duke
	kubectl apply -f "../openshift-4-worker-automation/e2e-yamls/cluster-dns-service.yaml.j2"
	kubectl apply -f "../openshift-4-worker-automation/e2e-yamls/coredns.yaml.j2"
	cat >"../openshift-4-worker-automation/e2e-yamls/coredns-cm.yaml" <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    # Add your CoreDNS customizations as import files.
    # Refer to https://cloud.ibm.com/docs/containers?topic=containers-cluster_dns for details.
    .:53 {
        errors
        health {
            lameduck 10s
        }
        ready
        rewrite name regex (.*)\.${USER_OC_ROUTER_SUBDOMAIN//./\\.} router-default.openshift-ingress.svc.cluster.local
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
EOF
	kubectl apply -f "../openshift-4-worker-automation/e2e-yamls/coredns-cm.yaml"
	kubectl apply -f "../openshift-4-worker-automation/e2e-yamls/provisioning-role-binding.yaml"
	#corresponds to the DNS Cluster IP of our secondary coredns deployment
	cat >"../openshift-4-worker-automation/e2e-yamls/ocdnspatch.yaml" <<EOF
{"spec":{"servers":[{"name":"test","zones":["${USER_OC_ROUTER_SUBDOMAIN}"],"forwardPlugin":{"upstreams":["172.31.0.11"]}}]}}
EOF
	wait_for_dns_patch() {
		# shellcheck disable=SC2046
		oc patch dns.operator/default --type=merge --patch=$(cat "../openshift-4-worker-automation/e2e-yamls/ocdnspatch.yaml")
	}
	export MAX_ATTEMPTS=120
	export RETRY_WAIT=30
	set +e
	retry_function_v2 "wait_for_dns_patch"
	set -e
	echo "E2E Preperation done... Now will execute E2E"
}

run_e2e() {
	if [[ -z "$ARTIFACTS_DIR" ]]; then
		export ARTIFACTS_DIR="$GOPATH/tmp/randomartifactsdirforconsistency"
	fi
	mkdir -p "$ARTIFACTS_DIR"
	USER_CLUSTER_KUBECONFIG=$1
	export KUBECONFIG="$USER_CLUSTER_KUBECONFIG"
	mkdir -p "$GOPATH/tmp/e2echeckfiles"
	cd "../openshift-4-worker-automation" || return 1
	# shellcheck disable=SC2002
	cat "$USER_CLUSTER_KUBECONFIG" | grep certificate-authority-data | awk '{print $2}' | base64 -d >"$GOPATH/tmp/e2echeckfiles/kubeconfigca"
	COMBINED_CA=$(cat "$GOPATH/tmp/ocroutercertdir/subdomainingresscert.crt" "$GOPATH/tmp/e2echeckfiles/kubeconfigca" | base64 -w 0)
	sed -i "s/certificate-authority-data:.*/certificate-authority-data: $COMBINED_CA/g" "$USER_CLUSTER_KUBECONFIG"
	oc create -n default cm --from-file="$USER_CLUSTER_KUBECONFIG" e2ekubeconfig
	sleep 600
	oc apply -n default -f "../openshift-4-worker-automation/e2e-yamls/e2e-job-4.8.yaml"
	sleep 100
	return 0
	# check_e2e_results TODO For future
}

check_e2e_results() {
	# give it some time to start
	# get the name of the pod for the wait and log commands
	echo "$PODS"
	name=$(kubectl -n default get pods | grep e2e-test | awk '{ print $1}')
	kubectl -n default wait --for=condition=Failed job/e2e-test --timeout=32400s &
	wait_pid_1=$!
	kubectl -n default wait --for=condition=Completed job/e2e-test --timeout=32400s &
	wait_pid_2=$!
	wait -n $wait_pid_1 $wait_pid_2
	E2E_RESULT=$(kubectl -n default wait --for=condition=Completed job/e2e-test --timeout=5s)
	export E2E_RESULT
	kubectl -n default logs "$name" -c e2e-test >"$GOPATH/tmp/e2echeckfiles/e2elogs"
	set +x
	# give configmap time to create
	sleep 120
	echo "UNIQUESTARTMESSAGE E2E LOGS START"
	cat "$GOPATH/tmp/e2echeckfiles/e2elogs"
	echo "UNIQUEENDMESSAGE E2E LOGS END"
	# shellcheck disable=SC2002
	cat "$GOPATH/tmp/e2echeckfiles/e2elogs" | grep "^failed:" >"$GOPATH/tmp/e2echeckfiles/e2efailedtestlogs"
	# shellcheck disable=SC2002
	cat "$GOPATH/tmp/e2echeckfiles/e2elogs" | grep "^passed:" >"$GOPATH/tmp/e2echeckfiles/e2epassedtestlogs"
	cp "$GOPATH/tmp/e2echeckfiles/e2efailedtestlogs" "$ARTIFACTS_DIR/e2efailedtestlogs.txt"
	cp "$GOPATH/tmp/e2echeckfiles/e2epassedtestlogs" "$ARTIFACTS_DIR/e2epassedtestlogs.txt"
	cp "$GOPATH/tmp/e2echeckfiles/e2elogs" "$ARTIFACTS_DIR/e2efulllogs.txt"
	# shellcheck disable=SC2002
	PASSED_TESTS_COUNT=$(cat "$GOPATH/tmp/e2echeckfiles/e2epassedtestlogs" | wc -l)
	# shellcheck disable=SC2002
	FAILED_TESTS_COUNT=$(cat "$GOPATH/tmp/e2echeckfiles/e2efailedtestlogs" | wc -l)
	set -x
	FILENAME="junit_e2e.xml"
	kubectl -n default logs "$name" -c publisher >"$ARTIFACTS_DIR/${FILENAME}"
	cat "$ARTIFACTS_DIR/${FILENAME}"
	if [[ $E2E_RESULT != 0 ]]; then
		echo "TEST FAILED: At least some E2E test failed. Go to the internal cluster in our gate test account and search for UNIQUESTARTMESSAGE E2E LOGS START to see logs" >"$GOPATH/tmp/e2echeckfiles/testfailuremessage"
		# add_test_comment "$GOPATH/tmp/e2echeckfiles/testfailuremessage"
		echo "$PASSED_TESTS_COUNT tests passed" >"$GOPATH/tmp/e2echeckfiles/testfailurelist"
		# shellcheck disable=SC2129
		echo "$FAILED_TESTS_COUNT tests failed. The list is base64 encoded below" >>"$GOPATH/tmp/e2echeckfiles/testfailurelist"
		echo "" >>"$GOPATH/tmp/e2echeckfiles/testfailurelist"
		echo "" >>"$GOPATH/tmp/e2echeckfiles/testfailurelist"
		# shellcheck disable=SC2002
		cat "$GOPATH/tmp/e2echeckfiles/e2efailedtestlogs" | base64 -w 0 >>"$GOPATH/tmp/e2echeckfiles/testfailurelist"
		# add_test_comment "$GOPATH/tmp/e2echeckfiles/testfailurelist"
		return 1
	fi
	echo "$PASSED_TESTS_COUNT tests passed" >"$GOPATH/tmp/e2echeckfiles/testpassedmessage"
	echo "TEST PASSED: E2E tests passed" >>"$GOPATH/tmp/e2echeckfiles/testpassedmessage"
	add_test_comment "$GOPATH/tmp/e2echeckfiles/testpassedmessage"
	return 0
}
