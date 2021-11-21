#!/usr/bin/env bash
set -e
set -o pipefail
# shellcheck disable=SC2002
RELEASE_IMAGE_SUFFIX=$(cat services/rhcos-vpcgen2-ignitiondata/deployment.yaml | grep "releaseimage:" | awk -F '/' '{print $NF}' | awk -F '"' '{print $1}')
RELEASE_IMAGE="us.icr.io/armada-master/$RELEASE_IMAGE_SUFFIX"
MACHINE_CONFIG_DAEMON_SHA=$(oc adm release info "$RELEASE_IMAGE" | grep "machine-config-operator" | awk '{print $2}')
sed -i "s#MACHINE_CONFIG_DAEMON_SHA_VALUE#${MACHINE_CONFIG_DAEMON_SHA}#g" etc/sysconfig/machineconfigdaemonsha
