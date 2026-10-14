#!/bin/bash
# utahime - /root/setup-dns.sh - DNS MASTER
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 dnsutils
ln -sf /etc/init.d/named /etc/init.d/bind9
mkdir -p /etc/bind/jarkom

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K68.com" {
    type master;
    notify yes;
    also-notify { 192.245.1.3; };
    allow-transfer { 192.245.1.3; };
    file "/etc/bind/jarkom/jujutsu.K68.com";
};

zone "1.245.192.in-addr.arpa" {
    type master;
    notify yes;
    also-notify { 192.245.1.3; };
    allow-transfer { 192.245.1.3; };
    file "/etc/bind/jarkom/1.245.192.in-addr.arpa";
};
EOF

cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    forwarders {
        192.168.122.1;
    };
    dnssec-validation no;
    allow-query { any; };
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

cat > /etc/bind/jarkom/jujutsu.K68.com <<'EOF'
$TTL    604800
@       IN      SOA     utahime.jujutsu.K68.com. root.jujutsu.K68.com. (
                        2026101503 ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.K68.com.
@       IN      NS      shoko.jujutsu.K68.com.

@       IN      A       192.245.1.4

utahime IN      A       192.245.1.2
shoko   IN      A       192.245.1.3
gojo    IN      A       192.245.1.4

www     IN      CNAME   jujutsu.K68.com.
EOF

cat > /etc/bind/jarkom/1.245.192.in-addr.arpa <<'EOF'
$TTL    604800
@       IN      SOA     utahime.jujutsu.K68.com. root.jujutsu.K68.com. (
                        2026101503 ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.K68.com.
@       IN      NS      shoko.jujutsu.K68.com.

2       IN      PTR     utahime.jujutsu.K68.com.
3       IN      PTR     shoko.jujutsu.K68.com.
4       IN      PTR     jujutsu.K68.com.
EOF

service bind9 restart
