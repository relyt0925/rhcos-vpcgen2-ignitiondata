#!/usr/bin/env bash
set -e
set -o pipefail
# shellcheck disable=SC2002
RELEASE_IMAGE_SUFFIX=$(cat services/rhcos-vpcgen2-ignitiondata/deployment.yaml | grep "releaseimage:" | awk -F '/' '{print $NF}' | awk -F '"' '{print $1}')
RELEASE_IMAGE="us.icr.io/armada-master/$RELEASE_IMAGE_SUFFIX"
INFRA_IMAGE=$(oc adm release info "$RELEASE_IMAGE" --pullspecs | grep "pod " | awk '{print $2}')
sed -i "s#pod-infra-container-image.*#pod-infra-container-image=${INFRA_IMAGE} \\\#g" etc/systemd/system/kubelet.service.d/02-ibm-kubelet-rootdiroverride.conf
sed -i "s#pod-infra-container-image.*#pod-infra-container-image=${INFRA_IMAGE} \\\#g" etc/systemd/system/kubelet.service.d/02-ibm-kubelet-rootdiroverride-satellite.conf
