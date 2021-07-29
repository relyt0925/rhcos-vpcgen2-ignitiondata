#!/usr/bin/env bash

set -e

echo "Create templated files directory"
DIR_LIST="etc systemd-units usr"
TEMPLATED_BASE_DIRECTORY=tmp/ignitionformmatedfiles
rm -rf "$TEMPLATED_BASE_DIRECTORY"
mkdir -p "$TEMPLATED_BASE_DIRECTORY"

func_traverse_dirs() {
	# shellcheck disable=SC2126
	is_systemd=$(echo "$1" | grep "systemd" | wc -l)
	if [[ "$is_systemd" -ne 0 ]]; then
		func_handle_systemd_files "$1"
	else
		# shellcheck disable=SC2045,SC2086
		for dir in $(ls $1); do
			if [[ -d "$1/$dir" ]]; then
				func_traverse_dirs "$1/$dir"
			elif [[ -f "$1/$dir" ]]; then
				func_handle_storage_files "$1/$dir"
			fi
		done
	fi
}

func_handle_storage_files() {
	echo "$1"
	BASE64_ENCODED_FILEPATH="${TEMPLATED_BASE_DIRECTORY}/$1.base64"
	# shellcheck disable=SC2046
	mkdir -p $(dirname "$BASE64_ENCODED_FILEPATH")
	# shellcheck disable=SC2002
	cat "$1" | base64 -w 0 >"$BASE64_ENCODED_FILEPATH"
	printf 'data:text/plain;base64,' | cat - "$BASE64_ENCODED_FILEPATH" >temp && mv temp "$BASE64_ENCODED_FILEPATH"
	echo "${BASE64_ENCODED_FILEPATH}"
}

func_handle_systemd_files() {
	#shellcheck disable=SC2045,SC2086
	for file in $(ls $1); do
		if [[ -f "$1/$file" ]]; then
			echo "$1/$file"
			FULL_IGNITION_FILE_PATH="${TEMPLATED_BASE_DIRECTORY}/$1/$file"
			# shellcheck disable=SC2046
			mkdir -p $(dirname "$FULL_IGNITION_FILE_PATH")
			awk '{print "" $0}' $1/$file >$FULL_IGNITION_FILE_PATH
			echo "${FULL_IGNITION_FILE_PATH}"
		elif [ -d $1/$file ]; then
			func_handle_systemd_files $1/$file
		fi
	done
}

for list in ${DIR_LIST}; do
	func_traverse_dirs "$list"
done
