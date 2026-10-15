cat > /root/setup-ab.sh <<'SCRIPT'
#!/bin/bash
apk update
apk add apache2-utils

grep -q "jujutsu.K68.com" /etc/hosts || \
    echo "192.245.1.4 jujutsu.K68.com www.jujutsu.K68.com" >> /etc/hosts
SCRIPT
chmod +x /root/setup-ab.sh
