#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Проверка пользователей"
echo

echo "Пользователи с UID 0 (суперпользователь):"
awk -F: '($3 == 0) {print "- " $1}' /etc/passwd
echo

echo "Пользователи с оболочкой входа:"
awk -F: '($7 !~ /(nologin|false)$/) {print "- " $1 " [" $7 "]"}' /etc/passwd
echo

echo "Пользователи в группе sudo/wheel:"
if getent group sudo >/dev/null 2>&1; then
    echo "  sudo: $(getent group sudo | awk -F: '{print $4}')"
fi
if getent group wheel >/dev/null 2>&1; then
    echo "  wheel: $(getent group wheel | awk -F: '{print $4}')"
fi
echo

echo "Дублирующиеся UID:"
awk -F: '{print $3}' /etc/passwd | sort -n | uniq -d | while read uid; do
    echo "  UID $uid: $(awk -F: -v u="$uid" '($3 == u) {print $1}' /etc/passwd | tr '\n' ' ')"
done
echo

if require_root; then
    echo "Пользователи без пароля (пустой пароль в /etc/shadow):"
    awk -F: '($2 == "" || $2 == "!!") {print "- " $1}' /etc/shadow 2>/dev/null || echo "  нет"
    echo
    echo "Пользователи с заблокированным паролем (! в /etc/shadow):"
    awk -F: '($2 ~ /^!/ || $2 == "*") && $2 != "!!" {print "- " $1}' /etc/shadow 2>/dev/null || true
    echo
    echo "Срок действия паролей (пользователи с истёкшим сроком):"
    awk -F: '($3 > 0 && $3 + $4 < systime()/86400) {print "- " $1}' /etc/shadow 2>/dev/null || echo "  не удалось проверить"
else
    echo "Проверка /etc/shadow пропущена: нет root-прав."
fi

log_action "Выполнена проверка пользователей"
