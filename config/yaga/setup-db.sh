#!/bin/bash
# yaga - /root/setup-db.sh  - DB MASTER (versi autostart)
# /var/lib/mysql IKUT HILANG saat node restart, jadi skema harus dibuat ulang di sini.
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server

cat > /etc/mysql/mariadb.conf.d/99-master.cnf <<'EOF'
[mysqld]
server-id        = 1
log-bin          = mysql-bin
binlog_format    = ROW
bind-address     = 0.0.0.0
EOF

service mariadb restart
sleep 8

mysql <<'EOF'
CREATE USER IF NOT EXISTS 'replica'@'192.245.4.%' IDENTIFIED BY 'replicapass';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'replica'@'192.245.4.%';

CREATE USER IF NOT EXISTS 'shibuya'@'192.245.4.%' IDENTIFIED BY 'shibuyapass';
GRANT ALL PRIVILEGES ON db_shibuya_K68.* TO 'shibuya'@'192.245.4.%';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS db_shibuya_K68;
USE db_shibuya_K68;
CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    endpoint VARCHAR(255),
    client_ip VARCHAR(45),
    worker VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
