#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Изоляция приложений (Firejail)"
echo

echo "--- Текущее состояние ---"
if command_exists firejail; then
    echo -e "  ${GREEN}[+]${NC} Firejail установлен"
    echo "  Версия: $(firejail --version 2>&1 | head -1)"
    echo "  Профилей в /etc/firejail: $(ls /etc/firejail/*.inc 2>/dev/null | wc -l)"
    echo
    echo "  Приложения с профилями Firejail:"
    ls /etc/firejail/*.inc 2>/dev/null | while read prof; do
        echo "    $(basename "$prof" .inc)"
    done | sort | head -20
else
    echo -e "  ${YELLOW}[--]${NC} Firejail не установлен"
fi
echo

echo "Firejail изолирует приложения в песочнице:"
echo "  - ограничивает доступ к файловой системе"
echo "  - ограничивает сетевое взаимодействие"
echo "  - изолирует процессы"
echo

if ! confirm_action "Установить и настроить Firejail"; then
    echo "Действие отменено."
    exit 0
fi

require_root || exit 1

if ! command_exists firejail; then
    echo -e "${YELLOW}[*]${NC} Устанавливаю Firejail..."
    apt update
    apt install -y firejail firejail-profiles
    echo -e "${GREEN}[+]${NC} Firejail установлен"
else
    echo -e "${GREEN}[+]${NC} Firejail уже установлен"
fi

if command_exists firecfg; then
    echo
    echo "Настройка автоматической интеграции с приложениями..."
    firecfg 2>/dev/null && echo -e "${GREEN}[+]${NC} Интеграция настроена" || echo -e "${YELLOW}[!]${NC} Ошибка интеграции"
fi

echo
echo "Firefox, Chromium, Transmission, VLC и другие приложения"
echo "будут автоматически запускаться в изолированной среде."

log_action "Установлен и настроен Firejail"
