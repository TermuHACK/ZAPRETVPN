#!/bin/bash
set -e

# Считываем UUID
UUID=$(cat ~/uuid.txt)

echo "Выберите профиль:"
echo "1) Анонимность"
echo "2) Шифрование"
echo "3) Скорость"
echo "4) Обход блокировок"

read -p "Введите номер профиля: " profile

# Генерация портов
PORT_PROXY=$((RANDOM%40000+10000))
PORT_SS=$((RANDOM%40000+10000))
PORT_XRAY=$((RANDOM%40000+10000))
PORT_TROJAN=$((RANDOM%40000+10000))

# Сохраняем порты
echo "Tinyproxy=$PORT_PROXY" > ~/ports.txt
echo "SS=$PORT_SS" >> ~/ports.txt
echo "Xray=$PORT_XRAY" >> ~/ports.txt
echo "Trojan=$PORT_TROJAN" >> ~/ports.txt

# Запускаем выбранные сервисы в screen
case $profile in
  1)
    echo "Выбран профиль: Анонимность (Tinyproxy + SS)"
    screen -dmS tinyproxy bash -c "tinyproxy -d; sleep infinity"
    screen -dmS ss bash -c "ss-server -c ~/ss.json; sleep infinity"
    ;;
  2)
    echo "Выбран профиль: Шифрование (SS + Trojan)"
    screen -dmS ss bash -c "ss-server -c ~/ss.json; sleep infinity"
    screen -dmS trojan bash -c "~/trojan/trojan -c ~/trojan-config.json; sleep infinity"
    ;;
  3)
    echo "Выбран профиль: Скорость (Tinyproxy + SS без screen)"
    tinyproxy -d &
    ss-server -c ~/ss.json &
    ;;
  4)
    echo "Выбран профиль: Обход блокировок (SS + Xray + Trojan)"
    screen -dmS ss bash -c "ss-server -c ~/ss.json; sleep infinity"
    screen -dmS xray bash -c "xray run -config /usr/local/etc/xray/config.json; sleep infinity"
    screen -dmS trojan bash -c "~/trojan/trojan -c ~/trojan-config.json; sleep infinity"
    ;;
  *)
    echo "Неверный ввод!"
    exit 1
    ;;
esac

# Настройка туннеля Serveo
function start_serveo {
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

# Генерация QR-кодов
sleep 10

EXTERNAL_IP=$(curl -s ifconfig.me)

mkdir -p ~/qr

SS_LINK="ss://$(echo -n "aes-256-gcm:Dvdr00@$EXTERNAL_IP:$PORT_SS" | base64 -w0)"
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

echo ""
echo "=== Всё готово! Ваш IP: $EXTERNAL_IP"
echo "=== QR-коды в папке ~/qr"
echo "=== Текущие порты в ~/ports.txt"
