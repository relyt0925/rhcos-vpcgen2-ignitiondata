#!/bin/bash

retry_function_v2() {
	if [ -z "$MAX_ATTEMPTS" ]; then
		MAX_ATTEMPTS=30
	fi
	if [ -z "$RETRY_WAIT" ]; then
		RETRY_WAIT=5
	fi
	for ((c = 0; c <= MAX_ATTEMPTS; c++)); do
		$1
		#REASON FOR DISABLE: doesn't run command properly if follow shellcheck suggestions
		# shellcheck disable=SC2181
		if [[ $? == 0 ]]; then
			echo "$1 completed successfully"
			return 0
		fi
		echo "Attempt number $c to $1"
		sleep ${RETRY_WAIT}
	done
	echo "unable to $1"
	return 1
}

retry() {
	local retryMax=10
	local timeout=10
	local retryCount=0
	local returnCode=1
	while [ "$returnCode" != 0 ]; do
		if [[ "$retryCount" == "$retryMax" ]]; then
			return 1
		fi
		result=$($1)
		returnCode="$?"
		if [[ "$returnCode" == 0 ]]; then
			echo "$result"
			break 1
		fi
		retryCount=$((retryCount + 1))
		sleep "$timeout"
	done
}

find_ibm_pr_link() {
	mkdir -p "$GOPATH/tmp/prtrackerinfo"
	if [[ -z "$TRAVIS_COMMIT" ]] && [[ -z "$TRAVIS_PULL_REQUEST_SHA" ]]; then
		return 0
	fi
	if [[ ! -f "$GOPATH/tmp/prtrackerinfo/pullrequests.json" ]]; then
		set +x
		curl -X GET -H "Authorization: token $GHE_TOKEN" https://github.ibm.com/api/v3/repos/alchemy-containers/rhcos-vpcgen2-ignitiondata/pulls >"$GOPATH/tmp/prtrackerinfo/pullrequests.json"
		set -x
	fi
	# shellcheck disable=SC2002
	for row in $(cat "$GOPATH/tmp/prtrackerinfo/pullrequests.json" | jq -r '.[] | @base64'); do
		_jq() {
			# shellcheck disable=SC2086
			echo "${row}" | base64 --decode | jq -r ${1}
		}
		OPEN_PULL_REQUEST_SHA=$(_jq '.head.sha')
		if [[ "$OPEN_PULL_REQUEST_SHA" == "$TRAVIS_COMMIT" ]] || [[ "$OPEN_PULL_REQUEST_SHA" == "$TRAVIS_PULL_REQUEST_SHA" ]]; then
			TESTING_PR_COMMENT_URL=$(_jq '.comments_url')
			export TESTING_PR_COMMENT_URL
			TESTING_PR_UUID=$(date +%s)
			export TESTING_PR_UUID
			break
		fi
	done
	return 0
}

add_test_comment() {
	FILE_WITH_COMMENT_DATA=$1
	if [[ -n "$TESTING_PR_COMMENT_URL" ]]; then
		# shellcheck disable=SC2086
		RESULT_MESSAGE="TEST UUID: $TESTING_PR_UUID\n\n$(cat $FILE_WITH_COMMENT_DATA)"
		mkdir -p "$GOPATH/tmp/testcommentoverride"
		cat >"$GOPATH/tmp/testcommentoverride/testcomment" <<EOF
{
  "body": "${RESULT_MESSAGE}"
}
EOF
		set +x
		curl -X POST -H "Authorization: token $GHE_TOKEN" "$TESTING_PR_COMMENT_URL" -H 'Content-Type: application/json' --data @"$GOPATH/tmp/testcommentoverride/testcomment"
		set -x
	fi
}
