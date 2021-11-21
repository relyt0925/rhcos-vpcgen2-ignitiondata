#!/usr/bin/env bash
set -x
ip addr delete 169.254.2.1/32 dev lo
ip route del 169.254.2.1/32 dev lo scope link src 169.254.2.1
sed -i '/^169.254.2.1 /d' /etc/hosts

ip addr delete 169.254.2.2/32 dev lo
ip route del 169.254.2.2/32 dev lo scope link src 169.254.2.2
sed -i '/^169.254.2.2 /d' /etc/hosts

ip addr delete 169.254.2.3/32 dev lo
ip route del 169.254.2.3/32 dev lo scope link src 169.254.2.3
sed -i '/^169.254.2.3 /d' /etc/hosts

ip addr delete 169.254.2.4/32 dev lo
ip route del 169.254.2.4/32 dev lo scope link src 169.254.2.4
sed -i '/^169.254.2.4 /d' /etc/hosts

ip addr delete 169.254.2.5/32 dev lo
ip route del 169.254.2.5/32 dev lo scope link src 169.254.2.5
sed -i '/^169.254.2.5 /d' /etc/hosts

ip addr delete 169.254.2.6/32 dev lo
ip route del 169.254.2.6/32 dev lo scope link src 169.254.2.6
sed -i '/^169.254.2.6 /d' /etc/hosts

ip addr delete 169.254.2.7/32 dev lo
ip route del 169.254.2.7/32 dev lo scope link src 169.254.2.7
sed -i '/^169.254.2.7 /d' /etc/hosts

ip addr delete 169.254.2.8/32 dev lo
ip route del 169.254.2.8/32 dev lo scope link src 169.254.2.8
sed -i '/^169.254.2.8 /d' /etc/hosts

ip addr delete 169.254.2.9/32 dev lo
ip route del 169.254.2.9/32 dev lo scope link src 169.254.2.9
sed -i '/^169.254.2.9 /d' /etc/hosts

ip addr delete 169.254.2.10/32 dev lo
ip route del 169.254.2.10/32 dev lo scope link src 169.254.2.10
sed -i '/^169.254.2.10 /d' /etc/hosts
