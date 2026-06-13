#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Автоматические обновления безопасности"
echo

echo "--- Состояние unattended-upgrades ---"
if command_exists unattended-upgrades; then
    echo -e "  ${GREEN}[+]${NC} unattended-upgrades установлен"
    dpkg -l unattended-upgrades 2>/dev/null | awk '/^ii/ {print "  Версия: " $3}'
else
    echo -e "  ${YELLOW}[--]${NC} unattended-upgrades не установлен"
fi

if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    echo "  Текущие настройки:"
    cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null | sed 's/^/    /'
fi
echo

echo "Будет выполнено:"
echo "  - установка unattended-upgrades при необходимости"
echo "  - настройка ежедневных обновлений безопасности"
echo "  - автоматическая очистка устаревших пакетов"
echo "  - удаление неиспользуемых ядер"
echo

if ! confirm_action "Настроить автоматические обновления безопасности"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if ! command_exists unattended-upgrades; then
    echo -e "${YELLOW}[*]${NC} Устанавливаю unattended-upgrades..."
    apt update
    apt install -y unattended-upgrades
fi

backup_file "/etc/apt/apt.conf.d/20auto-upgrades"
backup_file "/etc/apt/apt.conf.d/50unattended-upgrades"

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

UNATTENDED_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
if [[ -f "$UNATTENDED_CONF" ]]; then
    sed -i 's|//\s*"\${distro_id}:\${distro_codename}-security";|"${distro_id}:${distro_codename}-security";|' "$UNATTENDED_CONF"
    sed -i 's|//Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|' "$UNATTENDED_CONF"
    sed -i 's|//Unattended-Upgrade::Remove-Unused-Dependencies "true";|Unattended-Upgrade::Remove-Unused-Dependencies "true";|' "$UNATTENDED_CONF"
    sed -i 's|//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "false";|' "$UNATTENDED_CONF"
fi

systemctl restart unattended-upgrades 2>/dev/null || true

echo -e "${GREEN}[+]${NC} Автоматические обновления настроены:"
echo "  - ежедневная проверка обновлений"
echo "  - установка обновлений безопасности"
echo "  - очистка кэша каждые 7 дней"
echo "  - удаление старых ядер"
log_action "Настроены автоматические обновления безопасности"
