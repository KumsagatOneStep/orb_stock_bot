#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #102 — проверка

CASE_DIR="$HOME/nexus7/case102"
SCRIPT="$CASE_DIR/scan.sh"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #102 — СБОРОЧНЫЙ ЦЕХ                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -d "$CASE_DIR" ]; then
    echo "  ✗ Рабочая директория не найдена. Запусти сначала:"
    echo "    bash ~/nexus7/setup_case102.sh"
    exit 1
fi

if [ ! -f "$SCRIPT" ]; then
    echo "  ✗ scan.sh не найден."
    echo "    Создай: ~/nexus7/case102/scan.sh"
    PASS=false
else
    echo "  ✓ scan.sh найден."
fi

if [ -f "$SCRIPT" ] && [ ! -x "$SCRIPT" ]; then
    echo "  ✗ scan.sh не исполняемый."
    echo "    Подсказка: chmod +x ~/nexus7/case102/scan.sh"
    PASS=false
elif [ -f "$SCRIPT" ]; then
    echo "  ✓ scan.sh исполняемый."
fi

if [ -f "$SCRIPT" ]; then
    if grep -qE '\(\)|function' "$SCRIPT"; then
        echo "  ✓ Функция определена в скрипте."
    else
        echo "  ✗ Функция не найдена."
        echo "    Подсказка: check_log() { local file=\"\$1\"; grep -q '\[CRITICAL\]' \"\$file\" && echo \"\$(basename \"\$file\")\"; }"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q 'for ' "$SCRIPT"; then
        echo "  ✓ Цикл for найден."
    else
        echo "  ✗ Цикл for не найден."
        echo "    Подсказка: for log in logs/*.log; do ... done"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ] && [ "$PASS" = true ]; then
    ( cd "$CASE_DIR" && bash scan.sh >/dev/null 2>&1 ) || true
fi

REPORT="$CASE_DIR/report.txt"
if [ ! -f "$REPORT" ]; then
    echo "  ✗ report.txt не создан."
    echo "    Убедись, что scan.sh записывает результат в report.txt"
    PASS=false
else
    echo "  ✓ report.txt создан."
fi

if [ -f "$REPORT" ]; then
    if grep -q "SCANNED: 8" "$REPORT"; then
        echo "  ✓ SCANNED: 8 — все серверы просканированы."
    else
        echo "  ✗ SCANNED не равно 8."
        echo "    Подсказка: убедись, что цикл проходит по всем logs/*.log"
        PASS=false
    fi
fi

if [ -f "$REPORT" ]; then
    ACTUAL_CRITICAL=$(grep -rl '\[CRITICAL\]' "$CASE_DIR/logs/" | xargs -I{} basename {} 2>/dev/null | head -1)
    if [ -n "$ACTUAL_CRITICAL" ] && grep -q "$ACTUAL_CRITICAL" "$REPORT"; then
        echo "  ✓ CRITICAL_FOUND правильно указывает на: $ACTUAL_CRITICAL"
    else
        echo "  ✗ CRITICAL_FOUND не содержит правильное имя файла (ожидался: $ACTUAL_CRITICAL)."
        PASS=false
    fi
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #102 ЗАКРЫТО.                                        ║"
    echo "║  Сборочный цех просканирован. Источник угрозы найден.        ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг: bash ~/nexus7/setup_case103.sh              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки:"
    echo "  bash ~/nexus7/check_case102.sh"
fi
echo ""
