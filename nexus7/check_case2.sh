#!/usr/bin/env bash

ANSWER="$HOME/nexus7/case2/answer.txt"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           NEXUS-7 // ПРОВЕРКА ДЕЛА #002                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Проверка 1: файл существует ────────────────────────────────────────────
if [ ! -f "$ANSWER" ]; then
    echo "✗ Файл answer.txt не найден."
    echo "  Подсказка: создай ~/nexus7/case2/answer.txt"
    echo "  Пример:"
    echo "    echo \"IP: X.X.X.X\" > ~/nexus7/case2/answer.txt"
    echo "    echo \"TIME: HH:MM:SS\" >> ~/nexus7/case2/answer.txt"
    echo ""
    exit 1
fi

# ── Проверка 2: правильный IP ──────────────────────────────────────────────
if ! grep -q "192.168.77.13" "$ANSWER"; then
    echo "✗ IP-адрес неверный или отсутствует."
    echo "  Подсказка: запусти grep \"DELETE\" ~/nexus7/case2/logs/access.log"
    echo "  Затем запиши IP в answer.txt строкой: IP: <адрес>"
    PASS=false
fi

# ── Проверка 3: правильное время ───────────────────────────────────────────
if ! grep -q "03:47:22" "$ANSWER"; then
    echo "✗ Время атаки неверное или отсутствует."
    echo "  Подсказка: запусти grep \"DELETE\" ~/nexus7/case2/logs/access.log"
    echo "  Затем запиши время в answer.txt строкой: TIME: HH:MM:SS"
    PASS=false
fi

# ── Итог ───────────────────────────────────────────────────────────────────
if [ "$PASS" = true ]; then
    echo "✓ ДЕЛО #002 ЗАКРЫТО."
    echo ""
    echo "  Угроза нейтрализована. IP злоумышленника задокументирован."
    echo "  Готов к следующему заданию?"
    echo "  Запусти: bash ~/nexus7/setup_case3.sh"
fi

echo ""
