#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #101 — проверка

CASE_DIR="$HOME/nexus7/case101"
SCRIPT="$CASE_DIR/deploy.sh"
PASS=true

if [ ! -d "$CASE_DIR" ]; then
    echo "  ✗ Рабочая директория не найдена. Запусти сначала:"
    echo "    bash ~/nexus7/setup_case101.sh"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #101 — ПЕРВЫЙ КОНТАКТ                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -f "$SCRIPT" ]; then
    echo "  ✗ deploy.sh не найден."
    echo "    Создай файл: ~/nexus7/case101/deploy.sh"
    PASS=false
else
    echo "  ✓ deploy.sh найден."
fi

if [ -f "$SCRIPT" ]; then
    if [ -x "$SCRIPT" ]; then
        echo "  ✓ deploy.sh исполняемый."
    else
        echo "  ✗ deploy.sh не исполняемый."
        echo "    Подсказка: chmod +x ~/nexus7/case101/deploy.sh"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q "set -euo pipefail" "$SCRIPT"; then
        echo "  ✓ set -euo pipefail найден."
    else
        echo "  ✗ set -euo pipefail не найден."
        echo "    Добавь второй строкой в скрипт: set -euo pipefail"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q 'AGENT_NAME' "$SCRIPT"; then
        echo "  ✓ Переменная AGENT_NAME используется."
    else
        echo "  ✗ Переменная AGENT_NAME не найдена."
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q 'STATUS' "$SCRIPT" && grep -q 'if \[' "$SCRIPT"; then
        echo "  ✓ Проверка STATUS найдена."
    else
        echo "  ✗ Нет проверки STATUS в if-блоке."
        echo '    Подсказка: if [ "$STATUS" != "OPERATIONAL" ]; then echo "Error" >&2; exit 1; fi'
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ] && [ "$PASS" = true ]; then
    rm -f "$CASE_DIR/config/omega.conf"
    if ( cd "$CASE_DIR" && AGENT_NAME=Kira bash deploy.sh >/dev/null 2>&1 ); then
        if [ -f "$CASE_DIR/config/omega.conf" ]; then
            if grep -q "__AGENT__" "$CASE_DIR/config/omega.conf"; then
                echo "  ✗ config/omega.conf создан, но __AGENT__ не заменён."
                echo '    Подсказка: sed "s/__AGENT__/$AGENT_NAME/g" config/omega.conf.template > config/omega.conf'
                PASS=false
            else
                echo "  ✓ config/omega.conf создан, __AGENT__ заменён."
            fi
        else
            echo "  ✗ deploy.sh отработал, но config/omega.conf не создан."
            PASS=false
        fi
    else
        echo "  ✗ deploy.sh завершился с ошибкой при STATUS=OPERATIONAL."
        echo "    Проверь: cd ~/nexus7/case101 && AGENT_NAME=Kira bash deploy.sh"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ] && [ "$PASS" = true ]; then
    # Temporarily set STATUS=DEGRADED in the status file for this test
    trap 'mv "$CASE_DIR/system/status.txt.bak" "$CASE_DIR/system/status.txt" 2>/dev/null || true' EXIT
    cp "$CASE_DIR/system/status.txt" "$CASE_DIR/system/status.txt.bak"
    printf 'STATUS=DEGRADED\nUPTIME=99.97%%\nTHREAT_LEVEL=RED\n' > "$CASE_DIR/system/status.txt"
    if ( cd "$CASE_DIR" && AGENT_NAME=Kira bash deploy.sh >/dev/null 2>&1 ); then
        echo "  ✗ deploy.sh не прерывается при STATUS=DEGRADED."
        echo '    Добавь: if [ "$STATUS" != "OPERATIONAL" ]; then echo "ERROR" >&2; exit 1; fi'
        PASS=false
    else
        echo "  ✓ deploy.sh правильно прерывается при STATUS=DEGRADED."
    fi
    trap - EXIT
    mv "$CASE_DIR/system/status.txt.bak" "$CASE_DIR/system/status.txt"
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #101 ЗАКРЫТО.                                        ║"
    echo "║  Плацдарм установлен. Скрипт развёртывания работает.         ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг: bash ~/nexus7/setup_case102.sh              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки и запусти снова:"
    echo "  bash ~/nexus7/check_case101.sh"
fi
echo ""
