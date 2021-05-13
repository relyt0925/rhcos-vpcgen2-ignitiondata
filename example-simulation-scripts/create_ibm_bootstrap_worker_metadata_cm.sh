#!/usr/bin/env bash
WORKERIP=10.240.64.12
cat >/tmp/ibm-bootstrap-worker-metdata-cm <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-machinemetadata-$WORKERIP
  namespace: openshift-infra
data:
  providerid: "ibm://accountid1///clusterid1/workeridar"
EOF
sleep 1
kubectl --kubeconfig /tmp/tyler13-admin-kubeconfig apply -f /tmp/ibm-bootstrap-worker-metdata-cm
kubectl --kubeconfig /tmp/tyler13-admin-kubeconfig apply -f /Users/tylerlisowski/gopath/src/github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/node-bootstrapper-rbac-addtion/
