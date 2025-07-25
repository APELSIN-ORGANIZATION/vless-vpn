#!/bin/zsh
##!/usr/bin/env bash # для использования bash

###############################################################################
#   server-setup.sh
###############################################################################

################################################
# 1. Переменные окружения для выполнения скрипта
################################################
SERVER_IP="server_ip"
SSH_USER="user"
SSH_PASS="password"
DOMAIN="server_domain"
EMAIL="email"

# Цвета для текста
GREEN='\033[1;32m'
NC='\033[0m'

################################################
# 2. Подготовка к выполнению скрипта
################################################
# Проверяем, установлен ли sshpass, иначе пытаемся установить
if ! command -v sshpass >/dev/null 2>&1; then
    echo "${GREEN}[INFO] Установка sshpass на локальной машине... ${NC}"
    if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install -y sshpass
    elif [[ "${OSTYPE}" == "darwin"* ]]; then
        brew install hudochenkov/sshpass/sshpass
    fi
fi


################################################
# 3. Функция для выполнения команд по ssh
################################################
run_ssh() {
    local CMD=$1
    sshpass -p "${SSH_PASS}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${SERVER_IP}" "${CMD}"
}

################################################
# 4. Обновление системы и пакетов
################################################
echo "${GREEN}[STEP] Обновление пакетов...${NC}"
run_ssh "apt update && apt upgrade -y"

################################################
# 5. Установка нужных зависимостей на сервер
################################################
echo "${GREEN}[STEP] Установка пакетов curl, nginx, ufw, snapd, uuid...${NC}"
run_ssh "apt install -y curl nginx ufw snapd uuid"

################################################
# 6. Настройка UFW
################################################
echo "${GREEN}[STEP] Настройка UFW...${NC}"
run_ssh "ufw allow ssh && ufw allow http && ufw allow https && ufw enable"
run_ssh "ufw status"

################################################
# 7. Настройка nginx
################################################
echo "${GREEN}[STEP] Правка server_name в Nginx...${NC}"
run_ssh "sed -i 's|server_name _;|server_name ${DOMAIN};|' /etc/nginx/sites-available/default && systemctl restart nginx"

################################################
# 8. Установка certbot и получение сертификата
################################################
echo "${GREEN}[STEP] Получение SSL от Let's Encrypt...${NC}"
run_ssh "snap install core; snap refresh core"
run_ssh "snap install --classic certbot && ln -s -f /snap/bin/certbot /usr/bin/certbot"
run_ssh "certbot --nginx --non-interactive --agree-tos --email ${EMAIL} -d ${DOMAIN}"
run_ssh "certbot renew --dry-run"

################################################
# 9. Установка Xray
################################################
echo "${GREEN}[STEP] Установка Xray-Core...${NC}"
run_ssh "bash -c \"\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install -u root"
run_ssh "systemctl status xray"

################################################
# 10. Перезапуск Xray
################################################
echo "${GREEN}[STEP] Перезапуск и проверка статуса Xray...${NC}"
run_ssh "systemctl restart xray && systemctl status xray"

################################################
# 11. Завершение установки
################################################
echo "=============================================="
echo "УСТАНОВКА ЗАВЕРШЕНА!"
echo "=============================================="
