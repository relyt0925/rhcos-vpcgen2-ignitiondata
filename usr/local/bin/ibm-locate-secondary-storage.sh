#!/usr/bin/env bash
# this script ultimately will feed the necessary data to downstream units that will perform the disk formatting/mounting
set -x
if [[ -z "$SECONDARY_STORAGE_FORMATTING_STRATEGY" ]]; then
	echo "using default strategy"
	SECONDARY_STORAGE_FORMATTING_STRATEGY="ext4"
fi

echo "initializing secondary storage sysconfig metadata directory"
SECONDARY_STORAGE_SYSCONFIG_DIRECTORY=/etc/sysconfig/ibmsecondarystorage
SECONDARY_STORAGE_SYSCONFIG_ENVFILE="${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/ibmsecondarystorageenvfile"
rm -rf "$SECONDARY_STORAGE_SYSCONFIG_DIRECTORY"
mkdir -p "$SECONDARY_STORAGE_SYSCONFIG_DIRECTORY"
touch "$SECONDARY_STORAGE_SYSCONFIG_ENVFILE"

echo "determining secondary encryption device"
if [[ -z "$SECONDARY_STORAGE_DEVICE" ]]; then
	echo "scanning for candidate secondary storage devices"
	SECONDARY_STORAGE_DEVICE=$(bash /usr/local/bin/ibm-find-secondary-storage.sh)
fi

if [[ -n "$SECONDARY_STORAGE_DEVICE" ]]; then
	echo "writing metadata that will trigger formatting of secondary storage device $SECONDARY_STORAGE_DEVICE"
	echo "SECONDARY_STORAGE_DEVICE=\"${SECONDARY_STORAGE_DEVICE}\"" >>"$SECONDARY_STORAGE_SYSCONFIG_ENVFILE"
	touch "${SECONDARY_STORAGE_SYSCONFIG_DIRECTORY}/${SECONDARY_STORAGE_FORMATTING_STRATEGY}"
fi
