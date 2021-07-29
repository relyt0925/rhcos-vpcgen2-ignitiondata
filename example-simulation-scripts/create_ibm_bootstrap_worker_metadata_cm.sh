#!/usr/bin/env bash
WORKERID=tyler-30
cat >/tmp/ibm-bootstrap-worker-metdata-cm <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-machinemetadata-$WORKERID
  namespace: openshift-infra
data:
  providerid: "ibm://accountid1///clusterid1/$WORKERID"
EOF
sleep 1
kubectl --kubeconfig /tmp/tyler13-admin-kubeconfig apply -f /tmp/ibm-bootstrap-worker-metdata-cm
kubectl --kubeconfig /tmp/tyler13-admin-kubeconfig apply -f /Users/tylerlisowski/gopath/src/github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/node-bootstrapper-rbac-addtion/
