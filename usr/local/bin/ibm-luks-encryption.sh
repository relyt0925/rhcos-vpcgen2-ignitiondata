#!/usr/bin/env bash
SECONDARY_STORAGE_SYSCONFIG_DIRECTORY=/etc/sysconfig/ibmsecondarystorage
if [[ -z "$SECONDARY_STORAGE_DEVICE" ]]; then
	echo "cannot continue without a secondary storage device specified"
	exit 0
fi
if ! [[ -f "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey" ]]; then
	echo "creating passphrase for key"
	KEY=$(dd if="/dev/urandom" bs=64 count=1 iflag=fullblock)
	# shellcheck disable=SC2059
	printf "$KEY" >"${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
	chmod 0600 "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
fi
echo "storing luks key in cluster"
luks_encryption_secret_namespace=openshift-infra
# shellcheck disable=SC2154
if [[ -z "$KUBELET_NODE_IP" ]]; then
	echo "cannot continue without KUBELET_NODE_IP"
	exit 0
fi
if [[ -z "$luks_encryption_secret_namespace" ]]; then
	echo "cannot continue without luks secret namesapce"
	exit 0
fi
luks_secret_full_name="luks-$KUBELET_NODE_IP"
# shellcheck disable=SC2059
SECONDARY_STORAGE_DEVICE_BASE64=$(printf "$SECONDARY_STORAGE_DEVICE" | base64 -w 0)
# shellcheck disable=SC2002
LUKS_KEY_BASE64=$(cat "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey" | base64 -w 0)
cat <<EOF >/tmp/lukssecret
apiVersion: v1
kind: Secret
metadata:
  name: $luks_secret_full_name
  namespace: $luks_encryption_secret_namespace
type: ibm-cloud.k8s.io/luks-encryption-info
data:
  devices: $SECONDARY_STORAGE_DEVICE_BASE64
  key: $LUKS_KEY_BASE64
EOF
BOOTSTRAP_KUBECONFIG_FILE_PATH="/etc/kubernetes/kubeconfig"
while true; do
	if oc --kubeconfig "$BOOTSTRAP_KUBECONFIG_FILE_PATH" apply -f /tmp/lukssecret; then
		echo "secret successfully applied"
		break
	fi
	sleep 60
done
echo "creating luks header"
cryptsetup luksFormat --key-size=256 --batch-mode --hash sha512 --verbose "$SECONDARY_STORAGE_DEVICE" "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
echo "opening luks device mapper"
LUKS_DEVICE_MAPPER_NAME=docker_data
DEVICE_MOUNT_PATH=/var/data
DEVICE_MOUNT_SYSTEMD_NAME=var-data.mount
BLK_ID_OUTPUT=$(blkid -s UUID -o value "$SECONDARY_STORAGE_DEVICE")
cryptsetup luksOpen UUID="$BLK_ID_OUTPUT" "$LUKS_DEVICE_MAPPER_NAME" --key-file "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
echo "formatting filesystem on luks mapper"
mkfs -t ext4 /dev/mapper/"$LUKS_DEVICE_MAPPER_NAME"
cat <<EOF >/etc/systemd/system/"$DEVICE_MOUNT_SYSTEMD_NAME"
[Unit]
Description=Mount drive

[Mount]
What=/dev/mapper/${LUKS_DEVICE_MAPPER_NAME}
Where=${DEVICE_MOUNT_PATH}
Type=ext4
Options=nofail,relatime

[Install]
WantedBy=multi-user.target
EOF
POD_LOGS_MOUNT_NAME=var-log-pods.mount
cat <<EOF >/usr/local/bin/setupluksmount
#!/usr/bin/env bash
cryptsetup luksOpen UUID="${BLK_ID_OUTPUT}" ${LUKS_DEVICE_MAPPER_NAME} --key-file "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
systemctl start ${DEVICE_MOUNT_SYSTEMD_NAME}
systemctl start ${POD_LOGS_MOUNT_NAME}
rm -f "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
exit 0
EOF
cat <<EOF >/usr/local/bin/fetchlukskey
#!/usr/bin/env bash
while true; do
	if kubectl get --kubeconfig "$BOOTSTRAP_KUBECONFIG_FILE_PATH" -n "$luks_encryption_secret_namespace" secret "$luks_secret_full_name" -o jsonpath='{.data.key}' > "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey64"; then
	  cat "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey64" | base64 -d > "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
	  break
	fi
	if kubectl get --kubeconfig /var/lib/kubelet/kubeconfig -n "$luks_encryption_secret_namespace" secret "$luks_secret_full_name" -o jsonpath='{.data.key}' > "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey64"; then
	  cat "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey64" | base64 -d > "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey"
	  break
	fi
	sleep 60
done
exit 0
EOF
chmod 0700 /usr/local/bin/fetchlukskey
chmod 0700 /usr/local/bin/setupluksmount
chmod 0644 /etc/systemd/system/"$DEVICE_MOUNT_SYSTEMD_NAME"
cat <<EOF >/etc/systemd/system/decrypt-secondary-storage.service
[Unit]
Description=Automate mounting of the device
After=network-online.target local-fs.target
Before=kubelet.service podman.service crio-wipe.service crio.service


[Service]
Type=oneshot
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/fetchlukskey
ExecStartPost=/usr/local/bin/setupluksmount
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/usr/local/bin/clean-secondary-storage-keys.sh
#!/usr/bin/env bash
rm -f "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey" "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/lukskey64"
exit 0
EOF
cat <<EOF >/etc/systemd/system/clean-secondary-storage-keys.service
[Unit]
Description=Automate mounting of the device
After=decrypt-secondary-storage.service

[Service]
Type=oneshot
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/clean-secondary-storage-keys.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/decrypt-secondary-storage.service
chmod 0644 /etc/systemd/system/clean-secondary-storage-keys.service
chmod 0700 /usr/local/bin/clean-secondary-storage-keys.sh
systemctl daemon-reload
systemctl enable decrypt-secondary-storage.service
systemctl enable clean-secondary-storage-keys.service
systemctl start "$DEVICE_MOUNT_SYSTEMD_NAME"
systemctl start clean-secondary-storage-keys.service

#make necessary directories
bash /usr/local/bin/ibm-root-dir-permissions.sh

touch "$SECONDARY_STORAGE_SYSCONFIG_DIRECTORY/setupexecuted"
exit 0
