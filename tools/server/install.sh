#!/bin/bash
# City Alpha — установка онлайн-сервера на свой Linux-сервер (VPS: Ubuntu / Debian).
# Для бесплатного варианта без своего сервера см. README → «Онлайн» (Render.com).
#   curl -sL https://raw.githubusercontent.com/huhenbekon-byte/city-alpha/main/tools/server/install.sh | bash
# Сервер — tools/server/server.js (Node.js, без библиотек), работает как служба на порту 7777 (TCP).
set -e
PORT=${PORT:-7777}
REPO=${REPO:-https://github.com/huhenbekon-byte/city-alpha}
DIR=/opt/city-alpha
sudo apt-get update -y -q
sudo apt-get install -y -q nodejs git
sudo rm -rf $DIR
sudo git clone -q --depth 1 $REPO $DIR
sudo tee /etc/systemd/system/city-alpha.service > /dev/null <<UNIT
[Unit]
Description=City Alpha game server
After=network-online.target

[Service]
WorkingDirectory=$DIR/tools/server
Environment=PORT=$PORT
ExecStart=/usr/bin/node $DIR/tools/server/server.js
Restart=always
RestartSec=5
DynamicUser=yes

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now city-alpha
sudo iptables -I INPUT -p tcp --dport $PORT -j ACCEPT || true
if command -v ufw > /dev/null && sudo ufw status | grep -q active; then sudo ufw allow $PORT/tcp; fi
IP=$(curl -s -4 ifconfig.me || echo "АДРЕС_СЕРВЕРА")
echo "Готово! Адрес для игры: $IP:$PORT   (лог: journalctl -u city-alpha -f)"
