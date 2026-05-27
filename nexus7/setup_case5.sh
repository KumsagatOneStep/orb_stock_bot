#!/bin/bash
set -e

BASE="$HOME/nexus7/case5"

# Clean and recreate case5 directory structure
rm -rf "$BASE"
mkdir -p "$BASE"/{system,backup,logs,services/phoenix,config,cron.d,archive}

# ──────────────────────────────────────────────────────────────────
# Problem 1: missing config with bad permissions
# ──────────────────────────────────────────────────────────────────
cat > "$BASE/backup/phoenix.conf.old" << 'EOF'
PHOENIX CONFIG v5.0
MODE=GUARDIAN
FIREWALL=ENABLED
ENCRYPTION=AES-256
CORE=phoenix-core
EOF
chmod 000 "$BASE/backup/phoenix.conf.old"

# ──────────────────────────────────────────────────────────────────
# Problem 2: attacker IP buried in incident log
# ──────────────────────────────────────────────────────────────────
python3 - << 'PYEOF'
import random, os

base = os.path.expanduser("~/nexus7/case5")
log_path = os.path.join(base, "logs", "incident.log")

normal_ips = ["10.0.0.1", "10.0.0.2", "172.16.0.3"]
endpoints = ["/api/status", "/phoenix/health", "/api/users"]
methods = ["GET", "GET", "GET", "POST"]
codes = [200, 200, 200, 200, 200, 304, 204]

lines = []

# Generate ~80 normal lines across timestamps from 00:00 to ~04:00
import datetime
base_time = datetime.datetime(2089, 3, 16, 0, 0, 0)
for i in range(80):
    ts = base_time + datetime.timedelta(seconds=random.randint(0, 14400))
    ts_str = ts.strftime("%Y-%m-%d %H:%M:%S")
    ip = random.choice(normal_ips)
    method = random.choice(methods)
    endpoint = random.choice(endpoints)
    code = random.choice(codes)
    lines.append((ts, f"[{ts_str}] {ip} {method} {endpoint} {code}"))

# Attack line at exactly 02:13:44
attack_ts = datetime.datetime(2089, 3, 16, 2, 13, 44)
attack_line = "[2089-03-16 02:13:44] 10.99.255.1 POST /phoenix/override 401"
lines.append((attack_ts, attack_line))

# Sort by timestamp
lines.sort(key=lambda x: x[0])

with open(log_path, "w") as f:
    for _, line in lines:
        f.write(line + "\n")
PYEOF

# ──────────────────────────────────────────────────────────────────
# Problem 3: dead phoenix service (config has wrong extension)
# ──────────────────────────────────────────────────────────────────
cat > "$BASE/config/phoenix.conf.disabled" << 'EOF'
[phoenix]
mode=guardian
port=9999
log_level=WARN
encryption=AES-256
auth_token=PX-2089-OMEGA
EOF

cat > "$BASE/services/phoenix/phoenix.log" << 'EOF'
[2089-03-16 01:00:00] phoenix v5.0 initializing...
[2089-03-16 01:00:00] Checking system resources... OK
[2089-03-16 01:00:00] Loading configuration from config/phoenix.conf
[2089-03-16 01:00:00] ERROR: Config file not found: config/phoenix.conf
[2089-03-16 01:00:00] FATAL: Cannot start without configuration. Exiting.
[2089-03-16 01:00:01] phoenix stopped. Exit code: 1
EOF

echo "inactive" > "$BASE/services/phoenix/phoenix.status"

cat > "$BASE/services/phoenix/phoenix.sh" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$(cd "$DIR/../.." && pwd)"
CONFIG="$BASE/config/phoenix.conf"
STATUS="$DIR/phoenix.status"
LOG="$DIR/phoenix.log"

case "$1" in
  start)
    if [[ ! -f "$CONFIG" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Config not found: config/phoenix.conf" >> "$LOG"
      echo "FAILED: config/phoenix.conf not found. Service cannot start."
      exit 1
    fi
    echo "active" > "$STATUS"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] phoenix started successfully." >> "$LOG"
    echo "phoenix: ACTIVE"
    ;;
  stop)
    echo "inactive" > "$STATUS"
    echo "phoenix: STOPPED"
    ;;
  status)
    STATUS_VAL=$(cat "$STATUS" 2>/dev/null || echo "inactive")
    if [[ "$STATUS_VAL" == "active" ]]; then
      echo "phoenix: ACTIVE (running)"
    else
      echo "phoenix: INACTIVE (stopped)"
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    ;;
esac
EOF

chmod +x "$BASE/services/phoenix/phoenix.sh"

# ──────────────────────────────────────────────────────────────────
# Problem 4: malicious cron with rm -rf in it
# ──────────────────────────────────────────────────────────────────
cat > "$BASE/cron.d/nightly" << 'EOF'
# NexusTech Nightly Schedule — Phoenix Protocol
# Last modified: 2089-03-16 00:00:01 by system-bot v5.0

# System sync — safe
0 1 * * * /usr/bin/sync

# BACKDOOR: wipe backups at 04:00 (DANGEROUS — injected by attacker)
0 4 * * * rm -rf ~/nexus7/case5/archive/*.tar.gz
EOF

# ──────────────────────────────────────────────────────────────────
# Problem 5: player creates the backup archive themselves
# (archive/ directory is empty — that's intentional)
# ──────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────
# Briefing — FINAL BOSS
# ──────────────────────────────────────────────────────────────────
cat > "$BASE/briefing.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║         NEXUS-7 // ДЕЛО #005 — ФИНАЛ: ПРОТОКОЛ ФЕНИКС           ║
╚══════════════════════════════════════════════════════════════════╝

СТАТУС СИСТЕМЫ: КРИТИЧЕСКИЙ — ПРОТОКОЛ ФЕНИКС НЕДОСТУПЕН
ВРЕМЯ: 2089-03-16 06:00:00
ОПЕРАТОР: Kira-7

──────────────────────────────────────────────────────────────────
ФИНАЛЬНАЯ СВОДКА
──────────────────────────────────────────────────────────────────
Нео-Алматы в осаде. Вся защитная сеть Нексуса рухнула за одну ночь.
Феникс — последний протокол восстановления — не отвечает.

Кто-то намеренно сломал всё сразу: конфиги, логи, сервис, расписание.
Один просчёт — и Нексус падёт навсегда.

Ты дошла до этого момента. Пять задач. Последний шанс.
Активируй Протокол Феникс — или Нексус сгорит.

──────────────────────────────────────────────────────────────────
ЗАДАЧА 1 — ВОССТАНОВИТЬ КОНФИГ
──────────────────────────────────────────────────────────────────
Конфиг феникса заперт в резервной копии с нулевыми правами.
Найди файл, исправь права, скопируй в систему:

  ls -la backup/
  chmod 644 backup/phoenix.conf.old
  cp backup/phoenix.conf.old system/phoenix.conf

──────────────────────────────────────────────────────────────────
ЗАДАЧА 2 — ВЫЧИСЛИТЬ АТАКУЮЩЕГО
──────────────────────────────────────────────────────────────────
В логах зарыта запись о несанкционированном вторжении.
Запрос на /phoenix/override с кодом 401 — это след атакующего.

  grep "401" logs/incident.log

Когда найдёшь IP — запиши его в answer.txt:

  echo "IP: x.x.x.x" > answer.txt

──────────────────────────────────────────────────────────────────
ЗАДАЧА 3 — ПОДНЯТЬ СЕРВИС
──────────────────────────────────────────────────────────────────
Феникс не запускается — конфиг лежит с неправильным расширением.

  cat services/phoenix/phoenix.log
  ls config/

Переименуй конфиг и запусти сервис:

  mv config/phoenix.conf.disabled config/phoenix.conf
  ./services/phoenix/phoenix.sh start

──────────────────────────────────────────────────────────────────
ЗАДАЧА 4 — ОБЕЗВРЕДИТЬ БЭКДОР
──────────────────────────────────────────────────────────────────
Атакующий оставил мину в расписании — таймер на уничтожение архивов.
Найди опасную строку и закомментируй её:

  cat cron.d/nightly

  sed -i '' 's/^0 4 \* \* \* rm/# 0 4 * * * rm/' cron.d/nightly

──────────────────────────────────────────────────────────────────
ЗАДАЧА 5 — СОЗДАТЬ ФИНАЛЬНЫЙ АРХИВ
──────────────────────────────────────────────────────────────────
Последний шаг — запечатать восстановленную систему в защищённый архив.
Используй tar для создания резервной копии:

  tar -czf archive/backup_final.tar.gz system/ logs/

Проверь архив:
  ls -lh archive/

──────────────────────────────────────────────────────────────────
ФИНАЛЬНАЯ ПРОВЕРКА
──────────────────────────────────────────────────────────────────
Когда все пять задач выполнены — запусти финальную проверку:

  bash ~/nexus7/check_case5.sh

Нексус ждёт тебя, оператор. Это твой момент.
EOF

echo "✓ Дело #005 — ФИНАЛ подготовлено."
echo ""
echo "  Это последнее дело. Всё, чему ты научилась — понадобится здесь."
echo ""
echo "  cd ~/nexus7/case5 && cat briefing.txt"
