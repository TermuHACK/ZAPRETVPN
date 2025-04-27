#!/bin/bash
set -e

# Обновление и установка нужного софта
apt update
apt install -y tinyproxy shadowsocks-libev curl wget unzip socat screen net-tools qrencode jq openssh-client

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

# Меню выбора
echo "Выберите параметры настройки:"
echo "1. Анонимность"
echo "2. Шифрование"
echo "3. Скорость"
echo "4. Обход блокировок"
read -p "Введите номер (1-4): " privacy_choice

# Базовая настройка в зависимости от выбора
case $privacy_choice in
    1)
        echo "Вы выбрали Анонимность."
        ANONYMITY="true"
        ;;
    2)
        echo "Вы выбрали Шифрование."
        ENCRYPTION="true"
        ;;
    3)
        echo "Вы выбрали Скорость."
        SPEED="true"
        ;;
    4)
        echo "Вы выбрали Обход блокировок."
        BYPASS="true"
        ;;
    *)
        echo "Неверный выбор. Выход."
        exit 1
        ;;
esac

# Запуск установки и перенаправление в setup.sh
echo "Настройка завершена. Перейдите к setup.sh для настройки профилей."
