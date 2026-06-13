#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
REPORT_DIR="$ROOT_DIR/reports"
BACKUP_DIR="$ROOT_DIR/backups"

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR"

log_action() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_DIR/actions.log"
}

print_header() {
    clear
    local os_info
    os_info="$(lsb_release -ds 2>/dev/null || grep -s '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -s)"
    local user_status
    [[ $EUID -eq 0 ]] && user_status="root" || user_status="user"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BOLD}          SECURITY CONTROL CENTER${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e " ${GREEN}OS:${NC} $os_info  ${GREEN}Mode:${NC} $user_status"
    echo -e "${CYAN}========================================${NC}"
    echo
}

pause_screen() {
    echo
    read -rp "Нажмите Enter для продолжения..." _
}

confirm_action() {
    local question="$1"
    read -rp "$question [y/n]: " answer
    case "$answer" in
        y|Y|yes|YES|д|Д|да|ДА) return 0 ;;
        *) return 1 ;;
    esac
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] Для выполнения этого действия нужны права root.${NC}"
        echo "    Запустите: sudo ./start.sh"
        return 1
    fi
    return 0
}

require_root_opt() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    echo -e "${YELLOW}[!] Нет root-прав — некоторые проверки будут пропущены${NC}"
    return 1
}

backup_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local safe_name
        safe_name="$(echo "$file_path" | sed 's#/#_#g')"
        cp "$file_path" "$BACKUP_DIR/${safe_name}.$(date '+%Y%m%d_%H%M%S').backup"
        log_action "Создана резервная копия файла $file_path"
        echo -e "${GREEN}[+]${NC} Резервная копия создана для $file_path"
    else
        echo -e "${YELLOW}[!]${NC} Файл $file_path не найден, резервная копия не создана"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ok()   { echo -e " ${GREEN}[OK]${NC} $1"; }
fail() { echo -e " ${RED}[--]${NC} $1"; }
info() { echo -e " ${YELLOW}[*]${NC} $1"; }
