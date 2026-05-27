#!/bin/bash

BASE="$HOME/nexus7/case3"
PASS=true

echo "══════════════════════════════════════════════"
echo "  NEXUS-7 // ПРОВЕРКА ДЕЛА #003"
echo "══════════════════════════════════════════════"

# Check 1: guard.conf exists (not the .disabled version)
if [[ ! -f "$BASE/config/guard.conf" ]]; then
  echo "✗ Конфиг guard.conf не найден."
  echo "  Подсказка: ls ~/nexus7/case3/config/"
  echo "  Переименуй файл: mv config/guard.conf.disabled config/guard.conf"
  PASS=false
else
  echo "✓ Конфиг guard.conf найден."
fi

# Check 2: service status is active
STATUS_FILE="$BASE/services/nexus-guard/nexus-guard.status"
STATUS_VAL=$(cat "$STATUS_FILE" 2>/dev/null || echo "inactive")

if [[ "$STATUS_VAL" != "active" ]]; then
  echo "✗ Сервис nexus-guard не запущен (статус: $STATUS_VAL)."
  echo "  Подсказка: ./services/nexus-guard/nexus-guard.sh start"
  PASS=false
else
  echo "✓ Сервис nexus-guard активен."
fi

echo "══════════════════════════════════════════════"

if [[ "$PASS" == "true" ]]; then
  echo ""
  echo "✓ ДЕЛО #003 ЗАКРЫТО."
  echo ""
  echo "  Периметр восстановлен. Нексус под защитой."
  echo ""
  echo "  Следующее дело:"
  echo "    bash ~/nexus7/setup_case4.sh"
  echo ""
else
  echo ""
  echo "✗ Дело не закрыто. Исправь ошибки выше и повтори проверку."
  echo ""
fi
