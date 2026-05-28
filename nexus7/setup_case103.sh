#!/usr/bin/env bash
set -e
# NEXUS-7 :: ДЕЛО #103 — НОЧНОЙ СТОРОЖ

CASE_DIR="$HOME/nexus7/case103"

chmod -R u+rwx "$CASE_DIR" 2>/dev/null || true
rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR/snapshots"

cat > "$CASE_DIR/collect.sh" <<'COLLECT'
#!/usr/bin/env bash
# OmegaTech data collector — runs via cron
SNAP_DIR="$(dirname "$0")/snapshots"
mkdir -p "$SNAP_DIR"
OUTFILE="$SNAP_DIR/snap_$(date +%s).txt"
{
    echo "=== OMEGA SNAPSHOT ==="
    echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "UPTIME: $(uptime)"
    echo "PROCS: $(ps aux 2>/dev/null | wc -l | tr -d ' ')"
} > "$OUTFILE"
echo "[collect] snapshot saved: $OUTFILE"
COLLECT
chmod 644 "$CASE_DIR/collect.sh"

cat > "$CASE_DIR/cron_broken.txt" <<'BROKEN'
# НЕПРАВИЛЬНЫЙ crontab — найди 3 проблемы:

# Проблема 1: PATH не указан — cron не найдёт collect.sh
* * * * * collect.sh >> cron.log 2>&1

# Проблема 2: ~ не раскрывается в cron — используй полный путь /home/user/...
* * * * * ~/nexus7/case103/collect.sh

# Проблема 3: нет flock — если collect.sh зависнет, процессы накопятся
* * * * * /полный/путь/к/collect.sh >> ~/nexus7/case103/cron.log 2>&1
BROKEN

# Detect flock availability for briefing
if command -v flock >/dev/null 2>&1; then
    FLOCK_NOTE="flock доступен — используй его!"
    FLOCK_EXAMPLE="* * * * * /usr/bin/flock -n /tmp/omega.lock $CASE_DIR/collect.sh >> $CASE_DIR/cron.log 2>&1"
else
    FLOCK_NOTE="ПРИМЕЧАНИЕ: flock не найден (macOS). Для установки: brew install util-linux
  Пока используй скрипт без flock (для обучения концепции)."
    FLOCK_EXAMPLE="* * * * * $CASE_DIR/collect.sh >> $CASE_DIR/cron.log 2>&1"
fi

cat > "$CASE_DIR/briefing.txt" <<BRIEF
╔══════════════════════════════════════════════════════════════╗
║        NEXUS-7 // ОПЕРАЦИЯ АВТОМАТИЗАЦИЯ                      ║
║           ДЕЛО #103 — НОЧНОЙ СТОРОЖ                           ║
╚══════════════════════════════════════════════════════════════╝

ВХОДЯЩЕЕ СООБЩЕНИЕ // 2089-09-05 // ШИФР: ОМЕГА
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Kira-7,

Нам нужен тихий наблюдатель — задание в cron которое каждую
минуту собирает снапшот сервера OmegaTech.
Но если предыдущий сбор ещё не завершился — новый запуск не
должен накладываться. Иначе файлы перепутаются.
После завершения — следов быть не должно. Удали запись из cron.

$FLOCK_NOTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАНИЕ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Сделай collect.sh исполняемым:
   chmod +x $CASE_DIR/collect.sh

2. Изучи неправильный crontab: cat cron_broken.txt
   Найди 3 проблемы (указаны в комментариях).

3. Добавь ПРАВИЛЬНУЮ запись в crontab:
   crontab -e
   Вставь:
   $FLOCK_EXAMPLE

4. Подожди 1–2 минуты, убедись что появились файлы:
   ls snapshots/         # → snap_*.txt
   cat cron.log          # → строки с [collect]

5. ВАЖНО: удали запись из cron (операция секретная!):
   crontab -e  → удали строку с collect.sh
   Проверь: crontab -l   # строки с collect.sh не должно быть

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
НАВЫКИ: crontab | PATH в cron | flock | логирование
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Запусти: bash ~/nexus7/check_case103.sh
BRIEF

echo ""
cat "$CASE_DIR/briefing.txt"
echo ""
echo "  Рабочая директория: $CASE_DIR"
echo "  Начни здесь: cd ~/nexus7/case103"
echo ""
