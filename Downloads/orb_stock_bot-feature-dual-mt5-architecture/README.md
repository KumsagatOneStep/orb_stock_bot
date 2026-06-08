# TSLA ORB EA — v1.9

Expert Advisor для MetaTrader 5 на основе стратегии **Opening Range Breakout (ORB)** по акции TSLA.  
Брокер: **Capital.com MT5 · Hedging · ContractSize = 1 акция**.

---

## Стратегия

Бот торгует пробой уровней последней 5-минутной свечи премаркета.

| Этап | Время ET | Время сервера лето (UTC+0) | Время сервера зима (UTC+0) |
|---|---|---|---|
| Формирование ORB-свечи | 09:25 – 09:30 | 13:25 – 13:30 | 14:25 – 14:30 |
| Фиксация уровней HIGH / LOW | 09:30:00 | 13:30:00 | 14:30:00 |
| Окно входа | 09:30 – 10:00 | 13:30 – 14:00 | 14:30 – 15:00 |
| Принудительное закрытие EOD | 15:50 ET | 19:50 UTC | 20:50 UTC |

**Логика входа (двухступенчатая A→B):**

1. **LEVEL A** — цена касается уровня ORB (Ask ≥ PRE_HIGH или Bid ≤ PRE_LOW)
2. **LEVEL B** — цена возвращается и пробивает уровень с отступом `EntryOffset`

```
LONG:   Ask ≥ PRE_HIGH + EntryOffset
SHORT:  Bid ≤ PRE_LOW  − EntryOffset
```

- Одна сделка в день. После открытия — блокировка до следующего дня.
- Gap-фильтр: если на первом тике окна оба уровня пробиты одновременно — торговля отключается.
- Спайк-фильтр: если спред > `SpikeFilterThreshold` — тик пропускается.

---

## Архитектура

### Файлы EA

```
TSLA_ORB_v1.mq5   — главный файл (OnInit / OnTick / OnTimer / OnTradeTransaction)
├── Logger.mqh    — логирование и уведомления (Push / Telegram / Email / Sound)
├── Levels.mqh    — фиксация ORB-уровней, расчёт лота, машина состояний
├── Risk.mqh      — дневной лимит, просадка, месячный стоп-уровень
├── Entry.mqh     — логика входа, отправка ордера с retry
├── Position.mqh  — Breakeven, EOD-закрытие, детектор закрытия SL/TP
└── FileManager.mqh — чтение/запись orb_levels.txt (для Dual-MT5 режима)

EA_DataReader.mq5 — опциональный ридер данных Exness (Dual-MT5 режим)
```

### Dual-MT5 режим (опционально)

В стандартном режиме (`UseExternalLevels = false`) TSLA_ORB читает свечу M5 напрямую из Capital.com — этого достаточно для работы.

Dual-MT5 режим нужен если Capital.com не даёт надёжной истории M5 в момент 09:30 ET: тогда EA_DataReader запускается на отдельном MT5 (Exness) и пишет уровни в общий файл.

```
Exness MT5                              Capital.com MT5
EA_DataReader.mq5  ──► orb_levels.txt ──► TSLA_ORB_v1.mq5
(читает M5 свечу)       FILE_COMMON        (UseExternalLevels=true)
```

**Настройка Dual-MT5:**
1. Exness MT5: скомпилировать и запустить `EA_DataReader.mq5` на графике TSLA M5
2. Capital.com MT5: установить `UseExternalLevels = true` в параметрах TSLA_ORB_v1
3. Оба MT5 должны быть установлены на одной машине (общая папка `FILE_COMMON`)
4. Путь FILE_COMMON: **Файл → Открыть папку данных** → папка `MQL5/Files/`

---

## Машина состояний

```
STATE_WAITING
    │  09:30 ET — ORB-свеча зафиксирована
    ▼
STATE_LEVELS_SET
    │  Ask/Bid пробил уровень с отступом
    ▼
STATE_IN_TRADE
    │  SL / TP / EOD-закрытие
    ▼
STATE_DISABLED_TODAY  ←── дневной лимит / gap / ошибка
    │  00:00 GMT — новый день
    ▼
STATE_WAITING
```

---

## Входные параметры

### Торговля

| Параметр | По умолч. | Описание |
|---|---|---|
| `Symbol` | TSLA | Торговый инструмент |
| `Leverage` | 20.0 | Плечо 1:N для расчёта лота |
| `EntryOffset` | 0.50 | Отступ от уровня ORB для входа ($) |
| `TakeProfit` | 6.00 | TP от цены входа ($) |
| `BreakevenThreshold` | 1.50 | Движение в прибыль для переноса SL в BE ($) |
| `MaxSlippage` | 30 | Макс. слиппаж (пунктов) |
| `RetryDelay` | 500 | Задержка повтора при реквоте (мс) |
| `ETOffset` | −4 | Сдвиг ET вручную (лето −4, зима −5; игнорируется если AutoDST=true) |
| `AutoDST` | true | Авто-определение летнего/зимнего смещения ET (US DST) |
| `SpikeFilterThreshold` | 2.00 | Макс. спред для входа ($, 0 = откл.) |
| `UseDynamicParams` | true | Масштабировать EntryOffset/TP/BE от цены ORB-свечи |
| `BasePrice` | 400.00 | Эталонная цена TSLA для динамических параметров |
| `UseExternalLevels` | false | Читать уровни из файла EA_DataReader (Dual-MT5 режим) |

### Риск-менеджмент

| Параметр | По умолч. | Описание |
|---|---|---|
| `MaxDailyLossPercent` | 2.0 | Дневной лимит убытка в % от баланса дня (0 = откл.) |
| `MaxDrawdownPercent` | 0.0 | Максимальная просадка от старта EA (0 = откл.) |
| `TradingRatio` | 0.7143 | Доля баланса для торговли (71.43%) |
| `MaxLossPercent` | 28.5 | Макс. потеря от StartBalance до полной остановки (%) |
| `StartBalance` | 0.0 | Стартовый баланс периода (0 = авто при запуске) |

### Уведомления и логирование

| Параметр | По умолч. | Описание |
|---|---|---|
| `EnablePush` | true | Push-уведомления на телефон (MT5 Mobile) |
| `EnableEmail` | false | Email-уведомления |
| `EnableSound` | true | Звуковой сигнал |
| `EnableTelegram` | false | Telegram-уведомления |
| `TelegramToken` | "" | Bot Token от @BotFather |
| `TelegramChatId` | "" | Chat ID (получить у @userinfobot) |
| `LogLevel` | INFO | Детализация лога (DEBUG / INFO / WARNING / ERROR) |
| `Magic` | 20250101 | Magic number EA |

---

## Расчёт лота (v1.8)

Лот рассчитывается **один раз** при фиксации ORB-свечи (09:30 ET):

```
TradingCapital = AccountBalance × TradingRatio
LotSize        = (TradingCapital × Leverage) / (ORBprice × ContractSize)
```

Capital.com: ContractSize = 1, лот = количество акций (целое число).

**Пример** при балансе $280, TSLA = $400, Leverage = 20, TradingRatio = 0.7143:

```
TradingCapital = $280 × 0.7143 = $200
LotSize        = ($200 × 20) / ($400 × 1) = 10 лотов (10 акций)
```

| Баланс | TradingCapital | TSLA $400 | TSLA $300 | TSLA $500 |
|---|---|---|---|---|
| $300 | $214 | 11 акций | 14 акций | 9 акций |
| $500 | $357 | 18 акций | 24 акций | 14 акций |
| $1 000 | $714 | 36 акций | 48 акций | 29 акций |
| $2 000 | $1 428 | 71 акция | 95 акций | 57 акций |

Лот ограничен Capital.com: **MinLot = 1, шаг = 1** (целые акции).

---

## Динамические параметры (v1.6)

При `UseDynamicParams = true` EntryOffset, Breakeven и TP масштабируются от цены ORB-свечи:

```
EntryOffset = $0.50 × (ORBprice / BasePrice)
Breakeven   = $1.50 × (ORBprice / BasePrice)
TakeProfit  = $6.00 × (ORBprice / BasePrice)
R:R = 1:12 при любой цене TSLA
```

---

## Месячный риск-менеджмент (v1.7)

```
StartBalance  = баланс при запуске EA (или из GV если тот же день)
StopLevel     = StartBalance × (1 − MaxLossPercent / 100)
              = StartBalance × 0.715  (при MaxLoss = 28.5%)
```

| Событие | Действие |
|---|---|
| Баланс достиг 90% пути к StopLevel | Push + Email + Sound предупреждение |
| Баланс ≤ StopLevel | EA блокирует новые сделки навсегда |
| Открытые позиции | Остаются под защитой брокерского SL/TP |
| Восстановление | Требуется ручной перезапуск EA |

**После перезапуска** EA берёт текущий баланс как новый StartBalance и пересчитывает StopLevel.

---

## Восстановление после сбоя (GlobalVariables)

Все критические состояния сохраняются в GlobalVariables MT5 и восстанавливаются при перезапуске:

| GlobalVariable | Содержимое |
|---|---|
| `ORB_PRE_HIGH` | Верхний уровень ORB-свечи |
| `ORB_PRE_LOW` | Нижний уровень ORB-свечи |
| `ORB_CLOSE_PRICE` | Цена закрытия ORB-свечи |
| `ORB_LOT_SIZE` | Рассчитанный лот |
| `ORB_STATE` | Текущее состояние EA |
| `ORB_TRADE_DONE` | Флаг: сделка сегодня была |
| `ORB_BE_DONE` | Флаг: Breakeven активирован |
| `ORB_ENTRY_PRICE` | Цена входа текущей позиции |
| `ORB_LAST_DATE` | Дата последнего сброса |
| `ORB_START_BALANCE` | Стартовый баланс периода |
| `ORB_START_BAL_DATE` | Дата фиксации StartBalance |
| `ORB_LEVEL_A_LONG` | Флаг: LEVEL_A для лонга сработал |
| `ORB_LEVEL_A_SHORT` | Флаг: LEVEL_A для шорта сработал |
| `ORB_ORDER_LOCK` | Лок защиты от двойного входа |

---

## Сценарии позднего старта

| Время запуска | Действие EA |
|---|---|
| До 09:30 ET | Штатный запуск, ожидание свечи |
| 09:30–10:00 ET + уровни в GV | Восстановление уровней и лота, торговля |
| После 10:00 ET | STATE_DISABLED_TODAY, ждёт 00:00 GMT |
| Есть открытая позиция | Восстановление, мониторинг BE и EOD |

---

## Уведомления

| Событие | Push | Telegram | Email | Sound |
|---|---|---|---|---|
| Открытие позиции | ✓ | ✓ | ✓ | ✓ |
| Breakeven активирован | ✓ | ✓ | — | — |
| Закрытие по SL/TP/EOD | ✓ | ✓ | ✓ | ✓ |
| Дневной лимит убытка | ✓ | ✓ | ✓ | ✓ |
| Баланс близко к StopLevel (90%) | ✓ | ✓ | ✓ | ✓ |
| StopLevel достигнут — EA остановлен | ✓ | ✓ | ✓ | ✓ |
| ORB-уровни зафиксированы | ✓ | ✓ | — | — |
| GAP на открытии | ✓ | ✓ | — | — |

---

## Установка

### Стандартный режим (Capital.com, рекомендуется)

1. Скопировать все `.mqh` и `.mq5` файлы в папку `MQL5/Experts/`
2. Скомпилировать `TSLA_ORB_v1.mq5` в MetaEditor
3. Открыть график TSLA на таймфрейме **M5** в Capital.com MT5
4. Перетащить EA на график
5. Убедиться что счёт **Hedging** (Capital.com BAH-счёт)
6. Разрешить **Algo Trading** в настройках MT5
7. Разрешить **Push-уведомления**: Инструменты → Настройки → Уведомления

### Telegram (опционально)

1. Создать бота через [@BotFather](https://t.me/BotFather), получить Token
2. Получить Chat ID через [@userinfobot](https://t.me/userinfobot)
3. **Обязательно:** добавить `https://api.telegram.org` в белый список WebRequest:  
   Инструменты → Настройки → Советники → Разрешить WebRequest → добавить адрес
4. В параметрах EA: `EnableTelegram = true`, вставить Token и ChatId

### Dual-MT5 режим (опционально, Exness + Capital.com)

1. Установить два MT5 на одной машине: Exness MT5 и Capital.com MT5
2. Exness MT5: скопировать `EA_DataReader.mq5`, `FileManager.mqh`, `Logger.mqh` в `MQL5/Experts/`, скомпилировать, запустить на графике TSLA M5
3. Capital.com MT5: установить `UseExternalLevels = true` в параметрах TSLA_ORB_v1
4. Убедиться что оба MT5 используют одну и ту же папку `FILE_COMMON` (обычно это так при установке на одной машине)

---

## История версий

| Версия | Изменения |
|---|---|
| **v1.9** | Динамический Breakeven масштабируется с ценой TSLA; предварительная компенсация SL/TP на слиппаж при отправке ордера (fix 4756); Telegram-уведомления (WebRequest) |
| **v1.8** | Расчёт лота через плечо 1:20 от TradingCapital по цене ORB-свечи |
| **v1.7** | Месячный риск-менеджмент: TradingRatio, MaxLossPercent, StartBalance, StopLevel |
| **v1.6** | Динамические EntryOffset/TP масштабируются от текущей цены TSLA |
| **v1.5** | Базовая стратегия ORB: уровни, вход A→B, Breakeven, EOD-закрытие |
