cat > /root/setup-geto.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/geto <<'EOF'
upstream api_cluster {
    server 192.245.4.5 weight=3 max_fails=2 fail_timeout=5s;
    server 192.245.4.6 weight=1 max_fails=2 fail_timeout=5s;
    server 192.245.4.7 backup;
}

server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;

    set_real_ip_from 192.245.1.4;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/geto /etc/nginx/sites-enabled/geto
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-geto.sh
