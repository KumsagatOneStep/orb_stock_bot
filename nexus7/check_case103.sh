#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #103 — проверка

CASE_DIR="$HOME/nexus7/case103"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #103 — НОЧНОЙ СТОРОЖ                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -d "$CASE_DIR" ]; then
    echo "  ✗ Рабочая директория не найдена. Запусти сначала:"
    echo "    bash ~/nexus7/setup_case103.sh"
    exit 1
fi

COLLECT="$CASE_DIR/collect.sh"
if [ ! -f "$COLLECT" ]; then
    echo "  ✗ collect.sh не найден. Запусти setup заново:"
    echo "    bash ~/nexus7/setup_case103.sh"
    PASS=false
elif [ -x "$COLLECT" ]; then
    echo "  ✓ collect.sh исполняемый."
else
    echo "  ✗ collect.sh не исполняемый."
    echo "    Подсказка: chmod +x $CASE_DIR/collect.sh"
    PASS=false
fi

SNAP_COUNT=$(find "$CASE_DIR/snapshots/" -name "snap_*.txt" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SNAP_COUNT" -eq 0 ]; then
    echo "  ✗ Снапшоты не найдены в snapshots/."
    echo "    Подсказка: подожди 1–2 минуты после добавления в crontab"
    echo "    Или запусти вручную: bash $CASE_DIR/collect.sh"
    PASS=false
else
    echo "  ✓ Снапшоты созданы ($SNAP_COUNT шт.)."
fi

CRON_LOG="$CASE_DIR/cron.log"
if [ ! -f "$CRON_LOG" ]; then
    echo "  ✗ cron.log не найден."
    echo "    Подсказка: добавь >> $CASE_DIR/cron.log 2>&1 в конец crontab-строки"
    PASS=false
elif [ ! -s "$CRON_LOG" ]; then
    echo "  ✗ cron.log пустой."
    echo "    Подсказка: убедись что stdout скрипта перенаправлен в cron.log"
    PASS=false
else
    echo "  ✓ cron.log существует и не пустой."
fi

CRON_ACTIVE=$(crontab -l 2>/dev/null | grep -c "collect.sh" || true)
if [ "$CRON_ACTIVE" -gt 0 ]; then
    echo "  ✗ Запись с collect.sh всё ещё активна в crontab."
    echo "    Подсказка: crontab -e  → удали строку с collect.sh"
    PASS=false
else
    echo "  ✓ Запись в crontab удалена — следов нет."
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #103 ЗАКРЫТО.                                        ║"
    echo "║  Ночной сторож отработал и исчез. Данные собраны.            ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг: bash ~/nexus7/setup_case104.sh              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки:"
    echo "  bash ~/nexus7/check_case103.sh"
fi
echo ""
