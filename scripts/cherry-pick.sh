#!/bin/bash

set -xe

PULL_REQUEST_NUM=$(echo "$TRAVIS_TAG" | awk -F- '{print $3}')
RELEASE_BRANCH=$(echo "$TRAVIS_TAG" | awk -F- '{print $4"-"$5}')
PULL_REQUEST_URL="https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/$PULL_REQUEST_NUM"

cd ..
git clone -b test_cherrypick --depth 1 git@github.ibm.com:alchemy-containers/bootstrap-bom-update-release.git
cd bootstrap-bom-update-release/cherry-pick
go build
./cherry-pick --target-branch "$RELEASE_BRANCH" --pr-url "$PULL_REQUEST_URL"
