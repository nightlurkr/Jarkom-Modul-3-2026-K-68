#!/bin/bash
# Dipasang di 12 host infrastruktur (/root/dns.sh)
# Resolver awal supaya apt-get bisa jalan. Diganti ke DNS internal nanti.
echo "nameserver 192.168.122.1" > /etc/resolv.conf
