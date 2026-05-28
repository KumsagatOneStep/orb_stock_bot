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

cat > "$CASE_DIR/briefing.txt" <<'BRIEF'
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
