#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"
source "$ROOT_DIR/config/default.conf"

print_header

echo "[+] Установка и настройка Fail2Ban"
echo

if command_exists fail2ban-client; then
    echo -e "${GREEN}[+]${NC} Fail2Ban установлен"
    fail2ban-client status 2>/dev/null | head -3
else
    echo -e "${YELLOW}[--]${NC} Fail2Ban не установлен"
fi
echo

echo "Будет выполнено:"
echo "  - установка Fail2Ban при необходимости"
echo "  - резервное копирование jail.local"
echo "  - настройка защиты SSH"
echo "  - включение и проверка службы"
echo

if ! confirm_action "Продолжить настройку Fail2Ban"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if ! command_exists fail2ban-client; then
    echo -e "${YELLOW}[*]${NC} Fail2Ban не установлен. Устанавливаю..."
    apt update
    apt install -y fail2ban
else
    echo -e "${GREEN}[+]${NC} Fail2Ban уже установлен"
fi

JAIL_LOCAL="/etc/fail2ban/jail.local"
backup_file "$JAIL_LOCAL"

cat > "$JAIL_LOCAL" <<EOF_CONF
[DEFAULT]
bantime = ${FAIL2BAN_BANTIME}
findtime = ${FAIL2BAN_FINDTIME}
maxretry = ${FAIL2BAN_MAXRETRY}
backend = systemd
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = ${FAIL2BAN_MAXRETRY}
logpath = %(sshd_log)s
EOF_CONF

systemctl enable fail2ban
systemctl restart fail2ban

echo
sleep 1
echo "--- Статус Fail2Ban ---"
fail2ban-client status 2>/dev/null || echo "  fail2ban не отвечает"
echo
fail2ban-client status sshd 2>/dev/null || echo "  jail sshd не активен"

log_action "Выполнена настройка Fail2Ban для SSH"
