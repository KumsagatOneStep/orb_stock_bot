#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #105 — проверка

CASE_DIR="$HOME/nexus7/case105"
KEY="$CASE_DIR/.exfil_key"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #105 — ФИНАЛ: ИСХОД                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -d "$CASE_DIR" ]; then
    echo "  ✗ Рабочая директория не найдена. Запусти сначала:"
    echo "    bash ~/nexus7/setup_case105.sh"
    exit 1
fi

if [ ! -f "$KEY" ]; then
    echo "  ✗ SSH-ключ .exfil_key не найден."
    echo '    Подсказка: ssh-keygen -t ed25519 -f ~/nexus7/case105/.exfil_key -N ""'
    PASS=false
else
    echo "  ✓ Приватный ключ .exfil_key найден."
fi

if [ ! -f "${KEY}.pub" ]; then
    echo "  ✗ Публичный ключ .exfil_key.pub не найден."
    echo "    Подсказка: ssh-keygen создаёт оба файла автоматически"
    PASS=false
else
    echo "  ✓ Публичный ключ .exfil_key.pub найден."
fi

if [ -f "${KEY}.pub" ]; then
    PUB_CONTENT=$(cat "${KEY}.pub")
    if [ -f "$HOME/.ssh/authorized_keys" ] && grep -qF "$PUB_CONTENT" "$HOME/.ssh/authorized_keys"; then
        echo "  ✓ Публичный ключ добавлен в authorized_keys."
    else
        echo "  ✗ Публичный ключ не найден в ~/.ssh/authorized_keys."
        echo "    Подсказка: cat ~/nexus7/case105/.exfil_key.pub >> ~/.ssh/authorized_keys"
        PASS=false
    fi
fi

EXFIL="$CASE_DIR/exfil.sh"
if [ ! -f "$EXFIL" ]; then
    echo "  ✗ exfil.sh не найден."
    echo "    Подсказка: cp exfil.sh.template exfil.sh  затем заполни TODO-секции"
    PASS=false
elif [ ! -x "$EXFIL" ]; then
    echo "  ✗ exfil.sh не исполняемый."
    echo "    Подсказка: chmod +x exfil.sh"
    PASS=false
elif grep -q "TODO" "$EXFIL"; then
    echo "  ✗ exfil.sh содержит незаполненные TODO-секции."
    echo "    Замени все строки с TODO на реальные команды"
    PASS=false
elif ! grep -q "rsync" "$EXFIL"; then
    echo "  ✗ exfil.sh не использует rsync."
    echo '    Подсказка: rsync -av -e "ssh -i $KEY -o StrictHostKeyChecking=no" data/ "$DEST"'
    PASS=false
else
    echo "  ✓ exfil.sh корректен (исполняемый, rsync присутствует)."
fi

INTEL_COUNT=$(find "$CASE_DIR/remote/" -name "intel_*.txt" 2>/dev/null | wc -l | tr -d ' ')
if [ "$INTEL_COUNT" -lt 5 ]; then
    echo "  ✗ В remote/ найдено $INTEL_COUNT из 5 файлов intel_*.txt."
    echo "    Подсказка: ./exfil.sh  (запусти скрипт из ~/nexus7/case105/)"
    PASS=false
else
    echo "  ✓ Все 5 файлов intel_*.txt экстрагированы в remote/."
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║   ███████╗██╗███╗   ██╗ █████╗ ██╗      ██╗                 ║"
    echo "║   ██╔════╝██║████╗  ██║██╔══██╗██║     ██╔╝                 ║"
    echo "║   █████╗  ██║██╔██╗ ██║███████║██║    ██╔╝                  ║"
    echo "║   ██╔══╝  ██║██║╚██╗██║██╔══██║██║   ██╔╝                   ║"
    echo "║   ██║     ██║██║ ╚████║██║  ██║███████╔╝                    ║"
    echo "║   ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝                    ║"
    echo "║                                                              ║"
    echo "║      О П Е Р А Ц И Я   А В Т О М А Т И З А Ц И Я           ║"
    echo "║                   З А В Е Р Ш Е Н А                         ║"
    echo "║                                                              ║"
    echo "║  Kira-7 — лучший агент Нео-Алматы.                          ║"
    echo "║  OmegaTech не знает что произошло.                           ║"
    echo "║  NEXUS-7 победил.                                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки:"
    echo "  bash ~/nexus7/check_case105.sh"
fi
echo ""
