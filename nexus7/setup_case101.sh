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
