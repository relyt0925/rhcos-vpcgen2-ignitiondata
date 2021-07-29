#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2086,SC2046,SC2162,SC2116
LOCKFILE=/var/lock/irq-rebalance.lock

# Determine the number of CPUs on the system
NRCPU=$(nproc)

MASK=1
for i in $(seq 1 $(($NRCPU - 1))); do MASK=$((MASK | (1 << $i))); done
CPULIST=$(printf "0x%x\n" $MASK)

declare -a CPUARRAY
# Initialize the array based on the CPULIST mask
CNT=0
for i in $(seq 0 $((NRCPU - 1))); do
	if [ $(echo $((CPULIST & (1 << i)))) != 0 ]; then
		CPUARRAY[$CNT]=$i
		CNT=$((CNT + 1))
	fi
done

# Need a small delay before running this script to ensure IRQs for network
# interfaces are written to /proc/interrupts table
sleep 2

if [ -e $LOCKFILE ]; then
	echo "Found lock file $LOCKFILE ($(date)). Caller is ($(ps -p $PPID -o pid= -o cmd=)). $0 is already running, exiting"
	exit 1
fi

touch $LOCKFILE

echo "NRCPUS=$NRCPU IRQ cpuset: [ ${CPUARRAY[*]} ]"

################################################
# Main loop: Read IRQ list from /proc/interrupts
################################################
CPUIDX=0
while read line; do
	IRQ=$(echo $line | awk '{print $1}' | cut -d ':' -f1)
	IRQNAME=$(echo $line | awk '{print $NF}')
	printf '%f' "$IRQ" >/dev/null 2>&1
	rc=$?

	# Skip all non-numeric IRQs and header row
	if [ $rc == "1" ]; then
		continue
	fi

	# Skip all reserved IRQs (start from IRQ 14)
	if [ $IRQ -lt 14 ]; then
		continue
	fi

	# Check if smp_affinity file exists for IRQ, if not skip this IRQ
	if [ ! -e /proc/irq/$IRQ/smp_affinity_list ]; then
		continue
	fi

	# Set IRQ CPU affinity
	echo ${CPUARRAY[$CPUIDX]} >/proc/irq/$IRQ/smp_affinity_list 2>/dev/null
	rc=$?

	printf "IRQ: %s (%s) -> %s (rc=%s)\n" "$IRQ" "$IRQNAME" $(cat /proc/irq/$IRQ/smp_affinity) $rc

	if [ $CPUIDX -lt $((CNT - 1)) ]; then
		CPUIDX=$((CPUIDX + 1))
	else
		CPUIDX=0
	fi

done </proc/interrupts

# remove lock file
rm -f $LOCKFILE >/dev/null 2>/dev/null
