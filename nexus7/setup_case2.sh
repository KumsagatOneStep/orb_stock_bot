#!/usr/bin/env bash
set -e

CASE_DIR="$HOME/nexus7/case2"

# ── Пересоздать директорию ──────────────────────────────────────────────────
rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR/logs"

# ── Генерация access.log ────────────────────────────────────────────────────
python3 - <<'PYEOF'
import random
import os

case_dir = os.path.expanduser("~/nexus7/case2")
log_path = os.path.join(case_dir, "logs", "access.log")

ips       = ["10.0.0.1", "10.0.0.2", "10.0.0.5", "172.16.0.3", "192.168.1.10"]
endpoints = ["/api/status", "/nexus/health", "/api/users", "/api/metrics", "/ui/dashboard"]
methods   = ["GET", "POST"]

lines = []

# ~100 нормальных записей, временной диапазон 08:00:00–23:59:59
for _ in range(100):
    h  = random.randint(8, 23)
    m  = random.randint(0, 59)
    s  = random.randint(0, 59)
    ts = f"2089-03-15 {h:02d}:{m:02d}:{s:02d}"
    ip = random.choice(ips)
    method   = random.choice(methods)
    endpoint = random.choice(endpoints)
    lines.append(f"[{ts}] {ip} {method} {endpoint} 200")

# Вредоносная запись
lines.append("[2089-03-15 03:47:22] 192.168.77.13 DELETE /nexus/core 403")

# Сортировка по временной метке (первые 20 символов — дата+время)
lines.sort(key=lambda l: l[1:20])

with open(log_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"[setup] access.log создан: {len(lines)} строк")
PYEOF

# ── Создать briefing.txt ────────────────────────────────────────────────────
cat > "$CASE_DIR/briefing.txt" <<'BRIEF'
╔══════════════════════════════════════════════════════════════╗
║              NEXUS-7 // ДЕЛО #002 — ЭХО В ЛОГАХ             ║
╚══════════════════════════════════════════════════════════════╝

ВХОДЯЩЕЕ СООБЩЕНИЕ // 2089-03-15 // ПРИОРИТЕТ: КРИТИЧЕСКИЙ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Оперативник,

Ночью кто-то попытался УДАЛИТЬ ядро NEXUS.
Система заблокировала атаку кодом 403 — но злоумышленник
уже знает адрес. Следующая попытка может быть успешной.

Тебе нужно поднять IP-адрес атакующего и точное время удара.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАНИЕ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Найди в логах запрос DELETE /nexus/core (файл: logs/access.log)
2. Создай файл answer.txt в ~/nexus7/case2/ с двумя строками:

   IP: <адрес атакующего>
   TIME: <HH:MM:SS>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ПОДСКАЗКИ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  # Найти строку с DELETE:
  grep "DELETE" logs/access.log

  # Найти строку с кодом 403:
  grep "403" logs/access.log

  # Извлечь IP и время:
  grep "DELETE" logs/access.log | awk '{print $3}'   # IP адрес
  grep "DELETE" logs/access.log | awk '{print $2}' | tr -d ']'  # время

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Когда готово — запусти: bash ~/nexus7/check_case2.sh

╚══════════════════════════════════════════════════════════════╝
BRIEF

echo "[setup] Дело 2 готово. Читай: $CASE_DIR/briefing.txt"
