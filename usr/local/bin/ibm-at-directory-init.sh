#!/usr/bin/env bash
set -x
mkdir -p /var/log/at
chmod 1777 /var/log/at
mkdir -p /var/log/at-no-rotate
chmod 1777 /var/log/at-no-rotate
semanage fcontext -a -t container_file_t "/var/log/at(/.*)"
semanage fcontext -a -t container_file_t "/var/log/at"
semanage fcontext -a -t container_file_t "/var/log/at-no-rotate"
semanage fcontext -a -t container_file_t "/var/log/at-no-rotate(/.*)"
touch /etc/sysconfig/atdirinitialized
