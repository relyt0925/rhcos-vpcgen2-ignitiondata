#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2086,SC2046
set -x
set -e
NODE_SIZES_ENV=${NODE_SIZES_ENV:-/etc/node-sizing.env}

function dynamic_memory_sizing() {
	total_memory=$(free -g | awk '/^Mem:/{print $2}')
	# total_memory=8 test the recommended values by modifying this value
	recommended_systemreserved_memory=0
	if (($total_memory <= 4)); then # 25% of the first 4GB of memory
		# shellcheck disable=SC2086
		recommended_systemreserved_memory=$(echo $total_memory 0.25 | awk '{print $1 * $2}')
		total_memory=0
	else
		recommended_systemreserved_memory=1
		total_memory=$((total_memory - 4))
	fi
	if (($total_memory <= 4)); then # 20% of the next 4GB of memory (up to 8GB)
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory $(echo $total_memory 0.20 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
		total_memory=0
	else
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory 0.80 | awk '{print $1 + $2}')
		total_memory=$((total_memory - 4))
	fi
	if (($total_memory <= 8)); then # 10% of the next 8GB of memory (up to 16GB)
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory $(echo $total_memory 0.10 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
		total_memory=0
	else
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory 0.80 | awk '{print $1 + $2}')
		total_memory=$((total_memory - 8))
	fi
	if (($total_memory <= 112)); then # 6% of the next 112GB of memory (up to 128GB)
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory $(echo $total_memory 0.06 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
		total_memory=0
	else
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory 6.72 | awk '{print $1 + $2}')
		total_memory=$((total_memory - 112))
	fi
	if (($total_memory >= 0)); then # 2% of any memory above 128GB
		recommended_systemreserved_memory=$(echo $recommended_systemreserved_memory $(echo $total_memory 0.02 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
	fi
	echo "SYSTEM_RESERVED_MEMORY=${recommended_systemreserved_memory}Gi" >>${NODE_SIZES_ENV}
}

function dynamic_cpu_sizing() {
	total_cpu=$(getconf _NPROCESSORS_ONLN)
	recommended_systemreserved_cpu=0
	if (($total_cpu <= 1)); then # 6% of the first core
		recommended_systemreserved_cpu=$(echo $total_cpu 0.06 | awk '{print $1 * $2}')
		total_cpu=0
	else
		recommended_systemreserved_cpu=0.06
		total_cpu=$((total_cpu - 1))
	fi
	if (($total_cpu <= 1)); then # 1% of the next core (up to 2 cores)
		recommended_systemreserved_cpu=$(echo $recommended_systemreserved_cpu $(echo $total_cpu 0.01 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
		total_cpu=0
	else
		recommended_systemreserved_cpu=$(echo $recommended_systemreserved_cpu 0.01 | awk '{print $1 + $2}')
		total_cpu=$((total_cpu - 1))
	fi
	if (($total_cpu <= 2)); then # 0.5% of the next 2 cores (up to 4 cores)
		recommended_systemreserved_cpu=$(echo $recommended_systemreserved_cpu $(echo $total_cpu 0.005 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
		total_cpu=0
	else
		recommended_systemreserved_cpu=$(echo $recommended_systemreserved_cpu 0.01 | awk '{print $1 + $2}')
		total_cpu=$((total_cpu - 2))
	fi
	if (($total_cpu >= 0)); then # 0.25% of any cores above 4 cores
		recommended_systemreserved_cpu=$(echo $recommended_systemreserved_cpu $(echo $total_cpu 0.0025 | awk '{print $1 * $2}') | awk '{print $1 + $2}')
	fi
	echo "SYSTEM_RESERVED_CPU=${recommended_systemreserved_cpu}" >>${NODE_SIZES_ENV}
}

function dynamic_ephemeral_sizing() {
	# This should correspond to the hard eviction parameters
	KUBELET_DISK_SIZE_BYTES="$(df /var/lib/kubelet -B 1 | awk 'END{print $2}')"
	EPHERMERAL_RESERVATION_BYTES=$(echo $KUBELET_DISK_SIZE_BYTES 0.10 | awk '{printf "%d", $1 * $2}')
	echo "EPHERMERAL_RESERVATION_BYTES=${EPHERMERAL_RESERVATION_BYTES}" >>${NODE_SIZES_ENV}
}

function dynamic_pid_sizing() {
	threads_max=$(cat /proc/sys/kernel/threads-max)
	max_map_count_val=$(echo $threads_max 2 | awk '{printf "%d", $1 * $2}')
	cat >/etc/sysctl.d/90-ibm-threads-max.conf <<EOF
kernel.pid_max=$threads_max
vm.max_map_count=$max_map_count_val
EOF
	chmod 0644 /etc/sysctl.d/90-ibm-threads-max.conf
	#ensure sysctl params are loaded
	set +e
	sysctl --system
	set -e
	POD_PID_MAX_PERCENTAGE=0.35
	SYSTEM_RESERVED_PIDS_PERCENTAGE=0.2
	if ((threads_max >= 500000)); then
		POD_PID_MAX_PERCENTAGE=0.45
		SYSTEM_RESERVED_PIDS_PERCENTAGE=0.05
	elif ((threads_max >= 200000)); then
		POD_PID_MAX_PERCENTAGE=0.4
		SYSTEM_RESERVED_PIDS_PERCENTAGE=0.1
	fi
	POD_PID_MAX=$(echo $threads_max $POD_PID_MAX_PERCENTAGE | awk '{printf "%d", $1 * $2}')
	SYSTEM_RESERVED_PIDS=$(echo $threads_max $SYSTEM_RESERVED_PIDS_PERCENTAGE | awk '{printf "%d", $1 * $2}')
	cat >/etc/crio/crio.conf.d/03-pid-max <<EOF
[crio]
[crio.runtime]
pids_limit = $POD_PID_MAX
EOF
	chmod 0644 /etc/crio/crio.conf.d/03-pid-max
	echo "SYSTEM_RESERVED_PIDS=${SYSTEM_RESERVED_PIDS}" >>${NODE_SIZES_ENV}
	echo "POD_PID_MAX=${POD_PID_MAX}" >>${NODE_SIZES_ENV}
}

function max_pods_sizing() {
	TOTAL_CPUS=$(nproc)
	PROPOSED_MAX_PODS=$(echo $TOTAL_CPUS 10 | awk '{printf "%d", $1 * $2}')
	if ((PROPOSED_MAX_PODS < 110)); then
		PROPOSED_MAX_PODS=110
	elif ((PROPOSED_MAX_PODS > 250)); then
		PROPOSED_MAX_PODS=250
	fi
	echo "MAX_PODS=${PROPOSED_MAX_PODS}" >>${NODE_SIZES_ENV}
}

function dynamic_node_sizing() {
	rm -f ${NODE_SIZES_ENV}
	dynamic_memory_sizing
	dynamic_cpu_sizing
	dynamic_ephemeral_sizing
	dynamic_pid_sizing
	max_pods_sizing
}

function static_node_sizing() {
	rm -f ${NODE_SIZES_ENV}
	echo "SYSTEM_RESERVED_MEMORY=$1" >>${NODE_SIZES_ENV}
	echo "SYSTEM_RESERVED_CPU=$2" >>${NODE_SIZES_ENV}
}

if [ $1 == "true" ]; then
	dynamic_node_sizing
elif [ $1 == "false" ]; then
	static_node_sizing $2 $3
else
	echo "Unrecongnized command line option. Valid options are \"true\" or \"false\""
fi
