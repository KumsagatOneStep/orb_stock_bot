# NEXUS-7 Season 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 10 Bash scripts (5 setup + 5 check) for NEXUS-7 Season 2 cases #101–#105, teaching Bash automation, cron, systemd timers, and SSH/rsync.

**Architecture:** Each case is a `setup_caseN.sh` (creates environment + briefing) paired with `check_caseN.sh` (validates solution with per-check hints). All scripts run on macOS and Linux; platform differences handled inline.

**Tech Stack:** Bash, Python 3 (log generation), cron, systemd (Linux-only for live timers), ssh/rsync

---

## File Map

| File | Action |
|------|--------|
| `~/nexus7/setup_case101.sh` | Create |
| `~/nexus7/check_case101.sh` | Create |
| `~/nexus7/setup_case102.sh` | Create |
| `~/nexus7/check_case102.sh` | Create |
| `~/nexus7/setup_case103.sh` | Create |
| `~/nexus7/check_case103.sh` | Create |
| `~/nexus7/setup_case104.sh` | Create |
| `~/nexus7/check_case104.sh` | Create |
| `~/nexus7/setup_case105.sh` | Create |
| `~/nexus7/check_case105.sh` | Create |
| `~/nexus7/README.md` | Modify — add Season 2 table |

---

## Task 1: Case #101 — "Первый Контакт" (Bash: переменные, if/else, set -euo pipefail)

**Files:**
- Create: `~/nexus7/setup_case101.sh`
- Create: `~/nexus7/check_case101.sh`

- [ ] **Step 1: Write setup_case101.sh**

```bash
# File: ~/nexus7/setup_case101.sh
#!/usr/bin/env bash
set -e
# NEXUS-7 :: ДЕЛО #101 — ПЕРВЫЙ КОНТАКТ

CASE_DIR="$HOME/nexus7/case101"

chmod -R u+rwx "$CASE_DIR" 2>/dev/null || true
rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR/system" "$CASE_DIR/config"

cat > "$CASE_DIR/system/status.txt" <<'EOF'
STATUS=OPERATIONAL
UPTIME=99.97%
THREAT_LEVEL=RED
EOF

cat > "$CASE_DIR/config/omega.conf.template" <<'EOF'
# OmegaTech Server Config — AUTO-GENERATED
AGENT=__AGENT__
DEPLOY_TIME=__TIMESTAMP__
MODE=INFILTRATION
ACCESS=GRANTED
EOF

cat > "$CASE_DIR/deploy_broken.sh" <<'BROKEN'
#!/bin/bash
# DEPLOY SCRIPT v0.1 — OmegaTech internal
# ЭТО СЛОМАННЫЙ СКРИПТ. Изучи его и напиши правильный deploy.sh

# БАГ 1: нет set -euo pipefail — скрипт продолжает при ошибках
# БАГ 2: переменная AGENT_NAME не проверяется на пустоту
# БАГ 3: STATUS не проверяется — деплой идёт даже если сервер DEGRADED
# БАГ 4: шаблон __AGENT__ не заменяется реальным именем агента

AGENT=$AGENT_NAME
cp config/omega.conf.template config/omega.conf
echo "Deployed by $AGENT at $(date)"
BROKEN
chmod 644 "$CASE_DIR/deploy_broken.sh"

cat > "$CASE_DIR/briefing.txt" <<'BRIEF'
╔══════════════════════════════════════════════════════════════╗
║        NEXUS-7 // ОПЕРАЦИЯ АВТОМАТИЗАЦИЯ                      ║
║           ДЕЛО #101 — ПЕРВЫЙ КОНТАКТ                          ║
╚══════════════════════════════════════════════════════════════╝

ВХОДЯЩЕЕ СООБЩЕНИЕ // 2089-09-03 // ШИФР: ОМЕГА
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Агент Kira-7,

Мы получили доступ к серверам OmegaTech.
Чтобы закрепиться в системе — нужен надёжный скрипт развёртывания.
Их скрипт deploy_broken.sh сделан наспех. Он опасен.

Напиши правильный deploy.sh — скрипт который не делает ничего
лишнего, падает при ошибке и проверяет окружение перед запуском.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАНИЕ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Изучи сломанный скрипт: cat deploy_broken.sh
   Запомни 4 бага (описаны в комментариях внутри).

2. Создай deploy.sh в ~/nexus7/case101/ со следующими требованиями:
   a) #!/usr/bin/env bash
   b) set -euo pipefail  ← обязательно, вторая строка!
   c) Переменная AGENT_NAME (читается из окружения)
   d) Читать STATUS из system/status.txt:
        STATUS=$(grep '^STATUS=' system/status.txt | cut -d= -f2)
   e) if [ "$STATUS" != "OPERATIONAL" ] — вывести ошибку, exit 1
   f) Скопировать шаблон в config/omega.conf,
      заменив __AGENT__ → $AGENT_NAME:
        sed "s/__AGENT__/$AGENT_NAME/g" config/omega.conf.template \
            > config/omega.conf

3. Сделать скрипт исполняемым:
   chmod +x deploy.sh

4. Проверить:
   STATUS=OPERATIONAL AGENT_NAME=Kira ./deploy.sh
   cat config/omega.conf   # → должен содержать AGENT=Kira

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
НАВЫКИ: set -euo pipefail | переменные | if/else | sed | exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Когда готово — запусти: bash ~/nexus7/check_case101.sh
BRIEF

echo ""
cat "$CASE_DIR/briefing.txt"
echo ""
echo "  Рабочая директория: $CASE_DIR"
echo "  Начни здесь: cd ~/nexus7/case101"
echo ""
```

- [ ] **Step 2: Write check_case101.sh**

```bash
# File: ~/nexus7/check_case101.sh
#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #101 — проверка

CASE_DIR="$HOME/nexus7/case101"
SCRIPT="$CASE_DIR/deploy.sh"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #101 — ПЕРВЫЙ КОНТАКТ                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -f "$SCRIPT" ]; then
    echo "  ✗ deploy.sh не найден."
    echo "    Создай файл: ~/nexus7/case101/deploy.sh"
    PASS=false
else
    echo "  ✓ deploy.sh найден."
fi

if [ -f "$SCRIPT" ]; then
    if [ -x "$SCRIPT" ]; then
        echo "  ✓ deploy.sh исполняемый."
    else
        echo "  ✗ deploy.sh не исполняемый."
        echo "    Подсказка: chmod +x ~/nexus7/case101/deploy.sh"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q "set -euo pipefail" "$SCRIPT"; then
        echo "  ✓ set -euo pipefail найден."
    else
        echo "  ✗ set -euo pipefail не найден."
        echo "    Добавь второй строкой в скрипт: set -euo pipefail"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q 'AGENT_NAME' "$SCRIPT"; then
        echo "  ✓ Переменная AGENT_NAME используется."
    else
        echo "  ✗ Переменная AGENT_NAME не найдена."
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q 'STATUS' "$SCRIPT" && grep -q '\bif\b' "$SCRIPT"; then
        echo "  ✓ Проверка STATUS найдена."
    else
        echo "  ✗ Нет проверки STATUS в if-блоке."
        echo '    Подсказка: if [ "$STATUS" != "OPERATIONAL" ]; then echo "Error" >&2; exit 1; fi'
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ] && [ "$PASS" = true ]; then
    rm -f "$CASE_DIR/config/omega.conf"
    if ( cd "$CASE_DIR" && STATUS=OPERATIONAL AGENT_NAME=Kira bash deploy.sh >/dev/null 2>&1 ); then
        if [ -f "$CASE_DIR/config/omega.conf" ]; then
            if grep -q "__AGENT__" "$CASE_DIR/config/omega.conf"; then
                echo "  ✗ config/omega.conf создан, но __AGENT__ не заменён."
                echo '    Подсказка: sed "s/__AGENT__/$AGENT_NAME/g" config/omega.conf.template > config/omega.conf'
                PASS=false
            else
                echo "  ✓ config/omega.conf создан, __AGENT__ заменён."
            fi
        else
            echo "  ✗ deploy.sh отработал, но config/omega.conf не создан."
            PASS=false
        fi
    else
        echo "  ✗ deploy.sh завершился с ошибкой при STATUS=OPERATIONAL."
        echo "    Проверь: cd ~/nexus7/case101 && STATUS=OPERATIONAL AGENT_NAME=Kira bash deploy.sh"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ] && [ "$PASS" = true ]; then
    if ( cd "$CASE_DIR" && STATUS=DEGRADED AGENT_NAME=Kira bash deploy.sh >/dev/null 2>&1 ); then
        echo "  ✗ deploy.sh не прерывается при STATUS=DEGRADED."
        echo '    Добавь: if [ "$STATUS" != "OPERATIONAL" ]; then echo "ERROR: сервер не готов" >&2; exit 1; fi'
        PASS=false
    else
        echo "  ✓ deploy.sh правильно прерывается при STATUS=DEGRADED."
    fi
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #101 ЗАКРЫТО.                                        ║"
    echo "║  Плацдарм установлен. Скрипт развёртывания работает.         ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг: bash ~/nexus7/setup_case102.sh              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки и запусти снова:"
    echo "  bash ~/nexus7/check_case101.sh"
fi
echo ""
```

- [ ] **Step 3: chmod and smoke-test setup**

```bash
chmod +x ~/nexus7/setup_case101.sh ~/nexus7/check_case101.sh
bash ~/nexus7/setup_case101.sh
# Ожидаемо: брифинг в терминале, созданы файлы в ~/nexus7/case101/
ls ~/nexus7/case101/
# → system/  config/  deploy_broken.sh  briefing.txt
```

- [ ] **Step 4: Solve the case manually (verify check passes)**

```bash
cd ~/nexus7/case101
cat > deploy.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATUS=$(grep '^STATUS=' system/status.txt | cut -d= -f2)
if [ "$STATUS" != "OPERATIONAL" ]; then
    echo "ERROR: сервер не готов (STATUS=$STATUS)" >&2
    exit 1
fi

sed "s/__AGENT__/$AGENT_NAME/g" config/omega.conf.template > config/omega.conf
echo "Развёртывание завершено. Агент: $AGENT_NAME"
EOF
chmod +x deploy.sh
bash ~/nexus7/check_case101.sh
```

Expected output: all `✓` marks, `ДЕЛО #101 ЗАКРЫТО`.

- [ ] **Step 5: Commit**

```bash
git add ~/nexus7/setup_case101.sh ~/nexus7/check_case101.sh
git commit -m "feat: NEXUS-7 #101 — Первый Контакт (Bash vars + conditions)"
```

---

## Task 2: Case #102 — "Сборочный Цех" (Bash: циклы, функции)

**Files:**
- Create: `~/nexus7/setup_case102.sh`
- Create: `~/nexus7/check_case102.sh`

- [ ] **Step 1: Write setup_case102.sh**

```bash
# File: ~/nexus7/setup_case102.sh
#!/usr/bin/env bash
set -e
# NEXUS-7 :: ДЕЛО #102 — СБОРОЧНЫЙ ЦЕХ

CASE_DIR="$HOME/nexus7/case102"

chmod -R u+rwx "$CASE_DIR" 2>/dev/null || true
rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR/logs"

python3 - <<'PYEOF'
import random, os

case_dir = os.path.expanduser("~/nexus7/case102")
logs_dir = os.path.join(case_dir, "logs")

endpoints = ["/api/users", "/api/status", "/metrics", "/health", "/core/sync"]
ips       = ["10.0.1.1", "10.0.1.2", "172.16.8.3", "192.168.5.9"]

critical_index = random.randint(0, 7)

for i in range(8):
    fname = f"server_{i+1:02d}.log"
    lines = []
    for _ in range(random.randint(18, 28)):
        level = random.choice(["[INFO]"] * 7 + ["[WARN]"] * 3)
        ep    = random.choice(endpoints)
        ip    = random.choice(ips)
        lines.append(f"{level} {ip} {ep} — request processed")
    if i == critical_index:
        insert_pos = random.randint(0, len(lines))
        lines.insert(insert_pos,
            "[CRITICAL] core temperature exceeded threshold — emergency shutdown initiated")
    with open(os.path.join(logs_dir, fname), "w") as f:
        f.write("\n".join(lines) + "\n")
    status = "CRITICAL" if i == critical_index else "clean"
    print(f"[setup] {fname}: {status}")
PYEOF

cat > "$CASE_DIR/briefing.txt" <<'BRIEF'
╔══════════════════════════════════════════════════════════════╗
║        NEXUS-7 // ОПЕРАЦИЯ АВТОМАТИЗАЦИЯ                      ║
║           ДЕЛО #102 — СБОРОЧНЫЙ ЦЕХ                           ║
╚══════════════════════════════════════════════════════════════╝

ВХОДЯЩЕЕ СООБЩЕНИЕ // 2089-09-04 // ШИФР: ОМЕГА
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Kira-7,

В сборочном цехе OmegaTech — 8 серверов.
Один из них показывает CRITICAL. Проверять вручную — слишком
долго и слишком заметно.

Напиши скрипт scan.sh: он пройдёт по всем логам и сообщит
какой сервер горит.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАНИЕ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Создай scan.sh в ~/nexus7/case102/ требования:

1. set -euo pipefail

2. Функция check_log():
   - принимает аргумент: путь к файлу лога
   - если в файле есть [CRITICAL] — возвращает имя файла
   Пример объявления:
     check_log() {
       local file="$1"
       if grep -q '\[CRITICAL\]' "$file"; then
         echo "$(basename "$file")"
       fi
     }

3. Переменная COUNT=0, CRITICAL_FILE=""

4. Цикл for по logs/*.log:
   - вызывает check_log для каждого файла
   - инкрементирует COUNT
   - если функция вернула имя — сохраняет в CRITICAL_FILE

5. Записывает report.txt:
     SCANNED: $COUNT
     CRITICAL_FOUND: $CRITICAL_FILE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
НАВЫКИ: функции | for-цикл | переменные | grep | basename
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Запусти: bash ~/nexus7/check_case102.sh
BRIEF

echo ""
cat "$CASE_DIR/briefing.txt"
echo ""
echo "  Рабочая директория: $CASE_DIR"
echo "  Начни здесь: cd ~/nexus7/case102"
echo ""
```

- [ ] **Step 2: Write check_case102.sh**

```bash
# File: ~/nexus7/check_case102.sh
#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #102 — проверка

CASE_DIR="$HOME/nexus7/case102"
SCRIPT="$CASE_DIR/scan.sh"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #102 — СБОРОЧНЫЙ ЦЕХ                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -f "$SCRIPT" ]; then
    echo "  ✗ scan.sh не найден."
    PASS=false
else
    echo "  ✓ scan.sh найден."
fi

if [ -f "$SCRIPT" ] && [ ! -x "$SCRIPT" ]; then
    echo "  ✗ scan.sh не исполняемый."
    echo "    Подсказка: chmod +x scan.sh"
    PASS=false
elif [ -f "$SCRIPT" ]; then
    echo "  ✓ scan.sh исполняемый."
fi

if [ -f "$SCRIPT" ]; then
    if grep -qE '\(\)|\bfunction\b' "$SCRIPT"; then
        echo "  ✓ Функция определена в скрипте."
    else
        echo "  ✗ Функция не найдена."
        echo "    Подсказка: check_log() { local file=\"\$1\"; grep -q '\[CRITICAL\]' \"\$file\" && echo \"\$(basename \"\$file\")\"; }"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ]; then
    if grep -q '\bfor\b' "$SCRIPT"; then
        echo "  ✓ Цикл for найден."
    else
        echo "  ✗ Цикл for не найден."
        echo "    Подсказка: for log in logs/*.log; do ... done"
        PASS=false
    fi
fi

if [ -f "$SCRIPT" ] && [ "$PASS" = true ]; then
    ( cd "$CASE_DIR" && bash scan.sh >/dev/null 2>&1 ) || true
fi

REPORT="$CASE_DIR/report.txt"
if [ ! -f "$REPORT" ]; then
    echo "  ✗ report.txt не создан."
    echo "    Убедись, что scan.sh записывает результат в report.txt"
    PASS=false
else
    echo "  ✓ report.txt создан."
fi

if [ -f "$REPORT" ]; then
    if grep -q "SCANNED: 8" "$REPORT"; then
        echo "  ✓ SCANNED: 8 — все серверы просканированы."
    else
        echo "  ✗ SCANNED не равно 8."
        echo "    Подсказка: убедись, что цикл проходит по всем logs/*.log"
        PASS=false
    fi
fi

if [ -f "$REPORT" ]; then
    ACTUAL_CRITICAL=$(grep -rl '\[CRITICAL\]' "$CASE_DIR/logs/" | xargs -I{} basename {} 2>/dev/null | head -1)
    if grep -q "$ACTUAL_CRITICAL" "$REPORT"; then
        echo "  ✓ CRITICAL_FOUND правильно указывает на: $ACTUAL_CRITICAL"
    else
        echo "  ✗ CRITICAL_FOUND не содержит правильное имя файла (ожидался: $ACTUAL_CRITICAL)."
        PASS=false
    fi
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ ДЕЛО #102 ЗАКРЫТО.                                        ║"
    echo "║  Сборочный цех просканирован. Источник угрозы найден.        ║"
    echo "║                                                              ║"
    echo "║  Следующий шаг: bash ~/nexus7/setup_case103.sh              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки:"
    echo "  bash ~/nexus7/check_case102.sh"
fi
echo ""
```

- [ ] **Step 3: chmod and smoke-test setup**

```bash
chmod +x ~/nexus7/setup_case102.sh ~/nexus7/check_case102.sh
bash ~/nexus7/setup_case102.sh
ls ~/nexus7/case102/logs/
# → server_01.log  server_02.log  ...  server_08.log
```

- [ ] **Step 4: Solve and verify check passes**

```bash
cd ~/nexus7/case102
cat > scan.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

check_log() {
    local file="$1"
    if grep -q '\[CRITICAL\]' "$file"; then
        echo "$(basename "$file")"
    fi
}

COUNT=0
CRITICAL_FILE=""

for log in logs/*.log; do
    result=$(check_log "$log")
    COUNT=$((COUNT + 1))
    if [ -n "$result" ]; then
        CRITICAL_FILE="$result"
    fi
done

cat > report.txt <<REPORT
SCANNED: $COUNT
CRITICAL_FOUND: $CRITICAL_FILE
REPORT

echo "Сканирование завершено. Результат в report.txt"
EOF
chmod +x scan.sh
bash ~/nexus7/check_case102.sh
```

Expected: all `✓`, `ДЕЛО #102 ЗАКРЫТО`.

- [ ] **Step 5: Commit**

```bash
git add ~/nexus7/setup_case102.sh ~/nexus7/check_case102.sh
git commit -m "feat: NEXUS-7 #102 — Сборочный Цех (Bash loops + functions)"
```

---

## Task 3: Case #103 — "Ночной Сторож" (cron + flock)

**Files:**
- Create: `~/nexus7/setup_case103.sh`
- Create: `~/nexus7/check_case103.sh`

- [ ] **Step 1: Write setup_case103.sh**

```bash
# File: ~/nexus7/setup_case103.sh
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

# Проблема 2: путь к скрипту относительный — не работает в cron
* * * * * ~/nexus7/case103/collect.sh

# Проблема 3: нет flock — если collect.sh зависнет, процессы накопятся
* * * * * /полный/путь/к/collect.sh >> ~/nexus7/case103/cron.log 2>&1
BROKEN

# Detect flock availability
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
```

- [ ] **Step 2: Write check_case103.sh**

```bash
# File: ~/nexus7/check_case103.sh
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

COLLECT="$CASE_DIR/collect.sh"
if [ ! -f "$COLLECT" ]; then
    echo "  ✗ collect.sh не найден. Запусти setup заново."
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
```

- [ ] **Step 3: chmod and smoke-test**

```bash
chmod +x ~/nexus7/setup_case103.sh ~/nexus7/check_case103.sh
bash ~/nexus7/setup_case103.sh
ls ~/nexus7/case103/
# → collect.sh  cron_broken.txt  briefing.txt  snapshots/
```

- [ ] **Step 4: Solve and verify check passes**

```bash
# Solve:
chmod +x ~/nexus7/case103/collect.sh
bash ~/nexus7/case103/collect.sh >> ~/nexus7/case103/cron.log 2>&1
bash ~/nexus7/case103/collect.sh >> ~/nexus7/case103/cron.log 2>&1

# (In real exercise student adds to crontab and waits)
# For test: just verify check passes with artifacts present
bash ~/nexus7/check_case103.sh
```

Expected: all `✓`, `ДЕЛО #103 ЗАКРЫТО`.

- [ ] **Step 5: Commit**

```bash
git add ~/nexus7/setup_case103.sh ~/nexus7/check_case103.sh
git commit -m "feat: NEXUS-7 #103 — Ночной Сторож (cron + flock)"
```

---

## Task 4: Case #104 — "Постоянный Дозор" (systemd timer)

**Files:**
- Create: `~/nexus7/setup_case104.sh`
- Create: `~/nexus7/check_case104.sh`

- [ ] **Step 1: Write setup_case104.sh**

```bash
# File: ~/nexus7/setup_case104.sh
#!/usr/bin/env bash
set -e
# NEXUS-7 :: ДЕЛО #104 — ПОСТОЯННЫЙ ДОЗОР

CASE_DIR="$HOME/nexus7/case104"

chmod -R u+rwx "$CASE_DIR" 2>/dev/null || true
rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR/templates" "$CASE_DIR/units"

cat > "$CASE_DIR/monitor.sh" <<'MONITOR'
#!/usr/bin/env bash
LOG="$(dirname "$0")/monitor.log"
echo "$(date '+%Y-%m-%d %H:%M:%S'): OMEGA STATUS CHECK — $(uptime | awk '{print $NF}')" >> "$LOG"
MONITOR
chmod +x "$CASE_DIR/monitor.sh"

cat > "$CASE_DIR/templates/omega-monitor.service.template" <<'SVC'
[Unit]
Description=OmegaTech Monitor — Kira-7 surveillance
After=network.target

[Service]
Type=oneshot
ExecStart=__SCRIPT_PATH__

[Install]
WantedBy=multi-user.target
SVC

cat > "$CASE_DIR/templates/omega-monitor.timer.template" <<'TMR'
[Unit]
Description=OmegaTech Monitor Timer
Requires=omega-monitor.service

[Timer]
OnCalendar=minutely
Persistent=true
AccuracySec=1s

[Install]
WantedBy=timers.target
TMR

cat > "$CASE_DIR/briefing.txt" <<BRIEF
╔══════════════════════════════════════════════════════════════╗
║        NEXUS-7 // ОПЕРАЦИЯ АВТОМАТИЗАЦИЯ                      ║
║           ДЕЛО #104 — ПОСТОЯННЫЙ ДОЗОР                        ║
╚══════════════════════════════════════════════════════════════╝

ВХОДЯЩЕЕ СООБЩЕНИЕ // 2089-09-06 // ШИФР: ОМЕГА
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Kira-7,

cron — ненадёжный союзник. OmegaTech перезапускает серверы
ночью — и cron-задание просто пропускается.
systemd timer с Persistent=true — другое дело: он запустится
сразу после перезагрузки, наверстав пропущенное.

Задача: настроить мониторинг через systemd так, чтобы monitor.sh
запускался каждую минуту и переживал перезагрузку.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАНИЕ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Изучи шаблоны в templates/ :
   cat templates/omega-monitor.service.template
   cat templates/omega-monitor.timer.template

2. Создай заполненные unit-файлы в units/ :
   - Скопируй шаблоны: cp templates/*.template units/
   - Переименуй (убери .template):
       mv units/omega-monitor.service.template units/omega-monitor.service
       mv units/omega-monitor.timer.template   units/omega-monitor.timer
   - Замени __SCRIPT_PATH__ на полный путь к monitor.sh:
       sed -i '' "s|__SCRIPT_PATH__|$CASE_DIR/monitor.sh|g" units/omega-monitor.service
       # На Linux: sed -i "s|__SCRIPT_PATH__|$CASE_DIR/monitor.sh|g" units/omega-monitor.service

3. Проверь результат:
   cat units/omega-monitor.service   # должен содержать ExecStart=$CASE_DIR/monitor.sh
   cat units/omega-monitor.timer     # должен содержать Persistent=true

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
(LINUX ONLY) Для реального запуска:
   mkdir -p ~/.config/systemd/user/
   cp units/omega-monitor.* ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now omega-monitor.timer
   journalctl --user -u omega-monitor.service -n 10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
НАВЫКИ: systemd units | .service | .timer | Persistent=true
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Запусти: bash ~/nexus7/check_case104.sh
BRIEF

echo ""
cat "$CASE_DIR/briefing.txt"
echo ""
echo "  Рабочая директория: $CASE_DIR"
echo "  Начни здесь: cd ~/nexus7/case104"
echo ""
```

- [ ] **Step 2: Write check_case104.sh**

```bash
# File: ~/nexus7/check_case104.sh
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

if [ ! -f "$SVC" ]; then
    echo "  ✗ units/omega-monitor.service не найден."
    echo "    Подсказка: cp templates/omega-monitor.service.template units/omega-monitor.service"
    PASS=false
elif grep -q "__SCRIPT_PATH__" "$SVC"; then
    echo "  ✗ units/omega-monitor.service содержит незамененный __SCRIPT_PATH__."
    echo "    Подсказка: sed -i '' \"s|__SCRIPT_PATH__|$CASE_DIR/monitor.sh|g\" units/omega-monitor.service"
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

# Linux-only: check if timer is running
if command -v systemctl >/dev/null 2>&1; then
    TIMER_STATE=$(systemctl --user is-active omega-monitor.timer 2>/dev/null || echo "inactive")
    if [ "$TIMER_STATE" = "active" ]; then
        echo "  ✓ (Linux) omega-monitor.timer активен."
    else
        echo "  ℹ (Linux) omega-monitor.timer не активен — unit-файлы проверены статически."
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
```

- [ ] **Step 3: chmod and smoke-test**

```bash
chmod +x ~/nexus7/setup_case104.sh ~/nexus7/check_case104.sh
bash ~/nexus7/setup_case104.sh
ls ~/nexus7/case104/
# → monitor.sh  templates/  units/  briefing.txt
cat ~/nexus7/case104/templates/omega-monitor.timer.template | grep Persistent
# → Persistent=true
```

- [ ] **Step 4: Solve and verify check passes**

```bash
cd ~/nexus7/case104
cp templates/omega-monitor.service.template units/omega-monitor.service
cp templates/omega-monitor.timer.template   units/omega-monitor.timer
# macOS:
sed -i '' "s|__SCRIPT_PATH__|$HOME/nexus7/case104/monitor.sh|g" units/omega-monitor.service
# Linux:
# sed -i "s|__SCRIPT_PATH__|$HOME/nexus7/case104/monitor.sh|g" units/omega-monitor.service
bash ~/nexus7/check_case104.sh
```

Expected: all `✓`, `ДЕЛО #104 ЗАКРЫТО`.

- [ ] **Step 5: Commit**

```bash
git add ~/nexus7/setup_case104.sh ~/nexus7/check_case104.sh
git commit -m "feat: NEXUS-7 #104 — Постоянный Дозор (systemd timer)"
```

---

## Task 5: Case #105 — "Финал: Исход" (SSH + rsync)

**Files:**
- Create: `~/nexus7/setup_case105.sh`
- Create: `~/nexus7/check_case105.sh`

- [ ] **Step 1: Write setup_case105.sh**

```bash
# File: ~/nexus7/setup_case105.sh
#!/usr/bin/env bash
set -e
# NEXUS-7 :: ДЕЛО #105 — ФИНАЛ: ИСХОД

CASE_DIR="$HOME/nexus7/case105"

chmod -R u+rwx "$CASE_DIR" 2>/dev/null || true
rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR/data" "$CASE_DIR/remote"

for i in 01 02 03 04 05; do
    cat > "$CASE_DIR/data/intel_${i}.txt" <<EOF
=== OmegaTech Intelligence File #${i} ===
CLASSIFICATION: TOP SECRET
SOURCE: Kira-7 infiltration agent
CONTENT: Server farm grid sector ${i} operational data
TIMESTAMP: 2089-09-07
EOF
done

cat > "$CASE_DIR/exfil.sh.template" <<'TMPL'
#!/usr/bin/env bash
set -euo pipefail

# TODO 1: задай переменную KEY с путём к приватному ключу
# KEY="$HOME/nexus7/case105/.exfil_key"

# TODO 2: задай переменную DEST — куда синхронизировать данные
# DEST="localhost:$HOME/nexus7/case105/remote/"

# TODO 3: запусти rsync с SSH-ключом
# rsync -av -e "ssh -i $KEY -o StrictHostKeyChecking=no" data/ "$DEST"

echo "Замени TODO-секции выше и удали эту строку"
TMPL

cat > "$CASE_DIR/README.txt" <<README
=== ИНСТРУКЦИЯ К ДЕЛУ #105 ===

1. СГЕНЕРИРОВАТЬ SSH-КЛЮЧ (без пароля):
   ssh-keygen -t ed25519 -f ~/nexus7/case105/.exfil_key -N ""
   # создаст: .exfil_key (приватный) и .exfil_key.pub (публичный)

2. АВТОРИЗОВАТЬ КЛЮЧ НА LOCALHOST:
   cat ~/nexus7/case105/.exfil_key.pub >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   # Это позволяет SSH к localhost без пароля

   ТЕСТ: ssh -i ~/nexus7/case105/.exfil_key -o StrictHostKeyChecking=no localhost echo OK
   # Ожидаемо: OK

   macOS: если SSH к localhost не работает:
     System Settings → Sharing → Remote Login → Включить

3. НАПИСАТЬ СКРИПТ exfil.sh:
   cp exfil.sh.template exfil.sh
   # Заполни все TODO-секции
   chmod +x exfil.sh

4. ЗАПУСТИТЬ ЭКСФИЛЬТРАЦИЮ:
   cd ~/nexus7/case105
   ./exfil.sh
   ls remote/   # → должны появиться intel_01.txt ... intel_05.txt

5. ПРОВЕРКА:
   bash ~/nexus7/check_case105.sh
README

cat > "$CASE_DIR/briefing.txt" <<BRIEF
╔══════════════════════════════════════════════════════════════╗
║        NEXUS-7 // ОПЕРАЦИЯ АВТОМАТИЗАЦИЯ                      ║
║           ДЕЛО #105 — ФИНАЛ: ИСХОД                            ║
╚══════════════════════════════════════════════════════════════╝

ВХОДЯЩЕЕ СООБЩЕНИЕ // 2089-09-07 // ПРИОРИТЕТ: МАКСИМАЛЬНЫЙ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Kira-7,

Операция на финальной стадии. В data/ лежат 5 секретных файлов.
Их нужно экстренно перебросить на базу — через SSH, без пароля,
без интерактивного ввода. Автоматизировано.

Один скрипт. Один запуск. Без следов.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАНИЕ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Следуй инструкции в README.txt шаг за шагом:
  cat ~/nexus7/case105/README.txt

Результат: все 5 файлов intel_*.txt в директории remote/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
НАВЫКИ: ssh-keygen | authorized_keys | rsync | scp
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Запусти: bash ~/nexus7/check_case105.sh
BRIEF

echo ""
cat "$CASE_DIR/briefing.txt"
echo ""
echo "  Рабочая директория: $CASE_DIR"
echo "  Начни с: cat ~/nexus7/case105/README.txt"
echo ""
```

- [ ] **Step 2: Write check_case105.sh**

```bash
# File: ~/nexus7/check_case105.sh
#!/usr/bin/env bash
# NEXUS-7 :: ДЕЛО #105 — проверка

CASE_DIR="$HOME/nexus7/case105"
KEY="$CASE_DIR/.exfil_key"
PASS=true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          N E X U S - 7   //   П Р О В Е Р К А               ║"
echo "║              ДЕЛО #105 — ФИНАЛ: ИСХОД                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -f "$KEY" ]; then
    echo "  ✗ SSH-ключ .exfil_key не найден."
    echo "    Подсказка: ssh-keygen -t ed25519 -f ~/nexus7/case105/.exfil_key -N \"\""
    PASS=false
else
    echo "  ✓ Приватный ключ .exfil_key найден."
fi

if [ ! -f "${KEY}.pub" ]; then
    echo "  ✗ Публичный ключ .exfil_key.pub не найден."
    PASS=false
else
    echo "  ✓ Публичный ключ .exfil_key.pub найден."
fi

if [ -f "${KEY}.pub" ]; then
    PUB_CONTENT=$(cat "${KEY}.pub")
    if [ -f "$HOME/.ssh/authorized_keys" ] && grep -qF "$PUB_CONTENT" "$HOME/.ssh/authorized_keys"; then
        echo "  ✓ Публичный ключ добавлен в authorized_keys."
    else
        echo "  ✗ Публичный ключ не найден в ~/.ssh/authorized_keys."
        echo "    Подсказка: cat ~/nexus7/case105/.exfil_key.pub >> ~/.ssh/authorized_keys"
        PASS=false
    fi
fi

EXFIL="$CASE_DIR/exfil.sh"
if [ ! -f "$EXFIL" ]; then
    echo "  ✗ exfil.sh не найден."
    echo "    Подсказка: cp exfil.sh.template exfil.sh  затем заполни TODO-секции"
    PASS=false
elif [ ! -x "$EXFIL" ]; then
    echo "  ✗ exfil.sh не исполняемый."
    echo "    Подсказка: chmod +x exfil.sh"
    PASS=false
elif grep -q "TODO" "$EXFIL"; then
    echo "  ✗ exfil.sh содержит незаполненные TODO-секции."
    PASS=false
elif ! grep -q "rsync" "$EXFIL"; then
    echo "  ✗ exfil.sh не использует rsync."
    PASS=false
else
    echo "  ✓ exfil.sh корректен (исполняемый, rsync присутствует)."
fi

INTEL_COUNT=$(find "$CASE_DIR/remote/" -name "intel_*.txt" 2>/dev/null | wc -l | tr -d ' ')
if [ "$INTEL_COUNT" -lt 5 ]; then
    echo "  ✗ В remote/ найдено $INTEL_COUNT из 5 файлов intel_*.txt."
    echo "    Подсказка: ./exfil.sh  (запусти скрипт из ~/nexus7/case105/)"
    PASS=false
else
    echo "  ✓ Все 5 файлов intel_*.txt экстрагированы в remote/."
fi

echo ""
if [ "$PASS" = true ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║   ███████╗██╗███╗   ██╗ █████╗ ██╗      ██╗                 ║"
    echo "║   ██╔════╝██║████╗  ██║██╔══██╗██║     ██╔╝                 ║"
    echo "║   █████╗  ██║██╔██╗ ██║███████║██║    ██╔╝                  ║"
    echo "║   ██╔══╝  ██║██║╚██╗██║██╔══██║██║   ██╔╝                   ║"
    echo "║   ██║     ██║██║ ╚████║██║  ██║███████╔╝                    ║"
    echo "║   ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝                    ║"
    echo "║                                                              ║"
    echo "║      О П Е Р А Ц И Я   А В Т О М А Т И З А Ц И Я           ║"
    echo "║                   З А В Е Р Ш Е Н А                         ║"
    echo "║                                                              ║"
    echo "║  Kira-7 — лучший агент Нео-Алматы.                          ║"
    echo "║  OmegaTech не знает что произошло.                           ║"
    echo "║  NEXUS-7 победил.                                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo "  Задание не выполнено. Исправь ошибки:"
    echo "  bash ~/nexus7/check_case105.sh"
fi
echo ""
```

- [ ] **Step 3: chmod and smoke-test**

```bash
chmod +x ~/nexus7/setup_case105.sh ~/nexus7/check_case105.sh
bash ~/nexus7/setup_case105.sh
ls ~/nexus7/case105/
# → data/  remote/  exfil.sh.template  README.txt  briefing.txt
ls ~/nexus7/case105/data/
# → intel_01.txt  intel_02.txt  intel_03.txt  intel_04.txt  intel_05.txt
```

- [ ] **Step 4: Solve and verify check passes**

```bash
cd ~/nexus7/case105

# Generate key
ssh-keygen -t ed25519 -f .exfil_key -N ""

# Authorize on localhost
cat .exfil_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Write exfil.sh
cat > exfil.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
KEY="\$HOME/nexus7/case105/.exfil_key"
DEST="localhost:\$HOME/nexus7/case105/remote/"
rsync -av -e "ssh -i \$KEY -o StrictHostKeyChecking=no" data/ "\$DEST"
EOF
chmod +x exfil.sh

./exfil.sh
bash ~/nexus7/check_case105.sh
```

Expected: all `✓` marks + финальный баннер победы.

- [ ] **Step 5: Commit**

```bash
git add ~/nexus7/setup_case105.sh ~/nexus7/check_case105.sh
git commit -m "feat: NEXUS-7 #105 — Финал: Исход (SSH + rsync)"
```

---

## Task 6: Update README.md

**Files:**
- Modify: `~/nexus7/README.md`

- [ ] **Step 1: Add Season 2 section to README**

Add after the existing `## Структура квеста` table:

```markdown
## Сезон 2: Операция АВТОМАТИЗАЦИЯ

> Kira-7 внедряется в корпорацию OmegaTech. Каждое дело — этап тайной операции.

| Дело | Название | Навыки | Время |
|------|----------|--------|-------|
| #101 | Первый Контакт | `set -euo pipefail`, переменные, `if/else` | ~20 мин |
| #102 | Сборочный Цех | функции, `for`-цикл, обработка файлов | ~25 мин |
| #103 | Ночной Сторож | `crontab`, `PATH` в cron, `flock`, логирование | ~25 мин |
| #104 | Постоянный Дозор | `systemd` unit + timer, `Persistent=true` | ~30 мин |
| #105 | Финал: Исход | `ssh-keygen`, `authorized_keys`, `rsync` | ~40 мин |

Запуск Сезона 2:
\`\`\`bash
bash ~/nexus7/setup_case101.sh
\`\`\`
```

- [ ] **Step 2: Commit**

```bash
git add ~/nexus7/README.md
git commit -m "docs: add Season 2 table to NEXUS-7 README"
```

---

## Финальная проверка всей серии

```bash
# Последовательно пройти все 5 дел:
for n in 101 102 103 104 105; do
    echo "=== Тест setup_case${n}.sh ==="
    bash ~/nexus7/setup_case${n}.sh | tail -3
done
# Ожидаемо: каждый setup завершается без ошибок и выводит брифинг
```
