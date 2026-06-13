#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Проверка логирования"
echo

echo "--- systemd-journald ---"
if command_exists journalctl; then
    echo -e "  ${GREEN}[+]${NC} journalctl доступен"
    echo
    echo "  Последние 10 системных событий:"
    journalctl -n 10 --no-pager --quiet 2>/dev/null | sed 's/^/  /'
else
    echo -e "  ${YELLOW}[--]${NC} journalctl не найден"
fi
echo

echo "--- Логи аутентификации ---"
if [[ -f /var/log/auth.log ]]; then
    echo -e "  ${GREEN}[+]${NC} /var/log/auth.log найден"
    size=$(du -h /var/log/auth.log 2>/dev/null | awk '{print $1}')
    echo "  Размер: $size"
    echo "  Последние 10 событий аутентификации:"
    tail -n 10 /var/log/auth.log 2>/dev/null | sed 's/^/  /'
elif command_exists journalctl; then
    echo -e "  ${YELLOW}[*]${NC} /var/log/auth.log не найден. Используется journalctl."
    echo "  Последние 10 событий аутентификации:"
    journalctl -u ssh --no-pager -n 10 --quiet 2>/dev/null | sed 's/^/  /'
else
    echo -e "  ${YELLOW}[--]${NC} Логи аутентификации недоступны"
fi
echo

echo "--- Входы пользователей ---"
if command_exists last; then
    echo "  Последние 5 входов:"
    last -n 5 2>/dev/null | sed 's/^/  /'
fi
echo

echo "--- Logrotate (ротация логов) ---"
if [[ -d /etc/logrotate.d ]]; then
    echo "  Конфигураций logrotate: $(ls /etc/logrotate.d/ | wc -l)"
    echo "  Основные:"
    ls /etc/logrotate.d/ 2>/dev/null | sed 's/^/    /'
fi
echo

echo "--- Дисковое пространство для логов ---"
if command_exists df; then
    df -h /var/log 2>/dev/null | awk 'NR==2 {print "  Использовано /var/log: " $3 " / " $2 " (" $5 ")"}'
fi

log_action "Выполнена проверка логирования"
