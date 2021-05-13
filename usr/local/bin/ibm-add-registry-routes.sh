#!/usr/bin/env bash
set -x
ip addr add 169.254.2.1/32 brd 169.254.2.1 scope host dev lo
ip route add 169.254.2.1/32 dev lo scope link src 169.254.2.1
if grep "169.254.2.1" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.1.*/169.254.2.1 registry.ng.bluemix.net us.icr.io/g" /etc/hosts
else
	echo "169.254.2.1 registry.ng.bluemix.net us.icr.io" >> /etc/hosts
fi

ip addr add 169.254.2.2/32 brd 169.254.2.2 scope host dev lo
ip route add 169.254.2.2/32 dev lo scope link src 169.254.2.2
if grep "169.254.2.2" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.2.*/169.254.2.2 jp.icr.io/g" /etc/hosts
else
	echo "169.254.2.2 jp.icr.io" >> /etc/hosts
fi

ip addr add 169.254.2.3/32 brd 169.254.2.3 scope host dev lo
ip route add 169.254.2.3/32 dev lo scope link src 169.254.2.3
if grep "169.254.2.3" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.3.*/169.254.2.3 de.icr.io registry.eu-de.bluemix.net/g" /etc/hosts
else
	echo "169.254.2.3 de.icr.io registry.eu-de.bluemix.net" >> /etc/hosts
fi

ip addr add 169.254.2.4/32 brd 169.254.2.4 scope host dev lo
ip route add 169.254.2.4/32 dev lo scope link src 169.254.2.4
if grep "169.254.2.4" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.4.*/169.254.2.4 uk.icr.io registry.eu-gb.bluemix.net/g" /etc/hosts
else
	echo "169.254.2.4 uk.icr.io registry.eu-gb.bluemix.net" >> /etc/hosts
fi

ip addr add 169.254.2.5/32 brd 169.254.2.5 scope host dev lo
ip route add 169.254.2.5/32 dev lo scope link src 169.254.2.5
if grep "169.254.2.5" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.5.*/169.254.2.5 registry.au-syd.bluemix.net au.icr.io/g" /etc/hosts
else
	echo "169.254.2.5 registry.au-syd.bluemix.net au.icr.io" >> /etc/hosts
fi

ip addr add 169.254.2.6/32 brd 169.254.2.6 scope host dev lo
ip route add 169.254.2.6/32 dev lo scope link src 169.254.2.6
if grep "169.254.2.6" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.6.*/169.254.2.6 registry.bluemix.net icr.io cp.icr.io/g" /etc/hosts
else
	echo "169.254.2.6 registry.bluemix.net icr.io cp.icr.io" >> /etc/hosts
fi

ip addr add 169.254.2.7/32 brd 169.254.2.7 scope host dev lo
ip route add 169.254.2.7/32 dev lo scope link src 169.254.2.7
if grep "169.254.2.6" /etc/hosts; then
  # shellcheck disable=SC2154
	sed -i "s/^169.254.2.7.*/169.254.2.7 fr2.icr.io/g" /etc/hosts
else
	echo "169.254.2.7 fr2.icr.io" >> /etc/hosts
fi
