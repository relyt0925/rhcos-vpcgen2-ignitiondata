#!/usr/bin/env bash
set -e
set -o pipefail
set -x
# shellcheck disable=SC1091
source ../armada-softlayer-image/gen2image/util_import_funcs.sh
# shellcheck disable=SC1091
source ../armada-softlayer-image/gen2image/utils.sh

download_and_format_rhcos_image() {
	curl -LO "$IMAGE_DOWNLOAD_URL"
	gzip -d "${UPSTREAM_IMAGE_FILE}"
	./qemu-img resize "$(pwd)/${UPSTREAM_IMAGE_NAME_FILETYPE}" 100G
}

push_qwc2_images_to_cos() {
	# prod cos upload
	ibmcloud login -a https://cloud.ibm.com --apikey "$ORIGIN_COS_BX_APIKEY_PROD" -r "$ORIGIN_COS_BUCKET_REGION_PROD" -g "$ORIGIN_COS_BUCKET_RESOURCEGROUP_PROD"
	bx cos config endpoint-url --clear
	ibmcloud cos config region --region "$ORIGIN_COS_BUCKET_REGION_PROD"
	bx cos config auth --method IAM
	bx cos config crn --crn "$ORIGIN_COS_BUCKET_CRN_PROD" --force
	bx cos config endpoint-url --url https://s3.us-east.cloud-object-storage.appdomain.cloud
	ibmcloud cos config url-style --style Path
	ibmcloud cos list-objects --bucket "$ORIGIN_COS_BUCKET_NAME_PROD" --region "$ORIGIN_COS_BUCKET_REGION_PROD"
	if ! ibmcloud cos head-object --bucket "$ORIGIN_COS_BUCKET_NAME_PROD" --key "$UPSTREAM_IMAGE_NAME_FILETYPE" --region "$ORIGIN_COS_BUCKET_REGION_PROD" >/dev/null 2>&1; then
		alive_probe &
		ALIVEPROBPID=$!
		ibmcloud cos upload --bucket "$ORIGIN_COS_BUCKET_NAME_PROD" --key "$UPSTREAM_IMAGE_NAME_FILETYPE" --file "$(pwd)/$UPSTREAM_IMAGE_NAME_FILETYPE" --region "$ORIGIN_COS_BUCKET_REGION_PROD"
		set +e
		kill -9 $ALIVEPROBPID
		set -e
	fi
	ibmcloud cos list-objects --bucket "$ORIGIN_COS_BUCKET_NAME_PROD" --region "$ORIGIN_COS_BUCKET_REGION_PROD"

	# stage cos upload
	ibmcloud login -a https://test.cloud.ibm.com --apikey "$ORIGIN_COS_BX_APIKEY_STAGE" -r "$ORIGIN_COS_BUCKET_REGION_STAGE" -g "$ORIGIN_COS_BUCKET_RESOURCEGROUP_STAGE"
	bx cos config endpoint-url --clear
	ibmcloud cos config region --region "$ORIGIN_COS_BUCKET_REGION_STAGE"
	bx cos config endpoint-url --url https://s3.us-west.cloud-object-storage.test.appdomain.cloud
	bx cos config auth --method IAM
	ibmcloud cos config url-style --style Path
	bx cos config crn --crn "$ORIGIN_COS_BUCKET_CRN_STAGE" --force
	ibmcloud cos list-objects --bucket "$ORIGIN_COS_BUCKET_NAME_STAGE" --region "$ORIGIN_COS_BUCKET_REGION_STAGE"
	if ! ibmcloud cos head-object --bucket "$ORIGIN_COS_BUCKET_NAME_STAGE" --key "$UPSTREAM_IMAGE_NAME_FILETYPE" --region "$ORIGIN_COS_BUCKET_REGION_STAGE" >/dev/null 2>&1; then
		alive_probe &
		ALIVEPROBPID=$!
		ibmcloud cos upload --bucket "$ORIGIN_COS_BUCKET_NAME_STAGE" --key "$UPSTREAM_IMAGE_NAME_FILETYPE" --file "$(pwd)/$UPSTREAM_IMAGE_NAME_FILETYPE" --region "$ORIGIN_COS_BUCKET_REGION_STAGE"
		set +e
		kill -9 $ALIVEPROBPID
		set -e
	fi
	ibmcloud cos list-objects --bucket "$ORIGIN_COS_BUCKET_NAME_STAGE" --region "$ORIGIN_COS_BUCKET_REGION_STAGE"
}

# shellcheck disable=SC2002
RELEASE_IMAGE_SUFFIX=$(cat services/rhcos-vpcgen2-ignitiondata/deployment.yaml | grep "releaseimage:" | awk -F '/' '{print $NF}' | awk -F '"' '{print $1}')
RELEASE_IMAGE_NOTAG=$(echo "$RELEASE_IMAGE_SUFFIX" | awk -F ':' '{print $1}')
STATIC_REGISTRY_PATH="us.icr.io/armada-master"
RELEASE_IMAGE="${STATIC_REGISTRY_PATH}/${RELEASE_IMAGE_SUFFIX}"
SHA_FOR_INSTALLER_ARTIFACTS=$(oc adm release info "$RELEASE_IMAGE" | grep installer-artifacts | awk '{print $2}')
docker run --rm -v /tmp:/tmp --entrypoint cp "${STATIC_REGISTRY_PATH}/${RELEASE_IMAGE_NOTAG}@${SHA_FOR_INSTALLER_ARTIFACTS}" /manifests/coreos-bootimages.yaml /tmp/coreos-bootimages.yaml
set +x
echo "$ENCODED_OPENSHIFT_KUBECONFIG" | base64 -d >/tmp/yaml-to-json-kubeconfig.yaml
kubectl apply --dry-run=client --kubeconfig /tmp/yaml-to-json-kubeconfig.yaml -f /tmp/coreos-bootimages.yaml -o json | jq -r '.data.stream' >/tmp/coreos-bootimages-streams.json
rm -f /tmp/yaml-to-json-kubeconfig.yaml
set -x
# shellcheck disable=SC2002
IMAGE_DOWNLOAD_URL=$(cat /tmp/coreos-bootimages-streams.json | jq -r '.architectures.x86_64.artifacts.ibmcloud.formats."qcow2.gz".disk.location')
UPSTREAM_IMAGE_FILE=$(echo "$IMAGE_DOWNLOAD_URL" | awk -F '/' '{print $NF}')
UPSTREAM_IMAGE_NAME_FILETYPE=$(echo "$UPSTREAM_IMAGE_FILE" | awk -F '.gz' '{print $1}')
UPSTREAM_IMAGE_NAME=$(echo "$UPSTREAM_IMAGE_FILE" | awk -F '.qcow2.gz' '{print $1}')

#image_captured_name and  vpc_os_classification are for compatibility with existing softlayer scripts
export image_captured_name="$UPSTREAM_IMAGE_NAME"
git show --quiet "$TRAVIS_TAG" | grep -B 10 "^}" | grep -A 10 "^{" >/tmp/metadata
# shellcheck disable=SC2002
vpc_os_classification=$(cat /tmp/metadata | jq -r '.osname')
export vpc_os_classification
install_python3 || return 1
install_plugins || return 1
download_and_format_rhcos_image || return 1
push_qwc2_images_to_cos || return 1
push_image_to_all_locations || return 1
