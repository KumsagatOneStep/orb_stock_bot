# NEXUS-7 Season 2 — «Операция АВТОМАТИЗАЦИЯ» (#101–#105)

## Нарратив

**2089 год. Нео-Алматы.** Мегакорпорация **OmegaTech** скупает конкурентов силой и саботажем.
NexusTech нанимает Kira-7 для тайной операции: внедриться в инфраструктуру OmegaTech,
автоматизировать сбор разведданных и выйти незамеченной.

Каждое дело — этап операции. Кира пишет Bash-скрипты, настраивает cron/systemd и синхронизирует
данные через SSH — в конце поднимает всё вместе для финальной эксфильтрации.

---

## Структура сезона

| Дело | Название | Навыки | Время |
|------|----------|--------|-------|
| #101 | Первый Контакт | Bash: переменные, `if/else`, `set -euo pipefail`, exit-коды | ~20 мин |
| #102 | Сборочный Цех | Bash: `for`/`while`, функции, обработка файлов в цикле | ~25 мин |
| #103 | Ночной Сторож | `cron`, `PATH` в cron, `flock`, логирование cron-задач | ~25 мин |
| #104 | Постоянный Дозор | `systemd` unit + timer, `Persistent=true`, `journalctl` | ~30 мин |
| #105 | Финал: Исход | `ssh-keygen`, `authorized_keys`, `rsync`, `scp` | ~40 мин |

---

## Дело #101 — «Первый Контакт»

### Нарратив
Kira-7 взламывает первый сервер OmegaTech. Чтобы не оставлять следов, нужен
`deploy.sh` — скрипт, который проверяет окружение перед запуском и падает с понятной
ошибкой, а не разрушает боевую систему.

### Среда (`setup_case101.sh`)
Создаёт `~/nexus7/case101/`:
- `system/status.txt` — содержит `STATUS=DEGRADED` (ненормально) или `STATUS=OPERATIONAL`
- `config/omega.conf.template` — шаблон конфига с плейсхолдером `__AGENT__`
- `deploy_broken.sh` — скрипт без `set -e`, с отсутствующей переменной, без проверок
  (намеренно сломан — студент изучает его и пишет правильный)

### Задание
1. Изучить `deploy_broken.sh` — найти проблемы
2. Создать `deploy.sh` в `~/nexus7/case101/` с требованиями:
   - Первая строка: `set -euo pipefail`
   - Переменная `AGENT_NAME` (любое значение, не пустая)
   - Проверка `if [ "$STATUS" != "OPERATIONAL" ]` → `exit 1` с сообщением об ошибке
   - При успехе — копировать шаблон в `config/omega.conf`, заменив `__AGENT__` на `$AGENT_NAME`

### Проверка (`check_case101.sh`)
- `deploy.sh` существует и исполняемый (`chmod +x`)
- Содержит `set -euo pipefail`
- Содержит непустую переменную `AGENT_NAME`
- Содержит конструкцию `if` с проверкой `STATUS`
- После запуска `STATUS=OPERATIONAL bash deploy.sh` — файл `config/omega.conf` существует
  и не содержит `__AGENT__`

---

## Дело #102 — «Сборочный Цех»

### Нарратив
В дата-центре OmegaTech 8 серверных логов. Каждый нужно проверить на аномалии и
создать сводный отчёт. Вручную — слишком долго и заметно. Нужен скрипт с циклом.

### Среда (`setup_case102.sh`)
Создаёт `~/nexus7/case102/logs/` с 8 файлами `server_01.log` … `server_08.log`:
- Каждый содержит ~20 строк `[INFO]`, случайные `[WARN]`, а в одном (случайном) — строка `[CRITICAL]`

### Задание
1. Написать скрипт `scan.sh`:
   - `set -euo pipefail`
   - Функция `check_log <file>` — грепает `[CRITICAL]` и выводит имя файла если найдено
   - Цикл `for` по всем `logs/*.log` — вызывает функцию
   - Записывает результат в `report.txt` в формате:
     ```
     SCANNED: 8
     CRITICAL_FOUND: <имя файла>
     ```

### Проверка (`check_case102.sh`)
- `scan.sh` существует и исполняемый
- Содержит `function` или `()` (определение функции)
- Содержит цикл `for`
- `report.txt` существует
- `report.txt` содержит `SCANNED: 8`
- `report.txt` содержит имя файла, в котором реально есть `[CRITICAL]`

---

## Дело #103 — «Ночной Сторож»

### Нарратив
Нужно посадить «жучка» — cron-задание, которое каждую минуту собирает снапшот
процессов OmegaTech в файл. Но если предыдущий запуск ещё не завершился, второй
запуск не должен накладываться (иначе файл будет испорчен).

### Среда (`setup_case103.sh`)
Создаёт `~/nexus7/case103/`:
- `collect.sh` — рабочий скрипт сбора данных (уже написан): записывает `date` и `uptime`
  в `~/nexus7/case103/snapshots/snap_$(date +%s).txt`
- `cron_broken.txt` — неправильный crontab: путь к скрипту без `$HOME`, нет `flock`
- `README.md` — инструкция: объяснение PATH в cron, синтаксис flock

### Задание
1. Сделать `collect.sh` исполняемым
2. Добавить в `crontab -e` запись:
   ```
   * * * * * /usr/bin/flock -n /tmp/omega-collect.lock /полный/путь/до/collect.sh >> ~/nexus7/case103/cron.log 2>&1
   ```
3. Подождать ~1 минуту
4. Убедиться, что `cron.log` и хотя бы один `snapshots/snap_*.txt` существуют
5. Удалить запись из crontab (операция секретная — следов не оставлять)

### Проверка (`check_case103.sh`)
- `collect.sh` исполняемый
- Директория `snapshots/` существует
- Хотя бы 1 файл `snapshots/snap_*.txt` существует
- `cron.log` существует и не пустой
- Активной записи в `crontab -l` с `collect.sh` **нет** (убрал после теста)

---

## Дело #104 — «Постоянный Дозор»

### Нарратив
cron не надёжен — если сервер перезагрузится в момент запуска задачи, она пропустится.
OmegaTech перезапускает серверы каждую ночь. Нужен systemd timer с `Persistent=true`.

### Среда (`setup_case104.sh`)
Создаёт `~/nexus7/case104/`:
- `monitor.sh` — скрипт мониторинга: пишет `$(date): OMEGA STATUS CHECK` в `monitor.log`
- `templates/omega-monitor.service.template` — шаблон .service с плейсхолдером `__SCRIPT_PATH__`
- `templates/omega-monitor.timer.template` — шаблон .timer с `OnCalendar=minutely` и `Persistent=true`
- `README.md` — инструкция по systemd units

### Задание
> **Примечание:** Дело #104 полностью функционально только на Linux с systemd.
> На macOS скрипты создают и валидируют unit-файлы — реальный запуск таймера требует Linux.

1. Заменить `__SCRIPT_PATH__` в шаблонах на реальный путь к `monitor.sh`
2. Сохранить заполненные файлы в `~/nexus7/case104/units/`
3. Убедиться что `.service` содержит `ExecStart=` с правильным путём
4. Убедиться что `.timer` содержит `Persistent=true` и `OnCalendar=minutely`
5. (Linux) Скопировать в `~/.config/systemd/user/`, запустить `systemctl --user enable --now omega-monitor.timer`

### Проверка (`check_case104.sh`)
- `~/nexus7/case104/units/omega-monitor.service` существует, не содержит `__SCRIPT_PATH__`
- `~/nexus7/case104/units/omega-monitor.timer` существует, содержит `Persistent=true`
- `.timer` содержит `OnCalendar=minutely`
- `.service` содержит `ExecStart=` с путём к `monitor.sh`
- (Linux) если `systemctl` доступен: `systemctl --user is-active omega-monitor.timer` → `active`

---

## Дело #105 — «Финал: Исход»

### Нарратив
Операция завершена. Нужно эксфильтровать данные на сервер NexusTech.
Без пароля, без интерактива — только SSH-ключи и rsync.
Но «сервер NexusTech» — это localhost с другим пользователем (симуляция).

### Среда (`setup_case105.sh`)
Создаёт `~/nexus7/case105/`:
- `data/` — 5 файлов с "разведданными" (`intel_01.txt` … `intel_05.txt`)
- `remote/` — папка назначения (симулирует удалённый сервер через `rsync` в локальный путь)
- `exfil.sh.template` — шаблон скрипта с `TODO`-секциями
- `README.md` — инструкция по `ssh-keygen`, `authorized_keys`, `rsync`

### Задание
> **macOS**: перед делом включить Remote Login: `System Settings → Sharing → Remote Login: ON`
> Либо проверить командой: `ssh localhost echo ok`. Если не работает — следовать инструкции в README.

1. Сгенерировать SSH-ключ (`ssh-keygen -t ed25519 -f ~/nexus7/case105/.exfil_key -N ""`)
2. Добавить публичный ключ в `~/.ssh/authorized_keys`
3. Написать скрипт `exfil.sh`:
   - `set -euo pipefail`
   - Переменная `KEY=~/nexus7/case105/.exfil_key`
   - `rsync -av -e "ssh -i $KEY -o StrictHostKeyChecking=no" data/ localhost:~/nexus7/case105/remote/`
4. Запустить скрипт

### Проверка (`check_case105.sh`)
- `~/nexus7/case105/.exfil_key` существует (приватный ключ)
- `~/nexus7/case105/.exfil_key.pub` существует
- Публичный ключ присутствует в `~/.ssh/authorized_keys`
- `exfil.sh` существует, исполняемый, содержит `rsync`
- Все 5 файлов `intel_*.txt` присутствуют в `remote/`
- Победное сообщение: «Операция АВТОМАТИЗАЦИЯ завершена. NEXUS-7 победил.»

---

## Файловая структура

```
~/nexus7/
├── README.md                     # обновить — добавить Season 2
├── setup_case101.sh
├── check_case101.sh
├── setup_case102.sh
├── check_case102.sh
├── setup_case103.sh
├── check_case103.sh
├── setup_case104.sh
├── check_case104.sh
├── setup_case105.sh
├── check_case105.sh
├── case101/                      # создаётся setup
├── case102/
├── case103/
├── case104/
└── case105/
```

---

## Совместимость

Все скрипты должны работать на macOS и Linux.
- `stat` — двойная поддержка (`stat -f %OLp` / `stat -c %a`)
- `systemd user units` — дело #104 требует systemd; на macOS добавить предупреждение
- `flock` — на macOS требует `brew install util-linux`; setup выводит предупреждение если недоступен
