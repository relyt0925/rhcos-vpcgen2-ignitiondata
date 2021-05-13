#!/usr/bin/env bash
set -x
SECONDARY_STORAGE_SYSCONFIG_DIRECTORY=/etc/sysconfig/ibmsecondarystorage
if [[ -z "$SECONDARY_STORAGE_DEVICE" ]]; then
	echo "cannot continue without a secondary storage device specified"
	exit 0
fi

if [[ -z "$DEVICE_MOUNT_PATH" ]]; then
	echo "using default device mount path"
	DEVICE_MOUNT_PATH=/var/data
fi
if [[ -z "$DEVICE_MOUNT_SYSTEMD_NAME" ]]; then
	echo "using default device systemd name"
	DEVICE_MOUNT_SYSTEMD_NAME=var-data.mount
fi

echo "creating filesystem on device and mounting it at proper location"
mkfs -t ext4 "${SECONDARY_STORAGE_DEVICE}"
cat <<EOF >/etc/systemd/system/"$DEVICE_MOUNT_SYSTEMD_NAME"
[Unit]
Description=Mount drive

[Mount]
What=${SECONDARY_STORAGE_DEVICE}
Where=${DEVICE_MOUNT_PATH}
Type=ext4
Options=relatime

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$DEVICE_MOUNT_SYSTEMD_NAME"
systemctl start "$DEVICE_MOUNT_SYSTEMD_NAME"

#make necessary directories
bash /usr/local/bin/ibm-root-dir-permissions.sh
POD_LOGS_MOUNT_NAME=var-log-pods.mount
systemctl enable "$POD_LOGS_MOUNT_NAME"

touch "$SECONDARY_STORAGE_SYSCONFIG_DIRECTORY/setupexecuted"
exit 0
