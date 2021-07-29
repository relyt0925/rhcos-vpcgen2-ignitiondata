#!/usr/bin/env bash
set -x
cp -f /etc/haproxytemplates/haproxy-ibm-master-endpoints.cfg /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
if [[ -z "$MASTER_PROXY_IP" ]] || [[ -z "$MASTER_PROXY_PORT" ]]; then
	echo "proxy ips need to be defined"
	exit 1
fi
sed -i "s/MASTER_PROXY_IP_VALUE/$MASTER_PROXY_IP/g" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
sed -i "s/MASTER_PROXY_PORT_VALUE/$MASTER_PROXY_PORT/g" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg

# shellcheck disable=SC2059
printf "$MASTER_ENDPOINTS_CSV" >/tmp/master_endpoints
if [[ -z "$PRIMARY_ENDPOINTS_CSV" ]]; then
	while read -rd, endpoint; do
		if [[ "$endpoint" == *"private"* ]]; then
			PRIMARY_ENDPOINTS_CSV="$endpoint,${PRIMARY_ENDPOINTS_CSV}"
		else
			BACKUP_ENDPOINTS_CSV="$endpoint,${PRIMARY_ENDPOINTS_CSV}"
		fi
	done </tmp/master_endpoints
fi
if [[ -z "$PRIMARY_ENDPOINTS_CSV" ]]; then
	PRIMARY_ENDPOINTS_CSV="$BACKUP_ENDPOINTS_CSV"
	BACKUP_ENDPOINTS_CSV=""
fi
# shellcheck disable=SC2059
printf "$PRIMARY_ENDPOINTS_CSV" >/tmp/primary_endpoints
i=0
while read -rd, primary_endpoint; do
	replace_address_string="PRIMARY_ENDPOINT_${i}_ADDRESS_VALUE"
	replace_port_string="PRIMARY_ENDPOINT_${i}_PORT_VALUE"
	sed -i "s/$replace_address_string/$primary_endpoint/g" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
	sed -i "s/$replace_port_string/$MASTER_SERVER_PORT/g" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
	i=$((i + 1))
done </tmp/primary_endpoints
#Remove any extra
while ((i < 3)); do
	replace_address_string="PRIMARY_ENDPOINT_${i}_ADDRESS_VALUE"
	sed -i "/$replace_address_string/d" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
	i=$((i + 1))
done

i=0
# shellcheck disable=SC2059
printf "$BACKUP_ENDPOINTS_CSV" >/tmp/backup_endpoints
while read -rd, primary_endpoint; do
	replace_address_string="BACKUP_ENDPOINT_${i}_ADDRESS_VALUE"
	replace_port_string="BACKUP_ENDPOINT_${i}_PORT_VALUE"
	sed -i "s/$replace_address_string/$primary_endpoint/g" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
	sed -i "s/$replace_port_string/$MASTER_SERVER_PORT/g" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
	i=$((i + 1))
done </tmp/backup_endpoints
#Remove any extra
while ((i < 3)); do
	replace_address_string="BACKUP_ENDPOINT_${i}_ADDRESS_VALUE"
	sed -i "/$replace_address_string/d" /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg
	i=$((i + 1))
done
cp /etc/haproxytemplates/tmp-haproxy-ibm-master-endpoints.cfg /etc/kubernetes/apiserver-proxy-config/haproxy.cfg
chmod 0644 /etc/kubernetes/apiserver-proxy-config/haproxy.cfg
