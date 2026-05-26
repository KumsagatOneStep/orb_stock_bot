# TSLA ORB EA — v1.9

Expert Advisor для MetaTrader 5 на основе стратегии **Opening Range Breakout (ORB)** по акции TSLA.  
Брокер: **Capital.com BAH · Hedging · ContractSize = 1 акция**.

---

## Стратегия

Бот торгует пробой уровней последней 5-минутной свечи премаркета.

| Этап | Время ET | Сервер UTC+0 (лето) | Сервер UTC+0 (зима) |
|---|---|---|---|
| Формирование ORB-свечи | 09:25 – 09:30 | 13:25 – 13:30 | 14:25 – 14:30 |
| Фиксация уровней HIGH / LOW | 09:30:00 | 13:30:00 | 14:30:00 |
| Окно входа | 09:30 – 10:00 | 13:30 – 14:00 | 14:30 – 15:00 |
| Принудительное закрытие EOD | 15:50 | 19:50 | 20:50 |

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

```
TSLA_ORB_v1.mq5   — главный файл (OnInit / OnTick / OnTimer / OnTradeTransaction)
├── Logger.mqh    — логирование и уведомления (Push / Email / Sound)
├── Levels.mqh    — фиксация ORB-уровней, расчёт лота, машина состояний
├── Risk.mqh      — дневной лимит, просадка, месячный стоп-уровень
├── Entry.mqh     — логика входа, отправка ордера с retry
└── Position.mqh  — Breakeven, EOD-закрытие, детектор закрытия SL/TP
```

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
| `ETOffset` | −4 | Сдвиг ET от UTC вручную (если AutoDST=false) |
| `AutoDST` | true | Авто-определение летнего/зимнего ET (US DST) |
| `SpikeFilterThreshold` | 2.00 | Макс. спред для входа ($, 0 = откл.) |
| `UseDynamicParams` | true | Масштабировать EntryOffset/TP/BE от текущей цены TSLA |
| `BasePrice` | 400.00 | Эталонная цена для динамических параметров |

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
| `EnablePush` | true | Push-уведомления на телефон |
| `EnableEmail` | false | Email-уведомления |
| `EnableSound` | true | Звуковой сигнал |
| `LogLevel` | INFO | Детализация лога (DEBUG / INFO / WARNING / ERROR) |
| `Magic` | 20250101 | Magic number EA |

---

## Расчёт лота (v1.8)

Лот рассчитывается **один раз** при фиксации ORB-свечи (09:30 ET):

```
TradingCapital = AccountBalance × TradingRatio
LotSize        = ROUND((TradingCapital × Leverage) / ORBprice)
LotSize        = MathMax(LotSize, 1)     ← MinLot = 1
LotSize        = MathMin(LotSize, 1000)  ← MaxLot = 1000
```

**Пример** при балансе $300, TSLA = $400, Leverage = 20, TradingRatio = 0.7143:

```
TradingCapital = $300 × 0.7143 = $214
LotSize        = ROUND($214 × 20 / $400) = ROUND(10.71) = 11 акций
```

| Баланс | TradingCapital | TSLA $400 | TSLA $300 | TSLA $500 |
|---|---|---|---|---|
| $300 | $214 | 11 акций | 14 акций | 9 акций |
| $500 | $357 | 18 акций | 24 акций | 14 акций |
| $1 000 | $714 | 36 акций | 48 акций | 29 акций |
| $2 000 | $1 428 | 71 акций | 95 акций | 57 акций |

Лот на Capital.com BAH: **MinLot = 1, MaxLot = 1000, шаг = 1 (только целые акции)**.

---

## Динамические параметры (v1.6 / v1.9)

При `UseDynamicParams = true` EntryOffset, TP и Breakeven масштабируются от цены ORB-свечи:

```
EntryOffset        = $0.50 × (ORBprice / BasePrice)
BreakevenThreshold = $1.50 × (ORBprice / BasePrice)
TakeProfit         = $6.00 × (ORBprice / BasePrice)
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

| Событие | Push | Email | Sound |
|---|---|---|---|
| Открытие позиции | ✓ | ✓ | ✓ |
| Breakeven активирован | ✓ | — | — |
| Закрытие по SL/TP/EOD | ✓ | ✓ | ✓ |
| Дневной лимит убытка | ✓ | ✓ | ✓ |
| Баланс близко к StopLevel (90%) | ✓ | ✓ | ✓ |
| StopLevel достигнут — EA остановлен | ✓ | ✓ | ✓ |
| ORB-уровни зафиксированы | ✓ | — | — |
| GAP на открытии | ✓ | — | — |

---

## Установка

1. Скопировать все `.mqh` и `.mq5` файлы в папку `MQL5/Experts/`
2. Скомпилировать `TSLA_ORB_v1.mq5` в MetaEditor
3. Открыть график TSLA на таймфрейме **M5**
4. Перетащить EA на график
5. Убедиться что счёт **Hedging** (Capital.com BAH: заголовок MT5 — "Hedge")
6. Разрешить **Algo Trading** и **Push-уведомления** в настройках MT5

### Параметры брокера Capital.com BAH

| Параметр | Значение |
|---|---|
| Сервер | Capital.ComBah |
| Сервер UTC | UTC+0 (GMT) всегда |
| Тип счёта | Hedging |
| ContractSize | 1 (1 лот = 1 акция) |
| MinLot | 1 |
| MaxLot | 1000 |
| Шаг лота | 1 |
| Начало торговли | 08:00 UTC = 04:00 ET |

---

## История версий

| Версия | Изменения |
|---|---|
| **v1.9** | AutoDST (авто-определение US DST), динамический Breakeven, перенос на Capital.com BAH (Hedging, ContractSize=1) |
| **v1.8** | Расчёт лота через плечо 1:20 от TradingCapital по цене ORB-свечи |
| **v1.7** | Месячный риск-менеджмент: TradingRatio, MaxLossPercent, StartBalance, StopLevel |
| **v1.6** | Динамические EntryOffset/TP масштабируются от текущей цены TSLA |
| **v1.5** | Базовая стратегия ORB: уровни, вход A→B, Breakeven, EOD-закрытие |
