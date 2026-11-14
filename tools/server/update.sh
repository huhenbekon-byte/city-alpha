#!/bin/bash
# Обновить сервер до последней версии из GitHub и перезапустить.
set -e
sudo git -C /opt/city-alpha pull -q
sudo systemctl restart city-alpha
echo "Обновлено и перезапущено."
