#!/usr/bin/env bash
# ******************************************************************************
# * Licensed Materials - Property of IBM
# * IBM Cloud Kubernetes Service, 5737-D43
# * (C) Copyright IBM Corp. 2019, 2021 All Rights Reserved.
# * US Government Users Restricted Rights - Use, duplication or
# * disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
# ******************************************************************************

set -e
DEVICES=$(lsblk -J --bytes)

BLOCK_DEVICE_LENGTH=$(echo "${DEVICES}" | jq '.[] | length ')

# first if conditional checks if there are exactly 0 children, the mountpoint is null for the main device, and the name is not null
# the elif conditional checks if the first device index is not checked (OS is first device), there is exactly 1 child.
# Both the child and main device null point is null and the device name is not null.
# Both checks will look to make sure the size of the device is greater than or equal to 25 GB
for c in $(seq 0 "${BLOCK_DEVICE_LENGTH}"); do
	if [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].children | length")" -eq 0 ]]; then
		if [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].mountpoint")" == "null" ]] && [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].size" | tr -d "\"")" -ge 25000000000 ]]; then
			RESERVED_DEVICE=$(echo "${DEVICES}" | jq ".blockdevices[${c}].name" | tr -d "\"")
			if [[ "${RESERVED_DEVICE}" == "null" ]]; then
				continue
			fi
			if ! lsblk -s | grep "^${RESERVED_DEVICE} " >/dev/null; then
				continue
			fi
			echo -n "/dev/${RESERVED_DEVICE}"
			exit 0
		fi
	elif [[ ${c} != 0 && "$(echo "${DEVICES}" | jq ".blockdevices[${c}].children | length")" -eq 1 ]]; then
		if [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].mountpoint")" == "null" && "$(echo "${DEVICES}" | jq ".blockdevices[${c}].children[0].mountpoint")" == "null" ]] && [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].size" | tr -d "\"")" -ge 25000000000 ]]; then
			RESERVED_DEVICE=$(echo "${DEVICES}" | jq ".blockdevices[${c}].children[0].name" | tr -d "\"")
			if [[ "${RESERVED_DEVICE}" == "null" ]]; then
				continue
			fi
			if ! lsblk -s | grep "^${RESERVED_DEVICE} " >/dev/null; then
				continue
			fi
			echo -n "/dev/${RESERVED_DEVICE}"
			exit 0
		fi
	fi
done
for c in $(seq 0 "${BLOCK_DEVICE_LENGTH}"); do
	if [[ ${c} != 0 && "$(echo "${DEVICES}" | jq ".blockdevices[${c}].children | length")" -gt 1 ]]; then
		total_children=$(echo "${DEVICES}" | jq ".blockdevices[${c}].children | length")
		for ((itr = 0; itr < total_children; itr++)); do
			if [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].mountpoint")" == "null" && "$(echo "${DEVICES}" | jq ".blockdevices[${c}].children[${itr}].mountpoint")" == "null" ]] && [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].size" | tr -d "\"")" -ge 75000000000 ]] && [[ "$(echo "${DEVICES}" | jq ".blockdevices[${c}].children[${itr}].size" | tr -d "\"")" -ge 75000000000 ]]; then
				RESERVED_DEVICE=$(echo "${DEVICES}" | jq ".blockdevices[${c}].children[${itr}].name" | tr -d "\"")
				if [[ "${RESERVED_DEVICE}" == "null" ]]; then
					continue
				fi
				if ! lsblk -s | grep "^${RESERVED_DEVICE} " >/dev/null; then
					continue
				fi
				echo -n "/dev/${RESERVED_DEVICE}"
				exit 0
			fi
		done
	fi
done
