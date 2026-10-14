#!/bin/bash
# jichi - /root/setup-relay.sh  (SOAL 3)
# DHCP Relay: teruskan permintaan client Net 2 & Net 3 ke tengen di Net 4.

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y isc-dhcp-relay

cat > /etc/default/isc-dhcp-relay <<'EOF'
SERVERS="192.245.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EOF

service isc-dhcp-relay restart
