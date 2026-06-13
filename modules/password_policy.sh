#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Политика паролей"
echo

if [[ -f /etc/login.defs ]]; then
    echo "Текущие параметры /etc/login.defs:"
    for param in PASS_MAX_DAYS PASS_MIN_DAYS PASS_WARN_AGE PASS_MIN_LEN; do
        val=$(grep -E "^\s*${param}\s+" /etc/login.defs | awk '{print $2}')
        echo "  $param = ${val:-не задан}"
    done
fi

echo
echo "Проверка модуля pwquality:"
if grep -q "pam_pwquality\|pam_cracklib" /etc/pam.d/common-password 2>/dev/null; then
    echo -e " ${GREEN}[+]${NC} pam_pwquality/pam_cracklib настроен"
    grep "pam_pwquality\|pam_cracklib" /etc/pam.d/common-password 2>/dev/null | head -3
else
    echo -e " ${YELLOW}[--]${NC} pam_pwquality не настроен"
fi

echo
if ! confirm_action "Применить рекомендуемую политику паролей"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

backup_file "/etc/login.defs"
backup_file "/etc/pam.d/common-password"

if ! grep -q "PASS_MAX_DAYS" /etc/login.defs; then
    echo "PASS_MAX_DAYS   90" >> /etc/login.defs
else
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
fi

if ! grep -q "PASS_MIN_DAYS" /etc/login.defs; then
    echo "PASS_MIN_DAYS   7" >> /etc/login.defs
else
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' /etc/login.defs
fi

if ! grep -q "PASS_WARN_AGE" /etc/login.defs; then
    echo "PASS_WARN_AGE   14" >> /etc/login.defs
else
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
fi

echo -e "${GREEN}[+]${NC} /etc/login.defs обновлён"

if ! command_exists pwquality; then
    echo -e "${YELLOW}[*]${NC} Устанавливаю libpam-pwquality..."
    apt update
    apt install -y libpam-pwquality 2>/dev/null || apt install -y libpam-cracklib
fi

if grep -q "pam_pwquality.so" /etc/pam.d/common-password 2>/dev/null; then
    sed -i 's/pam_pwquality.so.*/pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password
elif grep -q "pam_cracklib.so" /etc/pam.d/common-password 2>/dev/null; then
    sed -i 's/pam_cracklib.so.*/pam_cracklib.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password
else
    sed -i '/^password\s\+requisite\s\+pam_unix.so/ a password\trequisite\tpam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1' /etc/pam.d/common-password
fi

echo -e "${GREEN}[+]${NC} Политика паролей применена"
echo "  - пароль действует не более 90 дней"
echo "  - смена не чаще 1 раза в 7 дней"
echo "  - предупреждение за 14 дней"
echo "  - минимальная длина 12 символов"
echo "  - обязательны: заглавные, строчные, цифры, спецсимволы"

log_action "Применена политика паролей"
