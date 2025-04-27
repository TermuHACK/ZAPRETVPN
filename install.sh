#!/bin/bash
set -e

# Обновление и установка нужного софта
apt update
apt install -y tinyproxy shadowsocks-libev curl wget unzip socat screen net-tools qrencode jq

# Переменные
PASS="Dvdr00"
UUID=$(cat /proc/sys/kernel/random/uuid)

# Установка Xray-core
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

# Установка Trojan
wget https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
tar -xvf trojan-1.16.0-linux-amd64.tar.xz
cd trojan || exit
chmod +x trojan
cd ..

# Настройка Tinyproxy
sed -i 's/^#Allow 127.0.0.1/Allow 0.0.0.0/' /etc/tinyproxy/tinyproxy.conf
sed -i 's/^Port 8888/Port 8888/' /etc/tinyproxy/tinyproxy.conf

# Настройка Shadowsocks
cat <<EOF > ~/ss.json
{
    "server":"0.0.0.0",
    "server_port":8388,
    "password":"$PASS",
    "timeout":300,
    "method":"aes-256-gcm"
}
EOF

# Настройка Xray (VMess)
mkdir -p /usr/local/etc/xray
cat <<EOF > /usr/local/etc/xray/config.json
{
  "inbounds": [{
    "port": 10086,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "alterId": 0
      }]
    },
    "streamSettings": {
      "network": "tcp"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

# Настройка Trojan
cat <<EOF > ~/trojan-config.json
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 4433,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": ["$PASS"],
  "ssl": {
    "verify": false,
    "cert": "",
    "key": ""
  }
}
EOF

echo "✅ Базовая установка завершена! Теперь запусти setup.sh"
