#!/usr/bin/env bash
set -x
# shellcheck disable=SC2234
if ! ([[ "$IAAS_PROVIDER" == "upi" ]]); then
	echo "only perform patch on satellite clusters"
	exit 0
fi
DEFAULT_INTERFACE=$(ip -4 route ls | grep default | head -n 1 | grep -Po '(?<=dev )(\S+)')
DEFAULT_INTERFACE_MTU=$(cat "/sys/class/net/$DEFAULT_INTERFACE/mtu")
#The - 50 accounts for the overhead in the VXLAN protocol. Satellite always uses VXLAN protocol for calico
CALICO_MTU=$(echo "$DEFAULT_INTERFACE_MTU" 50 | awk '{printf "%d", $1 - $2}')
KUBECONFIG_FILE_PATH="/etc/kubernetes/kubeconfig"
cat >/tmp/mtu-configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibm-autodetect-mtu
  namespace: kube-system
data:
  mtu: "$CALICO_MTU"
EOF
cat >/tmp/mtu-operator-patch.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    mtu: $CALICO_MTU
EOF

MTU_OUTPUT_FILE=/tmp/mtuoutput
function fetch_existing_mtu() {
	kubectl --kubeconfig "$KUBECONFIG_FILE_PATH" get cm -n kube-system ibm-autodetect-mtu --ignore-not-found -o jsonpath='{.data.mtu}' >"$MTU_OUTPUT_FILE"
}

while true; do
	if ! fetch_existing_mtu; then
		sleep 60
		continue
	fi
	MTU_EXISTS=$(cat "$MTU_OUTPUT_FILE")
	if [[ -z "$MTU_EXISTS" ]]; then
		if ! kubectl --kubeconfig "$KUBECONFIG_FILE_PATH" patch Installation default --type merge -p "$(cat /tmp/mtu-operator-patch.yaml)"; then
			sleep 60
			continue
		fi
		if ! kubectl --kubeconfig "$KUBECONFIG_FILE_PATH" apply -f /tmp/mtu-configmap.yaml; then
			sleep 60
			continue
		fi
	fi
	break
done
