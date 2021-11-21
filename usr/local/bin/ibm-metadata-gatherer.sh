#!/usr/bin/env bash
set -x
DEFAULT_INTERFACE=$(ip -4 route ls | grep default | head -n 1 | grep -Po '(?<=dev )(\S+)')
WORKER_SUBNET=$(ip addr show dev "$DEFAULT_INTERFACE" | grep "inet " | awk '{print $2}' | awk 'NR==1{print $1}')
WORKER_IP=$(echo "$WORKER_SUBNET" | awk -F / '{print $1}')
KUBELET_NODE_IP="$WORKER_IP"
KUBELET_HOSTNAME_OVERRIDE="$(hostname)"
BOOTSTRAP_KUBECONFIG_FILE_PATH="/etc/kubernetes/kubeconfig"
while true; do
	IBM_MACHINE_METADATA_PREFIX="ibm-machinemetadata"
	IBM_MACHINE_METADATA_DIRECTORY="/etc/sysconfig/ibmmachinemetadata"
	METADATA_KUBE_NAMESPACE="openshift-infra"
	mkdir -p "$IBM_MACHINE_METADATA_DIRECTORY"
	oc extract -n "$METADATA_KUBE_NAMESPACE" --kubeconfig "$BOOTSTRAP_KUBECONFIG_FILE_PATH" "configmap/${IBM_MACHINE_METADATA_PREFIX}-${KUBELET_HOSTNAME_OVERRIDE}" --to="$IBM_MACHINE_METADATA_DIRECTORY" --confirm
	oc extract -n "$METADATA_KUBE_NAMESPACE" --kubeconfig "$BOOTSTRAP_KUBECONFIG_FILE_PATH" "secret/${IBM_MACHINE_METADATA_PREFIX}-${KUBELET_HOSTNAME_OVERRIDE}" --to="$IBM_MACHINE_METADATA_DIRECTORY" --confirm
	if [[ -f "${IBM_MACHINE_METADATA_DIRECTORY}/providerid" ]]; then
		break
	fi
	sleep 60
done
# shellcheck disable=SC2059
printf "${KUBELET_NODE_IP}" >"${IBM_MACHINE_METADATA_DIRECTORY}/KUBELET_NODE_IP"

IBM_MACHINE_METADATA_ENVFILE="/etc/sysconfig/ibmmachinemetadataenvfile"
rm -f "$IBM_MACHINE_METADATA_ENVFILE"
touch "$IBM_MACHINE_METADATA_ENVFILE"
for fullfilepath in "${IBM_MACHINE_METADATA_DIRECTORY}/"*; do
	file_basename="${fullfilepath##*/}"
	echo "${file_basename}=\"$(cat "$fullfilepath")\"" >>"$IBM_MACHINE_METADATA_ENVFILE"
done

# shellcheck disable=SC1090
source "$IBM_MACHINE_METADATA_ENVFILE"
KUBELET_CONF_PATH=/etc/kubernetes/kubelet.conf
if grep "providerID" "$KUBELET_CONF_PATH"; then
	# shellcheck disable=SC2154
	sed -i -e "s/^providerID:.*/providerID: ${providerid}/g" "$KUBELET_CONF_PATH"
else
	echo "providerID: $providerid" >>"$KUBELET_CONF_PATH"
fi
HAPROXY_KUBECONFIG_FILEPATH=/etc/kubernetes/haproxy-kubeconfig
ADVERTISED_IP_ADDRESS=172.20.0.1
SECURE_PORT=2040
cp -f "$BOOTSTRAP_KUBECONFIG_FILE_PATH" "$HAPROXY_KUBECONFIG_FILEPATH"
sed -i "s/server:.*/server: https:\/\/${ADVERTISED_IP_ADDRESS}:${SECURE_PORT}/g" "$HAPROXY_KUBECONFIG_FILEPATH"
# create metadata files read by SOS toolkit
mkdir -p /opt/iks
echo "{\"imageversion\": \"${BOM_VERSION}\"}" >/opt/iks/imageversion.json
BOOTSTRAPPED_DATE=$(date -u +"%Y-%m-%dT%T%z")
echo "{\"reloaddate\": \"${BOOTSTRAPPED_DATE}\"}" >/opt/iks/reloaddate.json
