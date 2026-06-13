#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"
print_header

echo "[+] Анализ открытых портов"
echo

if command -v ss >/dev/null; then
    echo "Порты, ожидающие подключения (LISTEN):"
    echo
    ss -tulpn 2>/dev/null | while read line; do
        if echo "$line" | grep -q "LISTEN"; then
            proto=$(echo "$line" | awk '{print $1}')
            addr=$(echo "$line" | awk '{print $5}')
            proc=$(echo "$line" | awk -F'"' '{print $2}')
            echo "  $proto  $addr  [${proc:-unknown}]"
        fi
    done
    echo
    listening_public=$(ss -tulpn 2>/dev/null | grep -c "0.0.0.0:\|:::" || true)
    listening_local=$(ss -tulpn 2>/dev/null | grep -c "127.0.0.1:\|::1:" || true)
    echo "  Из них на всех интерфейсах (0.0.0.0): $listening_public"
    echo "  Только локальные (127.0.0.1):        $listening_local"
elif command -v netstat >/dev/null; then
    netstat -tulpn 2>/dev/null || true
else
    echo -e "${RED}[!]${NC} ss и netstat не найдены."
    echo "    Установите iproute2: sudo apt install iproute2"
fi

log_action "Выполнен анализ открытых портов"
