#!/bin/bash
#NOTE: this script should only be called form Makefile cherry-pick command

function usage {
  script=$(basename "$0")
    cat << EOF
$script - Handles creating a tag to cherry pick a commit to a target branch
Usage: $script pullRequestURL=<PR_URL> releaseBranch=<targetBranchName>
  pullRequestURL      Major.Minor_Provider Version of the BOM files you want to publish (valid options would be 1.11_z or 1.11_openshift).
  releaseBranch       path to the bom relative to armada-ansible directory (ie. common/bom/next/z-target-bom-1.11.yml ).
Example: ./$script pullRequestURL=https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/104 releaseBranch=release-4.9
EOF
}

set -xe

PULL_REQUEST_URL=$1
RELEASE_BRANCH=$2

if [ -z "${PULL_REQUEST_URL}" ]; then
    echo "error: Missing release branch parameter"
    usage
    exit 1
fi

if [ -z "${RELEASE_BRANCH}" ]; then
    echo "error: Missing release branch parameter"
    usage
    exit 1
fi

PULL_REQUEST_NUM=$(basename "$PULL_REQUEST_URL")

re='^[0-9]+$'
if ! [[ $PULL_REQUEST_NUM =~ $re ]] ; then
   echo "error: Pull Request URL not valid"
   usage
   exit 1
fi

NOW=$(date '+%F-%H-%M-%S')
git tag -f cherry-pick-"$PULL_REQUEST_NUM"-"$RELEASE_BRANCH"-"$NOW"
git push -f origin cherry-pick-"$PULL_REQUEST_NUM"-"$RELEASE_BRANCH"-"$NOW"