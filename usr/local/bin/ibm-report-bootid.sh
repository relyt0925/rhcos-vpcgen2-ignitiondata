#!/usr/bin/env bash
set -x
echo "annotating node with bootid to show system has registered the boot"
KUBECONFIG_FILE_PATH="/var/lib/kubelet/kubeconfig"
BOOT_ID_VALUE=$(cat /proc/sys/kernel/random/boot_id)
NODE_NAME=$(hostname)
KUBELET_SERVING_CERT_FILE_PATH="/var/lib/kubelet/pki/kubelet-server-current.pem"
while true; do
	if ! grep "CERTIFICATE" "$KUBELET_SERVING_CERT_FILE_PATH"; then
		echo "can't report until all certs approved and local"
		sleep 60
		continue
	fi
	if ! kubectl --kubeconfig "$KUBECONFIG_FILE_PATH" annotate node "$NODE_NAME" ibm-cloud.kubernetes.io/worker-version="$BOM_VERSION" --overwrite; then
		sleep 60
		continue
	fi
	if ! kubectl --kubeconfig "$KUBECONFIG_FILE_PATH" annotate node "$NODE_NAME" openshift.io/reported-boot-id="$BOOT_ID_VALUE" --overwrite; then
		sleep 60
		continue
	fi
	sleep 120
done
