#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Анализ системы"
echo

echo "--- Системная информация ---"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  ОС: ${NAME:-Не определено} ${VERSION:-}"
else
    echo "  ОС: $(uname -s)"
fi
echo "  Ядро: $(uname -r)"
echo "  Архитектура: $(uname -m)"
echo "  Uptime: $(uptime -p 2>/dev/null || uptime | awk -F, '{print $1}')"
echo "  Hostname: $(hostname 2>/dev/null || uname -n)"
echo "  Пользователь: $(whoami)"
echo "  Root-права: $([[ $EUID -eq 0 ]] && echo "есть" || echo "нет")"
echo

echo "--- Ресурсы ---"
if command_exists free; then
    echo "  Память: $(free -h | awk '/^Mem:/ {print $3 " / " $2 " used"}')"
    echo "  Swap:   $(free -h | awk '/^Swap:/ {print $3 " / " $2 " used"}')"
fi
if command_exists df; then
    echo "  Корневой раздел: $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}')"
fi
echo

echo "--- Основные утилиты ---"
for tool in bash sudo systemctl sshd ufw fail2ban-client journalctl auditctl aa-status firejail unattended-upgrades pwquality; do
    if command_exists "$tool"; then
        echo -e " ${GREEN}[OK]${NC} $tool"
    else
        echo -e " ${YELLOW}[--]${NC} $tool"
    fi
done
echo

echo "--- Сетевые адреса ---"
if command_exists ip; then
    ip -br address 2>/dev/null || true
fi
echo

echo "--- Активные службы ---"
if command_exists systemctl; then
    systemctl list-units --type=service --state=running --no-legend 2>/dev/null | head -10 | awk '{print "  " $1}'
    total=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
    echo "  ... и ещё $((total - 10)) служб (всего: $total запущено)"
fi

log_action "Выполнен анализ системы"
