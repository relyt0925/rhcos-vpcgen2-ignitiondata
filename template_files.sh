#!/usr/bin/env bash
echo "Create templated files directory"
TEMPLATED_BASE_DIRECTORY=/tmp/ignitionformmatedfiles
rm -rf "$TEMPLATED_BASE_DIRECTORY"
mkdir -p "$TEMPLATED_BASE_DIRECTORY"
for relative_file_path in etc/**/*; do
	echo "$relative_file_path"
	BASE64_ENCODED_FILEPATH="${TEMPLATED_BASE_DIRECTORY}/${relative_file_path}.base64"
	mkdir -p $(dirname "$BASE64_ENCODED_FILEPATH")
	cat "${relative_file_path}" | base64 -w 0 >"$BASE64_ENCODED_FILEPATH"
done
for relative_file_path in etc/**/**/*; do
	echo "$relative_file_path"
	BASE64_ENCODED_FILEPATH="${TEMPLATED_BASE_DIRECTORY}/${relative_file_path}.base64"
	mkdir -p $(dirname "$BASE64_ENCODED_FILEPATH")
	cat "${relative_file_path}" | base64 -w 0 >"$BASE64_ENCODED_FILEPATH"
done
for relative_file_path in etc/**/**/**/*; do
	echo "$relative_file_path"
	BASE64_ENCODED_FILEPATH="${TEMPLATED_BASE_DIRECTORY}/${relative_file_path}.base64"
	mkdir -p $(dirname "$BASE64_ENCODED_FILEPATH")
	cat "${relative_file_path}" | base64 -w 0 >"$BASE64_ENCODED_FILEPATH"
done
for relative_file_path in usr/**/**/*; do
	echo "$relative_file_path"
	BASE64_ENCODED_FILEPATH="${TEMPLATED_BASE_DIRECTORY}/${relative_file_path}.base64"
	mkdir -p $(dirname "$BASE64_ENCODED_FILEPATH")
	cat "${relative_file_path}" | base64 -w 0 >"$BASE64_ENCODED_FILEPATH"
done
for relative_file_path in systemd-units/*; do
	echo "$relative_file_path"
	FULL_IGNITION_FILE_PATH="${TEMPLATED_BASE_DIRECTORY}/${relative_file_path}"
	mkdir -p $(dirname "$FULL_IGNITION_FILE_PATH")
	cp "${relative_file_path}" "$FULL_IGNITION_FILE_PATH"
done
