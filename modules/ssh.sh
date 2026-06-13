#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Защита SSH"
echo

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "--- Текущие настройки SSH ---"
if [[ -f "$SSHD_CONFIG" ]]; then
    for param in Port PermitRootLogin PasswordAuthentication PermitEmptyPasswords PubkeyAuthentication X11Forwarding MaxAuthTries ClientAliveInterval Protocol; do
        val=$(grep -E "^\s*${param}\s+" "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}')
        echo "  $param = ${val:-не задан (используется стандартное значение)}"
    done
else
    echo "  Файл $SSHD_CONFIG не найден."
fi
echo

echo "Будет выполнено:"
echo "  - резервное копирование sshd_config"
echo "  - запрет входа root по SSH"
echo "  - запрет пустых паролей"
echo "  - запрет X11Forwarding"
echo "  - ограничение попыток аутентификации (MaxAuthTries 3)"
echo "  - таймаут сессии (ClientAliveInterval 300)"
echo "  - разрешение только SSH-ключей (PasswordAuthentication no)"
echo

if ! confirm_action "Продолжить настройку SSH"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if [[ ! -f "$SSHD_CONFIG" ]]; then
    echo "[!] Файл $SSHD_CONFIG не найден. Возможно, OpenSSH Server не установлен."
    if confirm_action "Установить openssh-server через apt"; then
        apt update
        apt install -y openssh-server
    else
        exit 1
    fi
fi

backup_file "$SSHD_CONFIG"

set_sshd_option() {
    local key="$1"
    local value="$2"
    if grep -Eq "^[#[:space:]]*${key}\s+" "$SSHD_CONFIG"; then
        sed -i "s/^[#[:space:]]*${key}\s\+.*/${key} ${value}/" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

set_sshd_option "PermitRootLogin" "no"
set_sshd_option "PermitEmptyPasswords" "no"
set_sshd_option "PasswordAuthentication" "no"
set_sshd_option "X11Forwarding" "no"
set_sshd_option "MaxAuthTries" "3"
set_sshd_option "ClientAliveInterval" "300"
set_sshd_option "ClientAliveCountMax" "2"
set_sshd_option "Protocol" "2"

echo
if sshd -t 2>/tmp/security_lab_sshd_test.log; then
    if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
        systemctl restart ssh
    elif systemctl list-unit-files 2>/dev/null | grep -q '^sshd.service'; then
        systemctl restart sshd
    else
        echo -e "${YELLOW}[!]${NC} SSH-служба не найдена для перезапуска"
    fi
    echo -e "${GREEN}[+]${NC} SSH настроен успешно"
    echo "  PermitRootLogin no"
    echo "  PasswordAuthentication no"
    echo "  PermitEmptyPasswords no"
    echo "  X11Forwarding no"
    echo "  MaxAuthTries 3"
    echo "  ClientAliveInterval 300"
    log_action "Выполнена настройка SSH"
else
    echo -e "${RED}[!]${NC} Ошибка проверки конфигурации SSH:"
    cat /tmp/security_lab_sshd_test.log
    log_action "Ошибка настройки SSH"
    exit 1
fi
