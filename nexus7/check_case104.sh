#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #104 — проверка

CASE_DIR="$HOME/nexus7/case104"
SVC="$CASE_DIR/units/omega-monitor.service"
TMR="$CASE_DIR/units/omega-monitor.timer"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #104 — ПОСТОЯННЫЙ ДОЗОР                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -d "$CASE_DIR" ]; then
    echo "  ✗ Рабочая директория не найдена. Запусти сначала:"
    echo "    bash ~/nexus7/setup_case104.sh"
    exit 1
fi

if [ ! -f "$SVC" ]; then
    echo "  ✗ units/omega-monitor.service не найден."
    echo "    Подсказка: cp templates/omega-monitor.service.template units/omega-monitor.service"
    PASS=false
elif grep -q "__SCRIPT_PATH__" "$SVC"; then
    echo "  ✗ units/omega-monitor.service содержит незамененный __SCRIPT_PATH__."
    echo "    macOS: sed -i '' \"s|__SCRIPT_PATH__|/полный/путь/к/monitor.sh|g\" units/omega-monitor.service"
    echo "    Linux: sed -i \"s|__SCRIPT_PATH__|/полный/путь/к/monitor.sh|g\" units/omega-monitor.service"
    PASS=false
elif grep -q "ExecStart=" "$SVC"; then
    echo "  ✓ omega-monitor.service корректен (ExecStart= заполнен)."
else
    echo "  ✗ omega-monitor.service не содержит ExecStart=."
    PASS=false
fi

if [ ! -f "$TMR" ]; then
    echo "  ✗ units/omega-monitor.timer не найден."
    echo "    Подсказка: cp templates/omega-monitor.timer.template units/omega-monitor.timer"
    PASS=false
else
    if grep -q "Persistent=true" "$TMR"; then
        echo "  ✓ omega-monitor.timer содержит Persistent=true."
    else
        echo "  ✗ Persistent=true не найден в omega-monitor.timer."
        echo "    Добавь в секцию [Timer]: Persistent=true"
        PASS=false
    fi

    if grep -q "OnCalendar=minutely" "$TMR"; then
        echo "  ✓ OnCalendar=minutely задан."
    else
        echo "  ✗ OnCalendar=minutely не найден."
        echo "    В секцию [Timer] добавь: OnCalendar=minutely"
        PASS=false
    fi
fi

# Linux-only: optionally check if timer is running
if command -v systemctl >/dev/null 2>&1; then
    TIMER_STATE=$(systemctl --user is-active omega-monitor.timer 2>/dev/null || echo "inactive")
    if [ "$TIMER_STATE" = "active" ]; then
        echo "  ✓ (Linux) omega-monitor.timer активен."
    else
        echo "  ℹ (Linux) Таймер не активен — unit-файлы проверены статически."
        echo "    Для запуска: cp units/* ~/.config/systemd/user/ && systemctl --user enable --now omega-monitor.timer"
    fi
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #104 ЗАКРЫТО.                                        ║"
    echo "║  Постоянный дозор настроен. Persistent=true активен.         ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг: bash ~/nexus7/setup_case105.sh              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки:"
    echo "  bash ~/nexus7/check_case104.sh"
fi
echo ""
