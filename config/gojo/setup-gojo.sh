cat > /root/setup-gojo.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

# Tambahkan direktif cache dan rate limit ke nginx.conf kalau belum ada
grep -q "jujutsu_cache" /etc/nginx/nginx.conf || \
    sed -i '/include \/etc\/nginx\/sites-enabled\/\*/a\    proxy_cache_path /var/cache/nginx/jujutsu levels=1:2 keys_zone=jujutsu_cache:10m inactive=10m max_size=1g;\n    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;' /etc/nginx/nginx.conf

mkdir -p /var/cache/nginx/jujutsu
chown -R www-data:www-data /var/cache/nginx

cat > /etc/nginx/sites-available/gojo <<'EOF'
upstream web_frontend {
    server 192.245.4.3;
    server 192.245.4.4;
}

upstream geto_api {
    server 192.245.4.2;
}

server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;

    location / {
        proxy_pass http://web_frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_cache jujutsu_cache;
        proxy_cache_valid 200 10m;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        add_header X-Cache-Status $upstream_cache_status;
        proxy_ignore_headers Cache-Control Expires Set-Cookie;
    }

    location /api {
        limit_req zone=api_limit burst=1 nodelay;
        limit_req_status 429;

        proxy_pass http://geto_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/gojo /etc/nginx/sites-enabled/gojo
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-gojo.sh
