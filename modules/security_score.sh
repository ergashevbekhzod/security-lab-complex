#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"
source "$ROOT_DIR/config/default.conf"

print_header

echo "[+] Оценка безопасности системы"
echo

SCORE=0
TOTAL=100

check() {
    local desc="$1"
    local pts="$2"
    shift 2
    if eval "$@" >/dev/null 2>&1; then
        echo -e " ${GREEN}[OK]${NC} $desc"
        SCORE=$((SCORE + pts))
    else
        echo -e " ${RED}[--]${NC} $desc"
    fi
}

check "SSH сервер запущен"           10 'systemctl is-active ssh'
check "UFW активен"                  10 'ufw status 2>/dev/null | grep -q active'
check "Fail2Ban запущен"             10 'systemctl is-active fail2ban'
check "PermitRootLogin выключен"     10 'grep -Eq "^PermitRootLogin\s+no" /etc/ssh/sshd_config 2>/dev/null'
check "PasswordAuthentication выкл"  10 'grep -Eq "^PasswordAuthentication\s+no" /etc/ssh/sshd_config 2>/dev/null'
check "tcp_syncookies включён"        5 'sysctl -n net.ipv4.tcp_syncookies 2>/dev/null | grep -q 1'
check "rp_filter включён"             5 'sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null | grep -q 1'
check "accept_redirects отключён"     5 'sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null | grep -q 0'
check "send_redirects отключён"       5 'sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null | grep -q 0'
check "auditd запущен"               10 'systemctl is-active auditd 2>/dev/null'
check "AppArmor активен"             10 'command -v aa-status && aa-status 2>/dev/null | grep -q "enabled"'
check "unattended-upgrades установлен" 5 'command -v unattended-upgrades'
check "Firejail установлен"           5 'command -v firejail'

echo
echo -e "${BOLD}Оценка безопасности: $SCORE/$TOTAL${NC}"
echo
if [[ $SCORE -lt 50 ]]; then
    echo -e "${RED}Низкий уровень защиты. Рекомендуется выполнить пункты 5-16.${NC}"
elif [[ $SCORE -lt 80 ]]; then
    echo -e "${YELLOW}Средний уровень защиты.${NC}"
else
    echo -e "${GREEN}Высокий уровень защиты.${NC}"
fi

log_action "Оценка безопасности: $SCORE/$TOTAL"
