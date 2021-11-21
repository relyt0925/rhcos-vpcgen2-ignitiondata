#!/usr/bin/env bash
set -e
set -o pipefail
# shellcheck disable=SC2002
OC_VERSION=$(cat services/rhcos-vpcgen2-ignitiondata/deployment.yaml | grep "releaseimage:" | awk -F '/' '{print $NF}' | awk -F '"' '{print $1}' | awk -F ':' '{print $2}' | awk -F '-' '{print $1}')
if ! command -v oc; then
	curl -H "X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}" -LO "https://na.artifactory.swg-devops.com/artifactory/wcp-alchemy-containers-team-openshift-generic-remote/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz" &&
		tar xvzf openshift-client-linux.tar.gz && sudo mv oc /usr/local/bin/oc && sudo chmod +x /usr/local/bin/oc && sudo mv kubectl /usr/local/bin/kubectl && sudo chmod +x /usr/local/bin/kubectl
fi
command -v oc
command -v kubectl
