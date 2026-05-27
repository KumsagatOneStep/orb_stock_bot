#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #001 — ПРИЗРАЧНЫЕ ФАЙЛЫ
# Check script — verifies player solved the case correctly

CASE_DIR="$HOME/nexus7/case1"
TARGET="$CASE_DIR/system/nexus.conf"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║                  ДЕЛО #001 — ПРИЗРАЧНЫЕ ФАЙЛЫ                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Проверка 1: файл существует ───────────────────────────────────────────────
if [ -f "$TARGET" ]; then
    echo "  ✓ Файл system/nexus.conf найден."
else
    echo "  ✗ Файл system/nexus.conf не найден."
    echo "    ПОДСКАЗКА: Сначала найди файл: find ~/nexus7/case1 -name \"*.conf*\""
    echo "               Затем скопируй: cp <файл> ~/nexus7/case1/system/nexus.conf"
    PASS=false
fi

# ── Проверка 2: права 644 ─────────────────────────────────────────────────────
if [ -f "$TARGET" ]; then
    # macOS: stat -f %OLp; Linux fallback: stat -c %a
    if stat -f %OLp "$TARGET" > /dev/null 2>&1; then
        PERMS=$(stat -f %OLp "$TARGET")
    else
        PERMS=$(stat -c %a "$TARGET")
    fi

    if [ "$PERMS" = "644" ]; then
        echo "  ✓ Права доступа корректны: 644."
    else
        echo "  ✗ Неверные права доступа: $PERMS (нужно 644)."
        echo "    ПОДСКАЗКА: chmod 644 ~/nexus7/case1/system/nexus.conf"
        PASS=false
    fi
fi

# ── Проверка 3: содержимое файла ─────────────────────────────────────────────
if [ -f "$TARGET" ]; then
    if grep -q "NEXUS-7 CONFIG v2.089" "$TARGET"; then
        echo "  ✓ Содержимое файла верно: NEXUS-7 CONFIG v2.089."
    else
        echo "  ✗ Содержимое файла неверно или повреждено."
        echo "    ПОДСКАЗКА: Убедись, что ты скопировал backup/nexus.conf.bak, а не nexus_v1.conf"
        PASS=false
    fi
fi

# ── Итог ──────────────────────────────────────────────────────────────────────
echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #001 ЗАКРЫТО.                                        ║"
    echo "║  NEXUS-7 CONFIG восстановлен. Ядро системы онлайн.           ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг:  bash ~/nexus7/setup_case2.sh               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки и запусти проверку снова."
    echo "  bash ~/nexus7/check_case1.sh"
fi
echo ""
