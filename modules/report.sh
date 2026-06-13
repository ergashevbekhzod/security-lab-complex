#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

REPORT_FILE="$REPORT_DIR/security_report_$(date '+%Y%m%d_%H%M%S').txt"

OS_NAME="Не определено"
OS_VERSION="Не определено"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_NAME="${NAME:-Не определено}"
    OS_VERSION="${VERSION:-Не определено}"
fi

{
    echo "Security Lab Complex — отчёт проверки"
    echo "Дата: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "ОС: $OS_NAME"
    echo "Версия: $OS_VERSION"
    echo "Ядро: $(uname -r)"
    echo "Архитектура: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime | awk -F, '{print $1}')"
    echo "Пользователь: $(whoami)"
    echo "Root: $([[ $EUID -eq 0 ]] && echo "да" || echo "нет")"
    echo

    echo "1. Основные утилиты"
    for tool in sudo systemctl sshd ufw fail2ban-client journalctl auditctl aa-status firejail unattended-upgrades pwquality; do
        if command_exists "$tool"; then
            echo "  [OK] $tool"
        else
            echo "  [--] $tool"
        fi
    done
    echo

    echo "2. Пользователи"
    echo "  Пользователи с UID 0:"
    awk -F: '($3 == 0) {print "    - " $1}' /etc/passwd
    echo
    echo "  Пользователи с оболочкой входа:"
    awk -F: '($7 !~ /(nologin|false)$/) {print "    - " $1 " [" $7 "]"}' /etc/passwd
    echo
    echo "  Всего пользователей: $(wc -l < /etc/passwd)"
    echo "  В группе sudo: $(getent group sudo 2>/dev/null | awk -F: '{print $4}' | tr ',' ' ' | wc -w)"
    echo

    echo "3. Права важных файлов"
    for file in /etc/passwd /etc/shadow /etc/gshadow /etc/group /etc/sudoers /etc/ssh/sshd_config /etc/crontab; do
        if [[ -e "$file" ]]; then
            perm=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file")
            owner=$(stat -c '%U:%G' "$file" 2>/dev/null || stat -f '%Su:%Sg' "$file")
            echo "  $file -> $perm $owner"
        else
            echo "  $file -> не найден"
        fi
    done
    echo

    echo "4. SSH"
    if [[ -f /etc/ssh/sshd_config ]]; then
        for param in Port PermitRootLogin PasswordAuthentication PermitEmptyPasswords PubkeyAuthentication X11Forwarding MaxAuthTries Protocol; do
            echo "  $param: $(grep -E "^\s*${param}\s+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')"
        done
    else
        echo "  OpenSSH Server не найден"
    fi
    echo

    echo "5. Firewall (UFW)"
    if command_exists ufw; then
        ufw status numbered 2>/dev/null || echo "  UFW не активен"
    else
        echo "  UFW не установлен"
    fi
    echo

    echo "6. Fail2Ban"
    if command_exists fail2ban-client; then
        fail2ban-client status 2>/dev/null || echo "  Не активен"
    else
        echo "  Fail2Ban не установлен"
    fi
    echo

    echo "7. Ядро системы (sysctl)"
    for param in net.ipv4.tcp_syncookies net.ipv4.ip_forward net.ipv4.conf.all.rp_filter net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects net.ipv4.icmp_echo_ignore_broadcasts; do
        echo "  $param = $(sysctl -n "$param" 2>/dev/null || echo "N/A")"
    done
    echo

    echo "8. Auditd"
    if command_exists auditctl; then
        rules=$(auditctl -l 2>/dev/null | wc -l)
        echo "  Правил загружено: $rules"
        auditctl -l 2>/dev/null || echo "  Правила не загружены"
    else
        echo "  auditd не установлен"
    fi
    echo

    echo "9. AppArmor"
    if command_exists aa-status; then
        aa-status 2>/dev/null | head -10
    else
        echo "  AppArmor не установлен"
    fi
    echo

    echo "10. Автоматические обновления"
    if command_exists unattended-upgrades; then
        echo "  unattended-upgrades: установлен"
        cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || echo "  конфиг не найден"
    else
        echo "  unattended-upgrades: не установлен"
    fi
    echo

    echo "11. Контроль целостности"
    INTEGRITY_DB="$ROOT_DIR/backups/file_integrity.db"
    if [[ -f "$INTEGRITY_DB" ]]; then
        echo "  Слепок целостности: $(wc -l < "$INTEGRITY_DB") файлов"
    else
        echo "  Слепок целостности: не сохранён"
    fi
    echo

    echo "12. Защита служб"
    echo "  Включено служб: $(systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | wc -l)"
    echo "  Запущено служб: $(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)"
    echo

    echo "13. Открытые порты"
    if command_exists ss; then
        ss -tulpn 2>/dev/null | grep LISTEN | awk '{print "  " $1 " " $5}' | sed 's/0.0.0.0/*/g' | sed 's/:::\*/: :::/g'
    fi
    echo

    echo "14. Логи действий проекта"
    if [[ -f "$LOG_DIR/actions.log" ]]; then
        tail -n 30 "$LOG_DIR/actions.log"
    else
        echo "  Лог действий отсутствует"
    fi
    echo

    echo "Рекомендации:"
    echo "  - регулярно обновлять систему (п.12)"
    echo "  - использовать SSH-ключи вместо паролей (п.4)"
    echo "  - включить AppArmor/SELinux (п.9)"
    echo "  - настроить auditd для мониторинга (п.8)"
    echo "  - использовать изоляцию приложений Firejail (п.13)"
    echo "  - проверить открытые порты (п.13)"
    echo "  - хранить резервные копии конфигураций (backups/)"
    echo "  - настроить политику паролей (п.11)"
} > "$REPORT_FILE"

echo -e "${GREEN}[+]${NC} Отчёт создан: $REPORT_FILE"
echo "  Размер: $(du -h "$REPORT_FILE" 2>/dev/null | awk '{print $1}')"
log_action "Создан отчёт $REPORT_FILE"
