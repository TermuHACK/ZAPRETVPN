#!/bin/bash
set -e

# Переменные
PASS="Dvdr00"
UUID=$(cat /proc/sys/kernel/random/uuid)

# Получаем параметры из install.sh
source ~/install.sh

# Если выбрана анонимность, то добавляем настройки для дополнительных протоколов
if [ "$ANONYMITY" == "true" ]; then
    echo "Настроим анонимность..."
    # Настройка прокси (например, Tinyproxy)
    sed -i 's/^#Allow 127.0.0.1/Allow 0.0.0.0/' /etc/tinyproxy/tinyproxy.conf
    sed -i 's/^Port 8888/Port 8888/' /etc/tinyproxy/tinyproxy.conf
    systemctl restart tinyproxy
fi

# Если выбрано шифрование, то добавляем шифрованные протоколы
if [ "$ENCRYPTION" == "true" ]; then
    echo "Настроим шифрование..."
    # Настройка Shadowsocks
    cat <<EOF > ~/ss.json
{
    "server":"127.0.0.1",
    "server_port":8388,
    "password":"$PASS",
    "timeout":300,
    "method":"aes-256-gcm"
}
EOF
    echo "Shadowsocks настроен."
fi

# Если выбрана скорость, то настраиваем оптимизированные параметры
if [ "$SPEED" == "true" ]; then
    echo "Настроим оптимизацию скорости..."
    # Тут можно добавить настройки для улучшения производительности
    # Например, для Xray
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
    echo "Xray настроен."
fi

# Если выбран обход блокировок, то настраиваем соответствующие протоколы
if [ "$BYPASS" == "true" ]; then
    echo "Настроим обход блокировок..."
    # Настройка Trojan
    cat <<EOF > ~/trojan-config.json
{
  "run_type": "server",
  "local_addr": "127.0.0.1",
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
    echo "Trojan настроен."
    # Также можно добавить PPTP (или другие старые протоколы)
    echo "Добавление PPTP (старый протокол)..."
    # Настройка PPTP (если нужно)
    # Дополнительно можно добавить дополнительный скрипт для настройки PPTP, если требуется
fi

# Запуск всех сервисов через screen с Keep-Alive
screen -dmS tinyproxy bash -c "while true; do systemctl restart tinyproxy; sleep 300; done"
screen -dmS ss bash -c "while true; do ss-server -c ~/ss.json; sleep 5; done"
screen -dmS xray bash -c "while true; do xray run -config /usr/local/etc/xray/config.json; sleep 5; done"
screen -dmS trojan bash -c "while true; do ~/trojan/trojan -c ~/trojan-config.json; sleep 5; done"

# Запуск туннеля через Serveo
function start_serveo {
  PORT_PROXY=$((RANDOM%40000+10000))
  PORT_SS=$((RANDOM%40000+10000))
  PORT_XRAY=$((RANDOM%40000+10000))
  PORT_TROJAN=$((RANDOM%40000+10000))

  echo "Tinyproxy=$PORT_PROXY" > ~/ports.txt
  echo "SS=$PORT_SS" >> ~/ports.txt
  echo "Xray=$PORT_XRAY" >> ~/ports.txt
  echo "Trojan=$PORT_TROJAN" >> ~/ports.txt

  while true; do
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
      -R $PORT_PROXY:localhost:8888 \
      -R $PORT_SS:localhost:8388 \
      -R $PORT_XRAY:localhost:10086 \
      -R $PORT_TROJAN:localhost:4433 \
      serveo.net
    echo "Туннель упал, пересоздаю через 5 секунд..."
    sleep 5
  done
}

screen -dmS serveo bash -c "$(declare -f start_serveo); start_serveo"

sleep 10

# Получение внешнего IP
EXTERNAL_IP=$(curl -s ifconfig.me)
PORT_PROXY=$(awk -F "=" '/Tinyproxy/ {print $2}' ~/ports.txt)
PORT_SS=$(awk -F "=" '/SS/ {print $2}' ~/ports.txt)
PORT_XRAY=$(awk -F "=" '/Xray/ {print $2}' ~/ports.txt)
PORT_TROJAN=$(awk -F "=" '/Trojan/ {print $2}' ~/ports.txt)

# Генерация QR-кодов
mkdir -p ~/qr

SS_LINK="ss://$(echo -n "aes-256-gcm:$PASS@$EXTERNAL_IP:$PORT_SS" | base64 -w0)"
VMESS_JSON=$(jq -n --arg add "$EXTERNAL_IP" --arg id "$UUID" --arg port "$PORT_XRAY" '{
  v: "2",
  ps: "GCS-Node",
  add: $add,
  port: $port,
  id: $id,
  aid: "0",
  net: "tcp",
  type: "none",
  host: "",
  path: "",
  tls: "none"
}')
VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w0)"

qrencode -o ~/qr/shadowsocks.png "$SS_LINK"
qrencode -o ~/qr/vmess.png "$VMESS_LINK"

# Вывод инфы
cat <<EOF > ~/info.txt

Ваш внешний IP: $EXTERNAL_IP

Доступ:

- Tinyproxy (HTTP прокси):
  http://$EXTERNAL_IP:$PORT_PROXY

- Shadowsocks:
  ss://aes-256-gcm:$PASS@$EXTERNAL_IP:$PORT_SS
  QR-код: ~/qr/shadowsocks.png

- Xray (VMess):
  Адрес: $EXTERNAL_IP
  Порт: $PORT_XRAY
  UUID: $UUID
  QR-код: ~/qr/vmess.png

- Trojan:
  Адрес: $EXTERNAL_IP
  Порт: $PORT_TROJAN
  Пароль: $PASS

EOF

cat ~/info.txt

echo ""
echo "=== Чтобы посмотреть все экраны: screen -ls"
echo "=== Чтобы зайти в процесс: screen -r tinyproxy (или ss, xray, trojan, serveo)"
echo "=== Чтобы выйти из screen не останавливая процесс: Ctrl+A, потом D"
