cat > /root/setup-api.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx php-fpm php-mysql

PHPV=$(ls /etc/php | head -1)
service php$PHPV-fpm start

mkdir -p /var/www/html/api
cat > /var/www/html/api/index.php <<'EOF'
<?php
header('Content-Type: application/json');
$remote = $_SERVER['REMOTE_ADDR'];
$client = $remote;
if ($remote === '192.245.4.2' && !empty($_SERVER['HTTP_X_REAL_IP'])) {
    $client = $_SERVER['HTTP_X_REAL_IP'];
}
try {
    $pdo = new PDO('mysql:host=192.245.4.8;dbname=db_shibuya_K68', 'shibuya', 'shibuyapass');
    $st = $pdo->prepare('INSERT INTO request_logs (endpoint, client_ip, worker) VALUES (?,?,?)');
    $st->execute([$_SERVER['REQUEST_URI'], $client, gethostname()]);
    echo json_encode(['status'=>'ok','server'=>gethostname(),'client_ip'=>$client]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status'=>'error','server'=>gethostname(),'msg'=>$e->getMessage()]);
}
EOF

cat > /etc/nginx/sites-available/jujutsu <<'EOF'
server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;
    root /var/www/html;
    index index.php;

    allow 192.245.4.2;
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
chmod +x /root/setup-api.sh
