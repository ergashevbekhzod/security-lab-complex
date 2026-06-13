#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Система аудита (auditd)"
echo

echo "--- Текущее состояние ---"
if command_exists auditd; then
    echo -e "  ${GREEN}[+]${NC} auditd установлен"
    if systemctl is-active auditd >/dev/null 2>&1; then
        echo -e "  ${GREEN}[+]${NC} auditd запущен"
    else
        echo -e "  ${YELLOW}[--]${NC} auditd остановлен"
    fi
else
    echo -e "  ${YELLOW}[--]${NC} auditd не установлен"
fi

if command_exists auditctl; then
    echo "  Загруженные правила:"
    auditctl -l 2>/dev/null | sed 's/^/    /' || echo "    правила не загружены"
fi
echo

echo "auditd отслеживает важные системные события:"
echo "  - изменения в /etc/passwd, /etc/shadow, /etc/sudoers"
echo "  - изменения конфигурации SSH"
echo "  - загрузку/выгрузку модулей ядра"
echo "  - запуск процессов"
echo

if ! confirm_action "Установить и настроить auditd"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if ! command_exists auditd; then
    echo -e "${YELLOW}[*]${NC} Устанавливаю auditd..."
    apt update
    apt install -y auditd audispd-plugins
fi

backup_file "/etc/audit/rules.d/audit.rules"

cat > /etc/audit/rules.d/audit.rules <<'EOF'
# Security Lab Complex — правила аудита
# Отслеживание изменений учётных записей
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/sudoers.d -p wa -k identity

# Отслеживание изменений SSH
-w /etc/ssh/sshd_config -p wa -k ssh

# Отслеживание аутентификации
-w /var/log/auth.log -p wa -k auth
-w /var/log/secure -p wa -k auth

# Отслеживание загрузки модулей ядра
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Отслеживание запуска процессов
-a always,exit -F arch=b64 -S execve -k process
EOF

systemctl enable auditd
systemctl restart auditd

echo
echo -e "${GREEN}[+]${NC} auditd настроен и запущен"
echo "  Правила загружены: $(auditctl -l 2>/dev/null | wc -l)"
echo "  Для просмотра событий: sudo ausearch -k identity"
log_action "Настроен auditd"
