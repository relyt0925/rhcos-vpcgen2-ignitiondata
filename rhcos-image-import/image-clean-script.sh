#!/usr/bin/env bash
set -e
set -x

#source ../armada-softlayer-image/gen2image/util_import_funcs.sh
# shellcheck disable=SC1091
source ../armada-softlayer-image/gen2image/utils.sh
#source cos_env.txt
export TMP_IMAGE_INFO_FILE=/tmp/imageinfo
export TMP_IMAGE_RM_AGE_BASED_FILE=/tmp/imagestoevaluateforremovalbasedonage
export TMP_COSENTRY_LIST_FILE=/tmp/currentlistofcosentries
export TMP_COSAGEBASED_REMOVAL_LIST_FILE=/tmp/cosbucketentriestoremove

install_plugins() {
	# ibmcloud cli
	if ! ibmcloud --version >/dev/null; then
		curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
	else
		ibmcloud plugin update -all
	fi
	ibmcloud plugin install cloud-object-storage -f
	ibmcloud plugin install vpc-infrastructure -f

}


clear_image_resources_cos() {
	ibmcloud login -a "$BXAPIENDPOINT_TO_USE"  --apikey "$ORIGIN_COS_BX_APIKEY_PROD" -r "$ORIGIN_COS_BUCKET_REGION_PROD" -g "$ORIGIN_COS_BUCKET_RESOURCEGROUP_PROD"
	bx cos config auth --method IAM
	bx cos config crn --crn "$ORIGIN_COS_BUCKET_REGION_PROD" --force
	bx cos config endpoint-url --url https://s3.us-east.cloud-object-storage.appdomain.cloud
	ibmcloud cos config url-style --style Path
	bx cos list-objects --bucket  "$ORIGIN_COS_BUCKET_NAME_PROD" --region "$ORIGIN_COS_BUCKET_REGION_PROD" >$TMP_COSENTRY_LIST_FILE
	rm -f "$TMP_COSAGEBASED_REMOVAL_LIST_FILE"
	touch "$TMP_COSAGEBASED_REMOVAL_LIST_FILE"
	# shellcheck disable=SC2002
	 for row in $(cat "TMP_COSENTRY_LIST_FILE" | jq -r '.[] | @base64'); do
	  _jq() {
		   echo "${row}" | base64 --decode | jq -r "${1}"

		}
	        set +x
                VISIBILITY=$(_jq '.visibility')
                if [[ "$VISIBILITY" == "public" ]]; then
                        continue
                fi
                CREATED_DATE_RAW=$(_jq '.created_at')
                CREATED_DATE_SECONDS=$(date -d "$CREATED_DATE_RAW" +%s)
                CURRENT_TIME_SECONDS=$(date +%s)
                TIME_DIFFERENCE_SECONDS=$((CURRENT_TIME_SECONDS - CREATED_DATE_SECONDS))
                TIME_DIFFERENCE_DAYS=$((TIME_DIFFERENCE_SECONDS / (3600 * 24)))
                AGE_THRESHOLD_DAYS=90
                if ((TIME_DIFFERENCE_DAYS > AGE_THRESHOLD_DAYS)); then
                        echo "found an image older than the age threshold. Evaluating for deletion purposes"
                        echo "$(_jq '.created_at') $(_jq '.name') $(_jq '.id')" >>"$TMP_COSAGEBASED_REMOVAL_LIST_FILE"
                fi
                set -x
        done


	#now actually clear images
	while read -r LINE; do
		cos_bucket_key=$(echo "$LINE" | awk '{print $1}')
		if [[ -z "$cos_bucket_key" ]]; then
			continue
		fi
		echo "Image Name to delelete = $LINE"
		bx cos delete-object --bucket "$ORIGIN_COS_BUCKET_NAME_PROD" --key "$cos_bucket_key" --region "$ORIGIN_COS_BUCKET_REGION_PROD" --force
	done <"$TMP_COSAGEBASED_REMOVAL_LIST_FILE"

}


clear_image_vpc() {
	ibmcloud login -a "$BXAPIENDPOINT_TO_USE" --apikey "$ORIGIN_COS_BX_APIKEY_PROD" -r "$ORIGIN_COS_BUCKET_REGION_PROD" -g "$ORIGIN_COS_BUCKET_RESOURCEGROUP_PROD"
	ibmcloud is target --gen "$GENERATION_TO_TARGET"
	ibmcloud is images --json >"$TMP_IMAGE_INFO_FILE"
	rm -f "$TMP_IMAGE_RM_AGE_BASED_FILE"
	touch "$TMP_IMAGE_RM_AGE_BASED_FILE"
	 # shellcheck disable=SC2002
	 for row in $(cat "$TMP_IMAGE_INFO_FILE" | jq -r '.[] | @base64'); do
                _jq() {
                        # shellcheck disable=SC2086
                        echo "${row}" | base64 --decode | jq -r ${1}
                }
                set +x
                VISIBILITY=$(_jq '.visibility')
                if [[ "$VISIBILITY" == "public" ]]; then
                        continue
                fi
                CREATED_DATE_RAW=$(_jq '.created_at')
                CREATED_DATE_SECONDS=$(date -d "$CREATED_DATE_RAW" +%s)
                CURRENT_TIME_SECONDS=$(date +%s)
                TIME_DIFFERENCE_SECONDS=$((CURRENT_TIME_SECONDS - CREATED_DATE_SECONDS))
                TIME_DIFFERENCE_DAYS=$((TIME_DIFFERENCE_SECONDS / (3600 * 24)))
                AGE_THRESHOLD_DAYS=90
                if ((TIME_DIFFERENCE_DAYS > AGE_THRESHOLD_DAYS)); then
                        echo "found an image older than the age threshold. Evaluating for deletion purposes"
                        echo "$(_jq '.created_at') $(_jq '.name') $(_jq '.id')" >>"$TMP_IMAGE_RM_AGE_BASED_FILE"
                fi
                set -x
        done

	#now actually clear images
	while read -r LINE; do
		image_id_vpc=$(echo "$LINE" | awk '{print $3}')
		if [[ -z "$image_id_vpc" ]]; then
			continue
		fi
		echo "VPC image to be deleted $LINE"
		#bx is image-delete "$image_id_vpc" --force
	done <$TMP_IMAGE_RM_AGE_BASED_FILE
}

clear_expired_resources() {
	for LOCATION in "${!LOCATION_CRN_MAP[@]}"; do
		if [[ $LOCATION == "g2"* ]]; then
			GENERATION_TO_TARGET=2
		else
			GENERATION_TO_TARGET=1
		fi
		VPC_ENDPOINT_TO_USE="${LOCATION_VPCENDPOINT_MAP[$LOCATION]}"
		BXAPIENDPOINT_TO_USE="${LOCATION_BXAPIENDPOINT_MAP[$LOCATION]}"
		BXREGION_TO_USE="${LOCATION_BXREGION_MAP[$LOCATION]}"
		if [[ -z "$BXAPIENDPOINT_TO_USE" ]]; then
			BXAPIENDPOINT_TO_USE="https://cloud.ibm.com"
		fi
		#TODO: Hack for BNPP Currently can remove when they give full support
		if [[ "$BXREGION_TO_USE" == "eu-fr2" ]]; then
			export IBMCLOUD_IS_NG_API_ENDPOINT=https://eu-fr2.iaas.cloud.ibm.com
		else
			unset IBMCLOUD_IS_NG_API_ENDPOINT
		fi
		if [[ -n "$VPC_ENDPOINT_TO_USE" ]]; then
			export IBMCLOUD_IS_API_ENDPOINT="$VPC_ENDPOINT_TO_USE"
		else
			unset IBMCLOUD_IS_API_ENDPOINT
		fi
		#scan_images
		if [[ -z "$DRY_RUN" ]]; then
			clear_image_vpc
		        clear_image_resources_cos	
		fi
	done
}

set -ex
# shellcheck disable=SC1091
#install_git || return 1
#install_plugins || return 1
clear_expired_resources || return 1
