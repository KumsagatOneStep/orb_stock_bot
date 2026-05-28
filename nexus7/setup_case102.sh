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
