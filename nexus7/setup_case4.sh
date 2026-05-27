#!/bin/bash
set -e

BASE="$HOME/nexus7/case4"

# Clean and recreate case4 directory structure
rm -rf "$BASE"
mkdir -p "$BASE/data"
mkdir -p "$BASE/cron.d"

# Create data files
cat > "$BASE/data/report_2089-03-14.dat" << 'EOF'
NEXUS Trade Report — 2089-03-14
EOF

cat > "$BASE/data/report_2089-03-15.dat" << 'EOF'
NEXUS Trade Report — 2089-03-15
EOF

cat > "$BASE/data/backup_2089-03-15.tar" << 'EOF'
ARCHIVE_2089-03-15
EOF

# Update timestamps so find -mtime -1 will find them
touch "$BASE/data/report_2089-03-15.dat"
touch "$BASE/cron.d"

# Create the simulated cron file with dangerous lines
cat > "$BASE/cron.d/nexus-maintenance" << 'EOF'
# NexusTech Automated Maintenance Schedule
# Last modified: 2089-03-15 03:00:01 by maintenance-bot v3.1
#
# System cleanup — safe operations
0 2 * * * find /tmp -name "*.tmp" -delete

# DATA WIPE — ночная очистка (ОПАСНО)
0 3 * * * rm -rf ~/nexus7/case4/data/*.dat
15 3 * * * find ~/nexus7/case4/data -name "*.tar" -delete
EOF

# Create briefing
cat > "$BASE/briefing.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║         NEXUS-7 // ДЕЛО #004 — НОЧНОЙ ТАЙМЕР                    ║
╚══════════════════════════════════════════════════════════════════╝

СТАТУС СИСТЕМЫ: ТРЕВОГА
ВРЕМЯ: 2089-03-16 06:17:44
ОПЕРАТОР: [ТЫ]

──────────────────────────────────────────────────────────────────
СВОДКА
──────────────────────────────────────────────────────────────────
Третье утро подряд торговые отчёты Нексуса исчезают без следа.
Архивы данных за 2089-03-14 и 2089-03-15 — испарились.
Финансовый отдел в панике. Совет требует объяснений.

Ты — единственный, кто ещё не спит. Найди таймер. Останови его.

──────────────────────────────────────────────────────────────────
ТВОИ ЗАДАЧИ
──────────────────────────────────────────────────────────────────
1. Найди файлы, изменённые за последние сутки:
     find . -mtime -1

2. Прочитай файл расписания технического обслуживания:
     cat cron.d/nexus-maintenance

3. Найди и закомментируй опасные строки (добавь # в начало).
   Можно вручную через nano:
     nano cron.d/nexus-maintenance

   Или одной командой через sed:
     sed -i '' 's/^0 3 \* \* \* rm/# 0 3 * * * rm/' cron.d/nexus-maintenance
     sed -i '' 's/^15 3 \* \* \* find/# 15 3 * * * find/' cron.d/nexus-maintenance

──────────────────────────────────────────────────────────────────
ПОДСКАЗКИ
──────────────────────────────────────────────────────────────────
• find -mtime -1 показывает файлы, изменённые менее 24 часов назад
• Строки в cron-файле, начинающиеся с #, считаются комментариями
  и НЕ выполняются — это безопасный способ отключить задачу
• Смотри внимательно: не все строки в cron.d/nexus-maintenance безобидны

──────────────────────────────────────────────────────────────────
ПРОВЕРКА
──────────────────────────────────────────────────────────────────
Когда готово — запусти: bash ~/nexus7/check_case4.sh

Нексус не забудет этого, оператор.
EOF

echo "✓ Дело #004 подготовлено. Читай briefing.txt и начинай расследование."
echo "  cd ~/nexus7/case4 && cat briefing.txt"
