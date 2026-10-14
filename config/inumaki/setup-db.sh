#!/bin/bash
# inumaki - /root/setup-db.sh  - DB SLAVE (versi autostart)
# Posisi binlog dibaca otomatis dari master, jadi tidak perlu diketik manual tiap restart.
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server

cat > /etc/mysql/mariadb.conf.d/99-slave.cnf <<'EOF'
[mysqld]
server-id        = 2
bind-address     = 0.0.0.0
EOF

service mariadb restart
sleep 8

# Skema dibuat lokal juga, supaya ada walau DDL dari master terlewat
mysql <<'EOF'
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

# Tunggu master siap menerima koneksi, maksimal 60 detik
for i in $(seq 1 30); do
    mysql -h 192.245.4.8 -u replica -preplicapass -e "SELECT 1;" >/dev/null 2>&1 && break
    sleep 2
done

# Baca posisi binlog master saat ini
STATUS=$(mysql -h 192.245.4.8 -u replica -preplicapass -N -e "SHOW MASTER STATUS;")
MFILE=$(echo "$STATUS" | awk '{print $1}')
MPOS=$(echo "$STATUS" | awk '{print $2}')

if [ -n "$MFILE" ] && [ -n "$MPOS" ]; then
    mysql <<EOF
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='192.245.4.8',
  MASTER_PORT=3306,
  MASTER_USER='replica',
  MASTER_PASSWORD='replicapass',
  MASTER_LOG_FILE='$MFILE',
  MASTER_LOG_POS=$MPOS;
START SLAVE;
EOF
fi
