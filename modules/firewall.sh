#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Настройка Firewall"
echo

echo "--- Текущий статус UFW ---"
if command_exists ufw; then
    ufw status numbered 2>/dev/null || echo "  UFW не активен или не настроен"
else
    echo "  UFW не установлен"
fi
echo

echo "Будет выполнено:"
echo "  - установка ufw при необходимости"
echo "  - запрет входящих подключений по умолчанию"
echo "  - разрешение SSH (порт 22)"
echo "  - включение firewall"
echo "  - вывод статуса"
echo

if ! confirm_action "Продолжить настройку Firewall"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if ! command_exists ufw; then
    echo -e "${YELLOW}[*]${NC} UFW не установлен. Устанавливаю..."
    apt update
    apt install -y ufw
fi

backup_file "/etc/default/ufw"

ufw --force reset 2>/dev/null || true

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH 2>/dev/null || ufw allow 22/tcp

ufw logging on

ufw --force enable

echo
echo "--- Статус UFW ---"
ufw status verbose

log_action "Выполнена настройка Firewall через UFW"
