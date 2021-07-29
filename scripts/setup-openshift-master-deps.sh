#!/bin/bash

set -xe

# Dependencies from https://github.ibm.com/alchemy-containers/armada-openshift-master/blob/master/.travis.yml
if [ -n "${CLUSTER_ID}" ]; then
    #Install required packages
    sudo apt-get install -y gettext apache2-utils sshpass -qq
    sudo apt-get remove -y gpg
    sudo apt-get install -y gnupg1
    sudo apt-get clean
    sudo ln -s /usr/bin/gpg1 /usr/bin/gpg

    #setup deps
    
    make armada-openshift-master
    pwd
    cd ../armada-openshift-master
    make python-deps
    make galaxy-deps
    make armada-ansible
    make openshift-4-worker-automation
    ./scripts/travis-molecule-setup.sh
    make openshift_kubeconfig
    make s3config
fi
