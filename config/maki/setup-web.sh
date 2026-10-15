cat > /root/setup-web.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx php-fpm

PHPV=$(ls /etc/php | head -1)
service php$PHPV-fpm start

cat > /var/www/html/index.php <<'EOF'
<?php echo "Frontend: " . gethostname() . "\n"; ?>
EOF

cat > /etc/nginx/sites-available/jujutsu <<'EOF'
server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;
    root /var/www/html;
    index index.php;

    allow 192.245.1.4;
    deny all;

    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/phpPHPVER-fpm.sock;
    }
}
EOF
sed -i "s/PHPVER/$PHPV/" /etc/nginx/sites-available/jujutsu

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/jujutsu /etc/nginx/sites-enabled/jujutsu
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-web.sh
