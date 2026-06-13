#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Защита системных служб"
echo

echo "--- Активные службы ---"
total_enabled=$(systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | wc -l)
total_running=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
echo "  Включено служб: $total_enabled"
echo "  Запущено служб: $total_running"
echo

echo "--- Проверка неиспользуемых/опасных служб ---"
SERVICES=(
    "telnet" "telnetd"
    "rsh-server" "rlogin" "rsh"
    "tftp" "tftpd"
    "vsftpd" "pure-ftpd" "proftpd"
    "samba" "smbd" "nmbd"
    "cups" "cups-browsed"
    "avahi-daemon"
    "bluetooth"
    "nfs-server" "nfs-kernel-server" "rpcbind"
    "slapd"
    "dovecot"
    "postfix" "exim4"
    "apache2" "nginx"
    "mysql" "mariadb"
    "named" "bind9"
    "rsync"
    "inetd" "xinetd"
    "snmpd"
)

found_any=false
for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files 2>/dev/null | grep -qE "^\s*${svc}\."; then
        found_any=true
        if systemctl is-active "$svc" 2>/dev/null | grep -q "active"; then
            echo -e "  ${RED}[!]${NC} $svc — АКТИВЕН (рекомендуется отключить)"
        elif systemctl is-enabled "$svc" 2>/dev/null | grep -q "enabled"; then
            echo -e "  ${YELLOW}[*]${NC} $svc — включён, но не активен"
        else
            echo -e "  ${YELLOW}[*]${NC} $svc — установлен, но отключён"
        fi
    fi
done

if ! $found_any; then
    echo "  Неиспользуемые службы не обнаружены."
fi
echo

if ! confirm_action "Отключить неиспользуемые службы"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

stopped=0
for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files 2>/dev/null | grep -qE "^\s*${svc}\."; then
        if systemctl is-active "$svc" 2>/dev/null | grep -q "active"; then
            systemctl stop "$svc" 2>/dev/null || true
        fi
        if systemctl is-enabled "$svc" 2>/dev/null | grep -qE "enabled|static"; then
            systemctl disable "$svc" 2>/dev/null || true
            systemctl mask "$svc" 2>/dev/null || true
        fi
        echo -e "  ${GREEN}[+]${NC} $svc — остановлена и отключена"
        log_action "Отключена служба $svc"
        stopped=$((stopped + 1))
    fi
done

echo
echo -e "${GREEN}[+]${NC} Отключено $stopped служб"
log_action "Выполнено отключение неиспользуемых служб ($stopped)"
