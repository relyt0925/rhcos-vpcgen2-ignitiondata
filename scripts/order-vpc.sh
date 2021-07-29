#!/bin/bash
set +e

export ORIGIN_COS_BUCKET_REGION_PROD=us-east
export ORIGIN_VS_REGION_PROD=us-east-2
export IMAGE_ID="r014-5613abef-9943-47ca-b780-22373c72d63e"
export vm_private_ip=""
export instance_id=""

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


install_python3() {
	sudo apt-get update
	sudo apt-get install -y  python3-pip python3-setuptools python3-wheel \
		glib2.0 pkg-config libpixman-1-dev flex
        sudo apt-get install -y jq
	sudo apt-get install -y qemu
	sudo apt install qemu-utils
}
install_git() {
	sudo apt-get update
	sudo apt-get install -y build-essential libffi-dev libssl-dev git
}




waitforvsrunning () {

	DESIREDSTATE="running"
	ACTUALSTATE=""
	LIMIT=10
	SLEEP_TIME=30

   	repeat=0

   	instance_id=$1
   	repeat=0
   	echo "instance_id = $instance_id"
   	while [ $repeat -lt $LIMIT ] && [ "$ACTUALSTATE" != "$DESIREDSTATE" ]; do
      		ACTUALSTATE=$(ibmcloud is instance  "$instance_id" --output JSON | jq -r .status)
      		echo "The Virtual Server  instance: $instance_id still in proviisoning state.... waiting for  provision to complete"
      		sleep $SLEEP_TIME
      		repeat=$(( repeat + 1 ))
    	done
}

create_vs_vm () {
   	
		instance_id=$(ibmcloud is instance-create "${INSTANCE_NAME}" "${ORIGIN_VPCID_PROD}" \
			"${ORIGIN_VS_REGION_PROD}" "${PROFILE_NAME}" "${ORIGIN_SUBNETID_PROD}" --image-id  "${IMAGE_ID}" \
			--user-data "$( cat "$USERDATA_FILE_PATH")"   --output JSON | jq  -r .id)
        	waitforvsrunning "$instance_id"
			vm_private_ip=$(ibmcloud is instance  "$instance_id"  --output JSON | jq -r '.network_interfaces[].primary_ipv4_address')
	  
	  
}

destroy_vs_vm(){
	ibmcloud is instance-delete "$instance_id" --force
}

PROFILE_NAME="bx2d-4x16"

#Intall the required packages 
install_git
install_python3


create_vm(){
install_plugins ||  return 1
ibmcloud login -a https://cloud.ibm.com --apikey "$ORIGIN_COS_BX_APIKEY_PROD" -r "$ORIGIN_COS_BUCKET_REGION_PROD" 
create_vs_vm   || return 1
}
