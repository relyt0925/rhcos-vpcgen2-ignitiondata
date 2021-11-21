#!/usr/bin/env bash
set -x
# shellcheck disable=SC2154
cat >/tmp/ibm-additions-kubelet.conf <<EOF
#START IBM ADDITIONS
eventRecordQPS: 0
podPidsLimit: $POD_PID_MAX
maxPods: $MAX_PODS
providerID: $providerid
#END IBM ADDITIONS
EOF
sed -i '/#START IBM ADDITIONS/,/#END IBM ADDITIONS/d' /etc/kubernetes/kubelet.conf
cat /tmp/ibm-additions-kubelet.conf >>/etc/kubernetes/kubelet.conf
