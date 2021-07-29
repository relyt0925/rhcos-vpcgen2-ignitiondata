#!/bin/bash

set -xe

#Variables
NOTIFY_PID=0

#Only for local testing
if [ -z "${TRAVIS_BUILD_DIR}" ]; then
    TRAVIS_BUILD_DIR=$(pwd)
fi

#Exports
export PUBLISH_ADDONS=false
export TEST_MASTER_TARGET_BOM=${CREATE_BOM}
export ANSIBLE_VERBOSITY=2
export TEST_CLUSTER_ID="${CLUSTER_ID}-${TRAVIS_JOB_ID}"
export KUBECONFIG=${TRAVIS_BUILD_DIR}/openshift.kubeconfig



#Notify bg & keep the job alive
start_notify() {
set +x
    while true
    do
        echo "$*..."
        sleep 120
    done
set -x
}

#stop notify bg
stop_notify() {
    if [ ${NOTIFY_PID} -ne 0 ]; then
set +e
        kill -9 ${NOTIFY_PID} >/dev/null 2>&1
        wait ${NOTIFY_PID} > /dev/null 2>&1
set -e
        NOTIFY_PID=0
        tail -n 50 "/tmp/${TEST_CLUSTER_ID}.txt"
    fi
}

#Cancel job
cancel_job() {
    stop_notify
}

#run molecule commands
run_cmd() {
    start_notify "$1" &
    NOTIFY_PID=$!
    $2 >> "/tmp/${TEST_CLUSTER_ID}.txt"
    stop_notify
}

trap cancel_job EXIT SIGINT SIGTERM
cd ../armada-openshift-master
