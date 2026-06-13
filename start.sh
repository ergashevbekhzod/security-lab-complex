#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROJECT_DIR/modules/utils.sh"

chmod +x "$PROJECT_DIR/modules/"*.sh 2>/dev/null || true

run_module() {
    local module="$PROJECT_DIR/modules/$1.sh"
    if [[ ! -f "$module" ]]; then
        echo -e "${RED}[!] Модуль $1.sh не найден${NC}"
        pause_screen
        return
    fi
    if [[ "$(head -1 "$module")" != "#!/usr/bin/env bash" ]]; then
        echo -e "${RED}[!] Некорректный модуль $1.sh${NC}"
        pause_screen
        return
    fi
    bash "$module"
    pause_screen
}

ALL_MODULES="system_check users ports security_score permissions ssh firewall fail2ban logging sysctl_hardening password_policy unattended_upgrades firejail file_integrity auditd services apparmor"

while true; do
    print_header
    echo -e " ${GREEN}[1]${NC}  Быстрый аудит системы"
    echo -e " ${GREEN}[2]${NC}  Анализ пользователей"
    echo -e " ${GREEN}[3]${NC}  Проверка открытых портов"
    echo -e " ${GREEN}[4]${NC}  Поиск уязвимых настроек"
    echo -e " ${YELLOW}[5]${NC}  Защита доступа и прав"
    echo -e " ${YELLOW}[6]${NC}  Защита SSH"
    echo -e " ${YELLOW}[7]${NC}  Межсетевой экран (UFW)"
    echo -e " ${YELLOW}[8]${NC}  Защита от атак (Fail2Ban)"
    echo -e " ${YELLOW}[9]${NC}  Мониторинг и журналы"
    echo -e " ${YELLOW}[10]${NC} Ядро системы (sysctl)"
    echo -e " ${YELLOW}[11]${NC} Политика паролей"
    echo -e " ${YELLOW}[12]${NC} Автоматические обновления"
    echo -e " ${YELLOW}[13]${NC} Изоляция приложений (Firejail)"
    echo -e " ${YELLOW}[14]${NC} Контроль целостности файлов"
    echo -e " ${YELLOW}[15]${NC} Защита системных служб"
    echo -e " ${YELLOW}[16]${NC} AppArmor / SELinux"
    echo -e " ${RED}[17]${NC} Полная настройка защиты"
    echo -e " ${RED}[18]${NC} Сформировать отчет"
    echo
    echo -e " ${BOLD}[0]${NC}  Выход"
    echo
    read -rp "Выберите пункт: " c
    case "${c:-}" in
        1) run_module system_check ;;
        2) run_module users ;;
        3) run_module ports ;;
        4) run_module security_score ;;
        5) run_module permissions ;;
        6) run_module ssh ;;
        7) run_module firewall ;;
        8) run_module fail2ban ;;
        9) run_module logging ;;
        10) run_module sysctl_hardening ;;
        11) run_module password_policy ;;
        12) run_module unattended_upgrades ;;
        13) run_module firejail ;;
        14) run_module file_integrity ;;
        15) run_module services ;;
        16) run_module apparmor ;;
        17)
            for m in $ALL_MODULES; do
                run_module "$m"
            done
            ;;
        18) run_module report ;;
        0)
            echo -e "${GREEN}До свидания.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный пункт.${NC}"
            pause_screen
            ;;
    esac
done
