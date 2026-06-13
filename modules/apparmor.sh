#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] AppArmor / SELinux"
echo

echo "--- Текущее состояние ---"
if command_exists aa-status; then
    echo -e "  ${GREEN}[+]${NC} AppArmor установлен"
    profiles=$(aa-status 2>/dev/null | grep "profiles" | head -1 || echo "0")
    enforce=$(aa-status 2>/dev/null | grep "profiles.*enforce" | grep -oP '\d+(?= profiles? in enforce)' || echo "0")
    complain=$(aa-status 2>/dev/null | grep "profiles.*complain" | grep -oP '\d+(?= profiles? in complain)' || echo "0")
    echo "  Профилей: $profiles"
    echo "  Из них в режиме enforce: ${enforce:-0}"
    echo "  В режиме complain: ${complain:-0}"
    echo
    echo "  Активные профили (enforce):"
    aa-status 2>/dev/null | grep -E "^\s+" | head -10 | sed 's/^/    /'
elif command_exists sestatus; then
    echo -e "  ${GREEN}[+]${NC} SELinux установлен"
    sestatus 2>/dev/null | sed 's/^/  /'
elif [[ -f /sys/kernel/security/lsm ]]; then
    echo "  Загруженные LSM: $(cat /sys/kernel/security/lsm)"
    echo -e "  ${YELLOW}[--]${NC} AppArmor или SELinux не обнаружены"
else
    echo -e "  ${YELLOW}[--]${NC} AppArmor/SELinux не обнаружены"
fi
echo

echo "AppArmor ограничивает программы с помощью профилей безопасности."
echo "Это дополнительный уровень защиты поверх стандартных прав доступа."
echo

if ! confirm_action "Установить AppArmor (если отсутствует)"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if ! command_exists aa-status && ! command_exists sestatus; then
    echo -e "${YELLOW}[*]${NC} Устанавливаю AppArmor..."
    apt update
    apt install -y apparmor apparmor-utils apparmor-profiles
    echo -e "${GREEN}[+]${NC} AppArmor установлен"
elif command_exists aa-status; then
    echo -e "${GREEN}[+]${NC} AppArmor уже установлен"
fi

if command_exists aa-enforce; then
    echo
    echo "Перевод профилей в режим enforce..."
    count=0
    for prof in /etc/apparmor.d/*; do
        if [[ -f "$prof" ]]; then
            local name
            name=$(basename "$prof")
            if aa-status 2>/dev/null | grep -q "^${name}\s"; then
                aa-enforce "$prof" 2>/dev/null && count=$((count + 1))
            fi
        fi
    done
    echo -e "  ${GREEN}[+]${NC} $count профилей переведены в enforce"

    systemctl reload apparmor 2>/dev/null || true
fi

log_action "Настроен AppArmor"
