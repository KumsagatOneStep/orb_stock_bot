#!/bin/bash
set -e

CRON_FILE="$HOME/nexus7/case4/cron.d/nexus-maintenance"

if [[ ! -f "$CRON_FILE" ]]; then
  echo "✗ Файл $CRON_FILE не найден. Запусти setup сначала: bash ~/nexus7/setup_case4.sh"
  exit 1
fi

# Check if the rm -rf line is still active (not commented out)
if grep -Eq "^[^#].*rm -rf.*\.dat" "$CRON_FILE"; then
  echo "✗ Строка с 'rm -rf *.dat' всё ещё активна."
  echo "  Подсказка: закомментируй строку — добавь # в её начало."
  echo "  Пример: sed -i '' 's/^0 3 \* \* \* rm/# 0 3 * * * rm/' cron.d/nexus-maintenance"
  exit 1
fi

# Check if the find -delete line is still active (not commented out)
if grep -Eq "^[^#].*find.*\.tar.*-delete" "$CRON_FILE"; then
  echo "✗ Строка с 'find *.tar -delete' всё ещё активна."
  echo "  Подсказка: закомментируй строку — добавь # в её начало."
  echo "  Пример: sed -i '' 's/^15 3 \* \* \* find/# 15 3 * * * find/' cron.d/nexus-maintenance"
  exit 1
fi

echo "✓ ДЕЛО #004 ЗАКРЫТО."
echo ""
echo "  Ночной таймер нейтрализован. Торговые отчёты Нексуса в безопасности."
echo "  Следующее дело: bash ~/nexus7/setup_case5.sh"
