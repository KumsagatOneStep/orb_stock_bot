#!/bin/bash
set -e

BASE="$HOME/nexus7/case3"

# Clean and recreate case3 directory structure
rm -rf "$BASE"
mkdir -p "$BASE/services/nexus-guard"
mkdir -p "$BASE/config"

# Create disabled config
cat > "$BASE/config/guard.conf.disabled" << 'EOF'
[nexus-guard]
port=7777
log_level=INFO
max_connections=100
auth_token=NX-2089-SECURE
EOF

# Create crash log
cat > "$BASE/services/nexus-guard/nexus-guard.log" << 'EOF'
[2089-03-15 23:58:55] nexus-guard v4.2 initializing...
[2089-03-15 23:58:55] Checking system resources... OK
[2089-03-15 23:58:55] Loading configuration from config/guard.conf
[2089-03-15 23:58:55] ERROR: Config file not found: config/guard.conf
[2089-03-15 23:58:55] FATAL: Cannot start without configuration. Exiting.
[2089-03-15 23:59:00] nexus-guard stopped. Exit code: 1
EOF

# Create status file
echo "inactive" > "$BASE/services/nexus-guard/nexus-guard.status"

# Create service control script
cat > "$BASE/services/nexus-guard/nexus-guard.sh" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$(cd "$DIR/../.." && pwd)"
CONFIG="$BASE/config/guard.conf"
STATUS="$DIR/nexus-guard.status"
LOG="$DIR/nexus-guard.log"

case "$1" in
  start)
    if [[ ! -f "$CONFIG" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Config not found: config/guard.conf" >> "$LOG"
      echo "FAILED: config/guard.conf not found. Service cannot start."
      exit 1
    fi
    echo "active" > "$STATUS"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] nexus-guard started successfully." >> "$LOG"
    echo "nexus-guard: ACTIVE"
    ;;
  stop)
    echo "inactive" > "$STATUS"
    echo "nexus-guard: STOPPED"
    ;;
  status)
    STATUS_VAL=$(cat "$STATUS" 2>/dev/null || echo "inactive")
    if [[ "$STATUS_VAL" == "active" ]]; then
      echo "nexus-guard: ACTIVE (running)"
    else
      echo "nexus-guard: INACTIVE (stopped)"
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    ;;
esac
EOF

chmod +x "$BASE/services/nexus-guard/nexus-guard.sh"

# Create briefing
cat > "$BASE/briefing.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║           NEXUS-7 // ДЕЛО #003 — МЁРТВЫЙ СТРАЖ                  ║
╚══════════════════════════════════════════════════════════════════╝

СТАТУС СИСТЕМЫ: КРИТИЧЕСКИЙ
ВРЕМЯ: 2089-03-16 00:04:22
ОПЕРАТОР: [ТЫ]

──────────────────────────────────────────────────────────────────
СВОДКА
──────────────────────────────────────────────────────────────────
Сторожевой демон nexus-guard упал в полночь и не поднимается.
Без него периметр Нексуса открыт для вторжения. У тебя — считанные
минуты, прежде чем мусорщики данных пройдут сквозь брешь.

Узнай, что случилось. Исправь. Запусти.

──────────────────────────────────────────────────────────────────
ТВОИ ЗАДАЧИ
──────────────────────────────────────────────────────────────────
1. Прочитай лог крэша — найди причину сбоя:
     cat services/nexus-guard/nexus-guard.log

2. Найди ошибку — используй grep:
     grep "ERROR" services/nexus-guard/nexus-guard.log

3. Посмотри что есть в конфигах:
     ls config/

4. Исправь проблему с помощью mv (переименуй файл конфига):
     mv config/guard.conf.disabled config/guard.conf

5. Запусти сервис:
     ./services/nexus-guard/nexus-guard.sh start

──────────────────────────────────────────────────────────────────
ПОДСКАЗКИ
──────────────────────────────────────────────────────────────────
• Лог говорит, что сервис ищет файл config/guard.conf
• Но в папке config/ лежит файл с другим именем...
• Расширение .disabled означает — файл отключён вручную
• Команда mv переименовывает файлы: mv старое_имя новое_имя

──────────────────────────────────────────────────────────────────
ПРОВЕРКА
──────────────────────────────────────────────────────────────────
Когда готово — запусти: bash ~/nexus7/check_case3.sh

Удачи, оператор. Нексус зависит от тебя.
EOF

echo "✓ Дело #003 подготовлено. Читай briefing.txt и начинай расследование."
echo "  cd ~/nexus7/case3 && cat briefing.txt"
