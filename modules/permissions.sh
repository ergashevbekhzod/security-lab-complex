#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Проверка прав доступа"
echo

check_perm() {
    local file_path="$1"
    local expected="$2"
    if [[ -e "$file_path" ]]; then
        local current
        current="$(stat -c '%a' "$file_path" 2>/dev/null || stat -f '%Lp' "$file_path")"
        local owner
        owner="$(stat -c '%U:%G' "$file_path" 2>/dev/null || stat -f '%Su:%Sg' "$file_path")"
        if [[ "$current" == "$expected" ]]; then
            echo -e " ${GREEN}[OK]${NC} $file_path ($current, $owner)"
        else
            echo -e " ${RED}[--]${NC} $file_path -> $current (ожидается $expected), $owner"
        fi
    else
        echo -e " ${YELLOW}[--]${NC} $file_path -> не найден"
    fi
}

echo "Важные системные файлы:"
check_perm /etc/passwd 644
check_perm /etc/shadow 640
check_perm /etc/gshadow 640
check_perm /etc/group 644
check_perm /etc/sudoers 440
check_perm /etc/ssh/sshd_config 600
check_perm /etc/crontab 600
check_perm /boot 755
echo

echo "SUID-файлы (опасные):"
suid_dangerous=0
for f in /usr/bin/pkexec /usr/bin/mount /usr/bin/umount /usr/bin/su /usr/bin/sudo /usr/bin/fusermount /usr/bin/chsh /usr/bin/chfn /usr/bin/gpasswd /usr/bin/passwd /usr/bin/newgrp; do
    if [[ -u "$f" ]]; then
        echo -e "  ${YELLOW}[!]${NC} $f (SUID)"
        suid_dangerous=$((suid_dangerous + 1))
    fi
done
echo "  Всего SUID-файлов из списка: $suid_dangerous"
echo

echo "Мировые-записываемые директории (/etc, /var):"
find /etc /var -type d -perm -o+w 2>/dev/null | while read dir; do
    echo -e "  ${RED}[!]${NC} $dir"
done

echo
echo "Можно создать учебную защищённую директорию /opt/security-lab-test с правами 700."
if confirm_action "Создать/настроить тестовую директорию"; then
    if require_root; then
        mkdir -p /opt/security-lab-test
        chown root:root /opt/security-lab-test
        chmod 700 /opt/security-lab-test
        echo -e "${GREEN}[+]${NC} Директория /opt/security-lab-test настроена"
        log_action "Настроена директория /opt/security-lab-test"
    fi
fi

log_action "Выполнена проверка прав доступа"
