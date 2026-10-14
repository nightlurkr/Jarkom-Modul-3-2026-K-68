#!/bin/bash
# tengen - /root/setup-dhcp.sh  (versi SOAL 4)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;

default-lease-time 600;
max-lease-time 7200;

option domain-name-servers 192.245.1.2, 192.245.1.3;

# ---------- DHCP class Network 2 (pisah berdasarkan MAC) ----------
# Pool 1 = itadori, fushiguro
class "pool1" {
    match if (substring(hardware,1,6) = 02:42:17:51:a0:00)
         or (substring(hardware,1,6) = 02:42:1f:87:4e:00);
}

# Pool 2 = zenin, okkotsu
class "pool2" {
    match if (substring(hardware,1,6) = 02:42:e8:81:d1:00)
         or (substring(hardware,1,6) = 02:42:21:d8:76:00);
}

# ---------- Network 4 : subnet lokal, tanpa pool ----------
subnet 192.245.4.0 netmask 255.255.255.0 {
}

# ---------- Network 2 : Divisi A ----------
# Rentang .2.36 - .2.69 sengaja TIDAK ditulis -> tidak pernah dialokasikan.
subnet 192.245.2.0 netmask 255.255.255.0 {
    option routers 192.245.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.2.255;

    pool {
        allow members of "pool1";
        range 192.245.2.10 192.245.2.35;
    }

    pool {
        allow members of "pool2";
        range 192.245.2.70 192.245.2.95;
    }
}

# ---------- Network 3 : Divisi B ----------
subnet 192.245.3.0 netmask 255.255.255.0 {
    range 192.245.3.10 192.245.3.89;
    option routers 192.245.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.3.255;
}
EOF

mkdir -p /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases

dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart
