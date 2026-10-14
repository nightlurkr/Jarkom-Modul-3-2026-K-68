#!/bin/bash
# jichi - /root/nat.sh
# ip_forward + source NAT. Dipanggil dari "up bash /root/nat.sh" di interfaces.
# Pakai -C (check) sebelum -A supaya rule tidak menumpuk tiap kali node restart.

sysctl -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
