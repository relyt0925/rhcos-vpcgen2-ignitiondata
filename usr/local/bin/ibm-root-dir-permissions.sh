#!/usr/bin/env bash
mkdir -p /var/data/kubelet
mkdir -p /var/data/crioruntimestorage
mkdir -p /var/data/criorootstorage
mkdir -p /var/data/tmp
mkdir -p /var/log/pods
mkdir -p /var/data/kubeletlogs
semanage fcontext -a -e /var/lib/kubelet /var/data/kubelet
semanage fcontext -a -e /run/containers/storage /var/data/crioruntimestorage
semanage fcontext -a -e /var/lib/containers/storage /var/data/criorootstorage
semanage fcontext -a -e /var/tmp /var/data/tmp
semanage fcontext -a -e /var/log/pods /var/data/kubeletlogs
restorecon -r /var/data/kubelet
restorecon -r /var/data/crioruntimestorage
restorecon -r /var/data/criorootstorage
restorecon -r /var/data/tmp
restorecon -r /var/data/kubeletlogs

# symlink code
mkdir -p /var/lib/kubelet
cp -r /var/lib/kubelet/* /var/data/kubelet/
rm -rf /var/lib/kubelet
ln -s /var/data/kubelet /var/lib/kubelet

#bind mount code
POD_LOGS_MOUNT_NAME=var-log-pods.mount
cat <<EOF >/etc/systemd/system/"$POD_LOGS_MOUNT_NAME"
[Unit]
Description=Pod logs bind mount
After=var-data.mount
Wants=var-data.mount

[Mount]
What=/var/data/kubeletlogs
Where=/var/log/pods
Type=none
Options=bind,nofail

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start "$POD_LOGS_MOUNT_NAME"
