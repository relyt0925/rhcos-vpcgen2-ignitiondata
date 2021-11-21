#!/usr/bin/env bash
set -e
set -o pipefail
set -x
# shellcheck disable=SC2002
RELEASE_IMAGE_SUFFIX=$(cat services/rhcos-vpcgen2-ignitiondata/deployment.yaml | grep "releaseimage:" | awk -F '/' '{print $NF}' | awk -F '"' '{print $1}')
RELEASE_IMAGE_NOTAG=$(echo "$RELEASE_IMAGE_SUFFIX" | awk -F ':' '{print $1}')
STATIC_REGISTRY_PATH="us.icr.io/armada-master"
RELEASE_IMAGE="${STATIC_REGISTRY_PATH}/${RELEASE_IMAGE_SUFFIX}"
SHA_FOR_INSTALLER_ARTIFACTS=$(oc adm release info "$RELEASE_IMAGE" | grep installer-artifacts | awk '{print $2}')
docker run --rm -v /tmp:/tmp --entrypoint cp "${STATIC_REGISTRY_PATH}/${RELEASE_IMAGE_NOTAG}@${SHA_FOR_INSTALLER_ARTIFACTS}" /manifests/coreos-bootimages.yaml /tmp/coreos-bootimages.yaml
oc convert -f /tmp/coreos-bootimages.yaml --local -o json | jq -r '.data.stream' >/tmp/coreos-bootimages-streams.yaml
# shellcheck disable=SC2002,SC2034
IMAGE_DOWNLOAD_URL=$(cat /tmp/coreos-bootimages-streams.yaml | jq -r '.architectures.x86_64.artifacts.ibmcloud.formats."qcow2.gz".disk.location')
#TODO: This is what we need to pull and push to COS and then publish bashed off of. We will need to do a standard translation
#of this image name to replace the characters gen 2 doesn't accept in the image name (no _'s).
#it would be nice to see a few discrete steps at this point
#1) Download image from url locally
#2) Ensure image is sized to 100GB with ./qemu-img resize "DOWNLOADED_IMAGE_FILEPATH" 100G
#3) Upload downloaded image to the global read stage cos instance we have setup and the global read prod cos instance we have setup. In this step we should also be checking if the image is already uploaded and if so not reuploading. Similar path done in armada-softlayer-image
#4) Translate image name based off the name of the downloaded image. Just need to remove characters gen 2 doesn't accept in image name. General code is
# 	formatted_vpc_name=${formatted_vpc_name//./-} (replace .'s with -)
#		formatted_vpc_name=${formatted_vpc_name//_/-} (replace _ with -)
#5) Then call image create with the image name across all the service accounts. It should pull the same common vars set in armada-softlayer-image:  https://github.ibm.com/alchemy-containers/armada-softlayer-image/blob/master/gen2image/utils.sh
# good logic to checkout for general path (it will be slightly different for this is: https://github.ibm.com/alchemy-containers/armada-softlayer-image/blob/master/gen2image/import-image-to-cos.sh)
# Lastly we need to update the cleaner to be able to properly clean these images when they are no longer in use without causing outages.
# Save this for last until the general flow of imports is done.
