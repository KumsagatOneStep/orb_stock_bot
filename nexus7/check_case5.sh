#!/bin/bash
set -e

BASE="$HOME/nexus7/case5"
SCORE=0

echo "══════════════════════════════════════════════════════════════════"
echo "  NEXUS-7 // ФИНАЛЬНАЯ ПРОВЕРКА — ПРОТОКОЛ ФЕНИКС"
echo "══════════════════════════════════════════════════════════════════"
echo ""

# ──────────────────────────────────────────────────────────────────
# Check 1: system/phoenix.conf exists, has 644 perms, valid content
# ──────────────────────────────────────────────────────────────────
CONF="$BASE/system/phoenix.conf"
if [[ ! -f "$CONF" ]]; then
  echo "✗ [1/5] Конфиг system/phoenix.conf не найден."
  echo "        Подсказка: chmod 644 backup/phoenix.conf.old && cp backup/phoenix.conf.old system/phoenix.conf"
else
  # Get permissions (macOS first, Linux fallback)
  if stat -f %OLp "$CONF" > /dev/null 2>&1; then
    PERMS=$(stat -f %OLp "$CONF")
  else
    PERMS=$(stat -c %a "$CONF")
  fi

  if [[ "$PERMS" != "644" ]]; then
    echo "✗ [1/5] Конфиг найден, но права доступа неверны (сейчас: $PERMS, нужно: 644)."
    echo "        Подсказка: chmod 644 system/phoenix.conf"
  elif ! grep -qiE "PHOENIX CONFIG|phoenix-core|mode=guardian" "$CONF"; then
    echo "✗ [1/5] Конфиг найден, но содержимое не похоже на конфиг феникса."
    echo "        Подсказка: cp backup/phoenix.conf.old system/phoenix.conf"
  else
    echo "✓ [1/5] Конфиг system/phoenix.conf восстановлен (права: $PERMS, содержимое OK)."
    SCORE=$((SCORE + 1))
  fi
fi

# ──────────────────────────────────────────────────────────────────
# Check 2: answer.txt contains the attacker IP
# ──────────────────────────────────────────────────────────────────
ANSWER="$BASE/answer.txt"
if [[ ! -f "$ANSWER" ]]; then
  echo "✗ [2/5] Файл answer.txt не найден."
  echo "        Подсказка: grep \"401\" logs/incident.log  →  echo \"IP: x.x.x.x\" > answer.txt"
elif ! grep -q "10.99.255.1" "$ANSWER"; then
  echo "✗ [2/5] В answer.txt нет IP атакующего (10.99.255.1)."
  echo "        Подсказка: grep \"401\" logs/incident.log  →  echo \"IP: 10.99.255.1\" > answer.txt"
else
  echo "✓ [2/5] Атакующий идентифицирован — IP 10.99.255.1 записан в answer.txt."
  SCORE=$((SCORE + 1))
fi

# ──────────────────────────────────────────────────────────────────
# Check 3: phoenix service is active
# ──────────────────────────────────────────────────────────────────
STATUS_FILE="$BASE/services/phoenix/phoenix.status"
STATUS_VAL=$(cat "$STATUS_FILE" 2>/dev/null || echo "inactive")

if [[ "$STATUS_VAL" != "active" ]]; then
  echo "✗ [3/5] Сервис phoenix не запущен (статус: $STATUS_VAL)."
  echo "        Подсказка: mv config/phoenix.conf.disabled config/phoenix.conf"
  echo "                   ./services/phoenix/phoenix.sh start"
else
  echo "✓ [3/5] Сервис phoenix активен и работает."
  SCORE=$((SCORE + 1))
fi

# ──────────────────────────────────────────────────────────────────
# Check 4: rm -rf line in cron is commented out
# ──────────────────────────────────────────────────────────────────
CRON_FILE="$BASE/cron.d/nightly"
if [[ ! -f "$CRON_FILE" ]]; then
  echo "✗ [4/5] Файл cron.d/nightly не найден."
  echo "        Подсказка: файл должен существовать — запусти setup заново если он исчез."
elif grep -Eq "^[^#].*rm -rf" "$CRON_FILE"; then
  echo "✗ [4/5] Бэкдор в cron всё ещё активен — строка rm -rf не закомментирована."
  echo "        Подсказка: sed -i '' 's/^0 4 \* \* \* rm/# 0 4 * * * rm/' cron.d/nightly"
else
  echo "✓ [4/5] Бэкдор нейтрализован — опасная строка в cron.d/nightly закомментирована."
  SCORE=$((SCORE + 1))
fi

# ──────────────────────────────────────────────────────────────────
# Check 5: archive/ contains at least one .tar.gz
# ──────────────────────────────────────────────────────────────────
ARCHIVE_DIR="$BASE/archive"
ARCHIVE_COUNT=$(find "$ARCHIVE_DIR" -maxdepth 1 -name "*.tar.gz" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$ARCHIVE_COUNT" -eq 0 ]]; then
  echo "✗ [5/5] Архив не создан — в archive/ нет ни одного .tar.gz файла."
  echo "        Подсказка: tar -czf archive/backup_final.tar.gz system/ logs/"
else
  echo "✓ [5/5] Резервный архив создан (найдено файлов .tar.gz: $ARCHIVE_COUNT)."
  SCORE=$((SCORE + 1))
fi

# ──────────────────────────────────────────────────────────────────
# Final result
# ──────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  РЕЗУЛЬТАТ: $SCORE / 5"
echo "══════════════════════════════════════════════════════════════════"

if [[ "$SCORE" -eq 5 ]]; then
  echo ""
  echo "██████████████████████████████████████████████████████████████████"
  echo "█                                                                 █"
  echo "█        П Р О Т О К О Л   Ф Е Н И К С   А К Т И В И Р О В А Н  █"
  echo "█                                                                █"
  echo "█             N E X U S - 7   В О С С Т А Н О В Л Е Н           █"
  echo "█                                                                █"
  echo "█           K i r a - 7  —  Л е г е н д а  Н е о - А л м а т ы  █"
  echo "█                                                                █"
  echo "██████████████████████████████████████████████████████████████████"
  echo ""
  echo "  Нексус снова дышит. Ты сделала это, оператор."
  echo "  Все пять дел закрыты. Все системы в норме."
  echo ""
  echo "  Нео-Алматы в безопасности. Феникс возродился."
  echo ""
else
  echo ""
  echo "  Не все задачи выполнены. Исправь ошибки выше и повтори:"
  echo "    bash ~/nexus7/check_case5.sh"
  echo ""
fi
