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
   - Скопируй шаблоны:
       cp templates/omega-monitor.service.template units/omega-monitor.service
       cp templates/omega-monitor.timer.template   units/omega-monitor.timer
   - Замени __SCRIPT_PATH__ на полный путь к monitor.sh:
   macOS:
       sed -i '' "s|__SCRIPT_PATH__|$CASE_DIR/monitor.sh|g" units/omega-monitor.service
   Linux:
       sed -i "s|__SCRIPT_PATH__|$CASE_DIR/monitor.sh|g" units/omega-monitor.service

3. Проверь результат:
   cat units/omega-monitor.service   # → ExecStart=$CASE_DIR/monitor.sh
   cat units/omega-monitor.timer     # → Persistent=true

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
