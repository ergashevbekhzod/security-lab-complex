#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Настройка ядра системы (sysctl)"
echo

echo "--- Текущие параметры ---"
PARAMS=(
    "net.ipv4.tcp_syncookies:Защита от SYN-атак (рекомендуется 1)"
    "net.ipv4.ip_forward:IP-форвардинг (рекомендуется 0)"
    "net.ipv4.conf.all.rp_filter:Фильтрация спуфинга (рекомендуется 1)"
    "net.ipv4.conf.all.accept_redirects:Приём ICMP-редиректов (рекомендуется 0)"
    "net.ipv4.conf.all.send_redirects:Отправка ICMP-редиректов (рекомендуется 0)"
    "net.ipv4.icmp_echo_ignore_broadcasts:Игнорирование ICMP broadcast (рекомендуется 1)"
    "net.ipv4.conf.all.log_martians:Логирование подозрительных пакетов (рекомендуется 1)"
)

for entry in "${PARAMS[@]}"; do
    key="${entry%%:*}"
    desc="${entry#*:}"
    val=$(sysctl -n "$key" 2>/dev/null)
    if [[ -z "$val" ]]; then
        echo -e "  ${YELLOW}[--]${NC} $desc: не определено"
    elif [[ "$val" == "1" ]] || [[ "$val" == "0" && "$key" != *"syncookies"* && "$key" != *"rp_filter"* && "$key" != *"log_martians"* && "$key" != *"icmp_echo_ignore_broadcasts"* ]]; then
        if [[ "$val" == "0" ]]; then
            echo -e "  ${YELLOW}[*]${NC} $desc: $val"
        else
            echo -e "  ${GREEN}[*]${NC} $desc: $val"
        fi
    else
        echo -e "  ${YELLOW}[*]${NC} $desc: $val"
    fi
done

echo
echo "Будет применено:"
echo "  - tcp_syncookies = 1 (защита от SYN-flood)"
echo "  - rp_filter = 1 (защита от IP-спуфинга)"
echo "  - accept_redirects = 0 (отключение ICMP-редиректов)"
echo "  - send_redirects = 0"
echo "  - icmp_echo_ignore_broadcasts = 1"
echo "  - log_martians = 1 (логирование подозрительных пакетов)"
echo

if ! confirm_action "Применить рекомендуемые параметры ядра"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

SYSCTL_FILE="/etc/sysctl.d/99-security-lab.conf"
backup_file "$SYSCTL_FILE"

cat > "$SYSCTL_FILE" <<'EOF'
# Security Lab Complex — настройки защиты ядра
# Защита от SYN-flood атак
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_synack_retries = 2

# Защита от IP-спуфинга
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Отключение ICMP-редиректов (защита от MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Игнорирование опасных ICMP-пакетов
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Логирование подозрительных пакетов
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Безопасность стека IPv6
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF

if sysctl -p "$SYSCTL_FILE" >/tmp/security_lab_sysctl.log 2>&1; then
    echo -e "${GREEN}[+]${NC} Параметры ядра успешно применены"
else
    echo -e "${RED}[!]${NC} Ошибка при применении параметров:"
    cat /tmp/security_lab_sysctl.log
fi

log_action "Применены настройки ядра (sysctl)"
