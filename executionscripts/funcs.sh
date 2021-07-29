#!/usr/bin/env bash
export NODEPOOL_INFO_FILE="/tmp/nodepools_for_cluster"

retry_function() {
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

retrieve_nodepools_for_cluster() {
	kubectl get nodepools -n "$NODE_POOL_NAMESPACE" -l clusterid="$HOSTED_CLUSTERID" --no-headers >"$NODEPOOL_INFO_FILE"
}

reconcile_nodepool_metadata() {
	PATCHSTRING='[{"op": "replace", "path": "/spec/release/image", "value":"'${RELEASE_IMAGE}'"}]'
	kubectl -n "$NODE_POOL_NAMESPACE" patch nodepool "$NODE_POOL_NAME" --type='json' -p="$PATCHSTRING"
}

main() {
	retry_function retrieve_nodepools_for_cluster || return 1
	while read -r NODEPOOL_INFO; do
		# shellcheck disable=SC2155
		export NODE_POOL_NAME=$(echo "$NODEPOOL_INFO" | awk '{print $1}')
		retry_function reconcile_nodepool_metadata || return 1
	done <"$NODEPOOL_INFO_FILE"
}
