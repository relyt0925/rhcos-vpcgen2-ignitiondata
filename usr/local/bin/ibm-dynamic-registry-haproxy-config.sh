#!/usr/bin/env bash
set -x
if [[ "$PRIVATE_SERVICE_ENDPOINT_ENABLED" != "true" ]]; then
	echo "no need to setup haproxy registry config"
	exit 0
fi
mkdir -p /etc/kubernetes/ibm-registry-proxy
if [[ "$PUBLIC_SERVICE_ENDPOINT_ENABLED" == "true" ]]; then
	cp /etc/haproxytemplates/haproxy-ibm-private-registries.cfg /etc/kubernetes/ibm-registry-proxy/99-haproxy-ibm-private-registries.cfg
else
	sed '/server zone/d' /etc/haproxytemplates/haproxy-ibm-private-registries.cfg >/etc/kubernetes/ibm-registry-proxy/haproxy-ibm-private-registries.cfg
fi
chmod 0644 /etc/kubernetes/apiserver-proxy-config/99-haproxy-ibm-private-registries.cfg

cp -f /etc/haproxytemplates/ibm-registry-haproxy.yaml /etc/haproxytemplates/tmp-ibm-registry-haproxy.yaml
sed -i "s/REGIONAL_REGISTRY_HOSTNAME_VALUE/$REGIONAL_REGISTRY_ENDPOINT/g" /etc/haproxytemplates/tmp-ibm-registry-haproxy.yaml
cp /etc/haproxytemplates/tmp-ibm-registry-haproxy.yaml /etc/kubernetes/manifests/ibm-registry-haproxy.yaml
chmod 0644 /etc/kubernetes/manifests/ibm-registry-haproxy.yaml
