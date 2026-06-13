#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/utils.sh"

print_header

echo "[+] Контроль целостности файлов"
echo

INTEGRITY_DB="$ROOT_DIR/backups/file_integrity.db"

SYSTEM_FILES=(
    /bin/bash /bin/ls /bin/ps /bin/mount /bin/umount
    /usr/bin/sudo /usr/bin/passwd /usr/bin/ssh /usr/bin/find
    /usr/bin/chsh /usr/bin/chfn /usr/bin/gpasswd /usr/bin/newgrp
    /sbin/sshd /sbin/fsck /sbin/modprobe
)

check_integrity() {
    echo "Слепок системных файлов:"
    echo
    for f in "${SYSTEM_FILES[@]}"; do
        if [[ -f "$f" ]]; then
            local hash
            hash=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
            local name
            name=$(basename "$f")
            echo -e "  ${YELLOW}[*]${NC} $name: $hash"
        else
            echo -e "  ${YELLOW}[--]${NC} $(basename "$f"): файл не найден"
        fi
    done

    echo
    if [[ -f "$INTEGRITY_DB" ]]; then
        echo "Эталонный слепок найден. Проверка изменений..."
        local changes
        changes=$(sha256sum -c "$INTEGRITY_DB" 2>/dev/null | grep "FAILED" | wc -l)
        if [[ "$changes" -gt 0 ]]; then
            echo -e "  ${RED}[!]${NC} Обнаружены изменения в $changes файлах!"
            sha256sum -c "$INTEGRITY_DB" 2>/dev/null | grep "FAILED" | sed 's/: FAILED/ -> ИЗМЕНЁН/' | sed 's/^/    /'
        else
            echo -e "  ${GREEN}[OK]${NC} Все файлы соответствуют эталону"
        fi
    fi
}

check_integrity

echo
if confirm_action "Сохранить текущий слепок как эталонный"; then
    {
        for f in "${SYSTEM_FILES[@]}"; do
            if [[ -f "$f" ]]; then
                sha256sum "$f"
            fi
        done
    } > "$INTEGRITY_DB"
    echo -e "${GREEN}[+]${NC} Слепок сохранён: $INTEGRITY_DB (${#SYSTEM_FILES[@]} файлов)"
    log_action "Сохранён слепок целостности файлов"
fi

log_action "Выполнен контроль целостности файлов"
