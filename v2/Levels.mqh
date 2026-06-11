//+------------------------------------------------------------------+
//|                                                       Levels.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v2.0 (09:30-09:35)   |
//|           Модуль: фиксация уровней PRE_HIGH / PRE_LOW            |
//|                                                                  |
//|  Логика:                                                         |
//|    • Ищет M5-свечу с открытием в 09:30 ET (13:30 / 14:30 UTC)   |
//|    • При її закрытии (13:35 / 14:35 UTC) фиксирует HIGH и LOW    |
//|    • Сохраняет уровни в GlobalVariables                          |
//|    • Обрабатывает поздний старт, обрыв соединения, no-candle     |
//+------------------------------------------------------------------+
#ifndef LEVELS_MQH
#define LEVELS_MQH

#include "Logger.mqh"
#include "FileManager.mqh"

//+------------------------------------------------------------------+
//|  Перечисление состояний советника                                |
//|  Объявлено здесь — используется всеми модулями через Levels.mqh  |
//+------------------------------------------------------------------+
enum ENUM_EA_STATE
{
   STATE_WAITING,         // Ожидание фиксации уровней
   STATE_LEVELS_SET,      // Уровни зафиксированы, ожидание окна входа
   STATE_IN_TRADE,        // Позиция открыта
   STATE_DISABLED_TODAY   // Торговля заблокирована на текущий день
};

//+------------------------------------------------------------------+
//|  Разделяемые переменные модуля                                   |
//|  Объявляются один раз — видны всему советнику после #include     |
//+------------------------------------------------------------------+
double        g_preHigh        = 0.0;           // Верхний уровень ORB (PRE_HIGH)
double        g_preLow         = 0.0;           // Нижний уровень ORB  (PRE_LOW)
ENUM_EA_STATE g_eaState        = STATE_WAITING; // Текущее состояние EA
bool          g_levelsFixed    = false;         // Флаг однократной фиксации уровней

// Динамические параметры (v1.6) — масштабируются от цены ORB-свечи
double        g_dynEntryOffset = 0.0;           // EntryOffset = SL-дистанция (dynamic)
double        g_dynTP          = 0.0;           // TakeProfit-дистанция (dynamic)
double        g_dynBreakeven   = 0.0;           // BreakevenThreshold (dynamic, v1.9)
bool          g_dynReady       = false;         // Флаг: динамические параметры вычислены
double        g_lotSize        = 0.0;           // Лот, рассчитанный из ORB-цены × плечо (v1.8)

//+------------------------------------------------------------------+
//|  Возвращает серверный час открытия ORB-свечи                     |
//|                                                                  |
//|  09:25 ET → UTC: UTC = ET - ETOffset                             |
//|  Лето  (ETOffset = -4): UTC_hour = 9 - (-4) = 13                |
//|  Зима  (ETOffset = -5): UTC_hour = 9 - (-5) = 14                |
//+------------------------------------------------------------------+
int GetOrbCandleHour(int etOffset)
{
   return 9 - etOffset;
}

//+------------------------------------------------------------------+
//|  Расчёт динамических параметров (v1.6)                           |
//|  EntryOffset = SL = 0.50 * (currentPrice / basePrice)           |
//|  TakeProfit  = 6.00 * (currentPrice / basePrice)                |
//|  R:R = 1:12 при любой цене TSLA                                  |
//+------------------------------------------------------------------+
void CalcDynamicParams(double currentPrice, double basePrice)
{
   if(basePrice <= 0.0)
   {
      LogError("CalcDynamicParams: basePrice=0 — динамические параметры не рассчитаны");
      return;
   }
   double ratio      = currentPrice / basePrice;
   g_dynEntryOffset  = NormalizeDouble(0.50 * ratio, 2);
   g_dynBreakeven    = NormalizeDouble(1.50 * ratio, 2);
   g_dynTP           = NormalizeDouble(6.00 * ratio, 2);
   g_dynReady        = true;
   GlobalVariableSet("ORB_ENTRY_OFFSET", g_dynEntryOffset);
   GlobalVariableSet("ORB_STOP_LOSS",    g_dynEntryOffset);   // SL == EntryOffset по дизайну
   GlobalVariableSet("ORB_BREAKEVEN",    g_dynBreakeven);
   GlobalVariableSet("ORB_TAKE_PROFIT",  g_dynTP);
   LogInfo(StringFormat("Dynamic params | Price=$%.2f  Entry=$%.2f  BE=$%.2f  TP=$%.2f  Ratio=%.4f",
                         currentPrice, g_dynEntryOffset, g_dynBreakeven, g_dynTP, ratio));
}

//+------------------------------------------------------------------+
//|  Расчёт лота через плечо от ORB-цены (v1.8)                     |
//|  LotSize = (Balance × TradingRatio × Leverage) / (Price × ContractSize)  |
//|  Вызывается однократно при фиксации ORB-уровней                           |
//+------------------------------------------------------------------+
void CalcOrbLot(string symbol, double orbPrice, double tradingRatio, double leverage)
{
   if(orbPrice <= 0.0 || tradingRatio <= 0.0 || leverage <= 0.0)
   {
      LogError("CalcOrbLot: некорректные параметры — лот не рассчитан");
      return;
   }

   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contractSize <= 0.0)
   {
      LogError(StringFormat("CalcOrbLot: ContractSize=%.0f — используем 1 как запасное значение", contractSize));
      contractSize = 1.0;
   }

   double balance        = AccountInfoDouble(ACCOUNT_BALANCE);
   double tradingCapital = balance * tradingRatio;
   double lotSize        = (tradingCapital * leverage) / (orbPrice * contractSize);

   // Округление до шага лота брокера (Capital.com: step=1, целые акции)
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0) lotStep = 1.0;
   lotSize = MathRound(lotSize / lotStep) * lotStep;

   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(maxLot <= 0.0) maxLot = 1000.0;
   if(lotSize > maxLot)
   {
      LogWarning(StringFormat("LotSize %.2f превышает MaxLot=%.2f — обрезан", lotSize, maxLot));
      lotSize = maxLot;
   }
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(minLot <= 0.0) minLot = 1.0;
   lotSize = MathMax(lotSize, minLot);

   g_lotSize = lotSize;
   GlobalVariableSet("ORB_LOT_SIZE", g_lotSize);

   LogInfo(StringFormat("Лот рассчитан: Balance=$%.2f  TradingCapital=$%.2f  "
                        "Price=$%.2f  ContractSize=%.0f  Leverage=1:%.0f  LotSize=%.2f  Акций=%.0f  Маржа=$%.2f",
                        balance, tradingCapital, orbPrice, contractSize, leverage,
                        lotSize, MathRound(lotSize * contractSize), tradingCapital));
}

//+------------------------------------------------------------------+
//|  Строит datetime открытия ORB-свечи для сегодняшней даты        |
//|  Результат: сегодня orbHour:25:00 по серверному времени          |
//+------------------------------------------------------------------+
datetime BuildOrbOpenTime(int etOffset)
{
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   dt.hour = GetOrbCandleHour(etOffset);
   dt.min  = 30;
   dt.sec  = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//|  Ищет в M5-истории свечу с открытием в 09:25 ET за сегодня     |
//|  Возвращает индекс бара (>= 1) или -1 если свеча не найдена     |
//|                                                                  |
//|  Примечания:                                                     |
//|    • Бар [0] — текущая формирующаяся свеча, поиск с [1]         |
//|    • Поиск прерывается если вышли дальше 2 часов до цели        |
//+------------------------------------------------------------------+
int FindOrbCandleIndex(string symbol, int etOffset)
{
   datetime orbOpenTime = BuildOrbOpenTime(etOffset);

   int totalBars   = iBars(symbol, PERIOD_M5);
   int searchDepth = MathMin(totalBars - 1, 60);   // 60 × 5 мин = 5 часов истории

   for(int i = 1; i <= searchDepth; i++)
   {
      datetime barTime = iTime(symbol, PERIOD_M5, i);

      if(barTime == orbOpenTime)
         return i;

      // Прекращаем поиск при уходе слишком далеко в прошлое
      if(barTime < orbOpenTime - 7200)
         break;
   }

   return -1;
}

//+------------------------------------------------------------------+
//|  Фиксирует уровни PRE_HIGH / PRE_LOW из M5-истории              |
//|  Сохраняет результат в GlobalVariables                           |
//|  Возвращает true при успешной фиксации                           |
//|                                                                  |
//|  Edge case (раздел 7.1): свеча не найдена →                      |
//|    STATE_DISABLED_TODAY + Push-уведомление                       |
//+------------------------------------------------------------------+
bool FixLevelsFromHistory(string symbol, int etOffset,
                          bool useDynamic = false, double basePrice = 400.0,
                          double tradingRatio = 0.7143, double leverage = 20.0)
{
   int candleIdx = FindOrbCandleIndex(symbol, etOffset);

   if(candleIdx < 0)
   {
      // Свеча 09:30 ET отсутствует в истории M5.
      // Если мы ещё в минуте fixHour:35 — даём брокеру время обновить историю
      // (бар может появиться с задержкой 200–500мс после закрытия).
      // Блокируем только если прошла вся минута 35 (now.min >= 36).
      MqlDateTime nowCheck;
      TimeToStruct(TimeTradeServer(), nowCheck);
      int fixHourCheck = GetOrbCandleHour(etOffset);
      if(nowCheck.hour == fixHourCheck && nowCheck.min < 36)
      {
         LogDebug(StringFormat("Свеча ORB не найдена в %02d:%02d — ожидаем обновления истории",
                               nowCheck.hour, nowCheck.min));
         return false;   // повторим на следующем тике/таймере
      }

      string errMsg = StringFormat("[%s] Свеча ORB 09:30 ET (%s) не найдена — "
                                   "день пропущен",
                                   symbol,
                                   TimeToString(BuildOrbOpenTime(etOffset),
                                                TIME_DATE | TIME_MINUTES));
      LogError(errMsg);
      g_eaState = STATE_DISABLED_TODAY;
      GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
      SendEaAlert(errMsg, true, false, false);
      return false;
   }

   // Фиксируем уровни из найденной свечи
   g_preHigh     = iHigh(symbol, PERIOD_M5, candleIdx);
   g_preLow      = iLow(symbol,  PERIOD_M5, candleIdx);
   g_eaState     = STATE_LEVELS_SET;
   g_levelsFixed = true;

   // Цена закрытия ORB-свечи — нужна и для динамических параметров, и для расчёта лота
   double orbPrice = iClose(symbol, PERIOD_M5, candleIdx);
   if(orbPrice > 0.0)
   {
      GlobalVariableSet("ORB_CLOSE_PRICE", orbPrice);

      // v1.6: масштабирование EntryOffset/TP от цены свечи
      if(useDynamic && basePrice > 0.0)
         CalcDynamicParams(orbPrice, basePrice);

      // v1.8: расчёт лота через плечо от цены ORB-свечи
      CalcOrbLot(symbol, orbPrice, tradingRatio, leverage);
   }

   // Сохраняем в GlobalVariables для восстановления после обрыва (раздел 7.3)
   GlobalVariableSet("ORB_PRE_HIGH", g_preHigh);
   GlobalVariableSet("ORB_PRE_LOW",  g_preLow);
   GlobalVariableSet("ORB_STATE",    (double)STATE_LEVELS_SET);

   string msg = StringFormat("ORB уровни зафиксированы | PRE_HIGH=%.2f  PRE_LOW=%.2f  "
                              "Свеча[%d]: O=%.2f H=%.2f L=%.2f",
                              g_preHigh, g_preLow, candleIdx,
                              iOpen(symbol, PERIOD_M5, candleIdx),
                              g_preHigh, g_preLow);
   LogInfo(msg);
   SendEaAlert(StringFormat("ORB уровни | HIGH=%.2f  LOW=%.2f", g_preHigh, g_preLow),
               true, false, false);

   return true;
}

//+------------------------------------------------------------------+
//|  Восстанавливает уровни из GlobalVariables                       |
//|  Используется при переподключении или позднем старте             |
//|  Возвращает true если значения в GV валидны                      |
//+------------------------------------------------------------------+
bool RestoreLevelsFromGV(string symbol, bool useDynamic = false, double basePrice = 400.0,
                         double tradingRatio = 0.7143, double leverage = 20.0)
{
   if(!GlobalVariableCheck("ORB_PRE_HIGH") || !GlobalVariableCheck("ORB_PRE_LOW"))
      return false;

   double savedHigh = GlobalVariableGet("ORB_PRE_HIGH");
   double savedLow  = GlobalVariableGet("ORB_PRE_LOW");

   if(savedHigh <= 0.0 || savedLow <= 0.0 || savedHigh <= savedLow)
      return false;

   g_preHigh     = savedHigh;
   g_preLow      = savedLow;
   g_levelsFixed = true;

   // Восстанавливаем цену ORB-свечи для динамических параметров и лота
   if(GlobalVariableCheck("ORB_CLOSE_PRICE"))
   {
      double savedClose = GlobalVariableGet("ORB_CLOSE_PRICE");
      if(savedClose > 0.0)
      {
         if(useDynamic && basePrice > 0.0)
            CalcDynamicParams(savedClose, basePrice);

         // Восстанавливаем лот: сначала из GV, иначе пересчитываем
         if(GlobalVariableCheck("ORB_LOT_SIZE"))
         {
            double savedLot = GlobalVariableGet("ORB_LOT_SIZE");
            if(savedLot > 0.0)
            {
               g_lotSize = savedLot;
               LogInfo(StringFormat("Лот восстановлен из GV: %.2f", g_lotSize));
            }
            else
               CalcOrbLot(symbol, savedClose, tradingRatio, leverage);
         }
         else
            CalcOrbLot(symbol, savedClose, tradingRatio, leverage);
      }
   }

   LogInfo(StringFormat("Уровни восстановлены из GlobalVariables | "
                        "PRE_HIGH=%.2f  PRE_LOW=%.2f  LotSize=%.2f",
                        g_preHigh, g_preLow, g_lotSize));
   return true;
}

//+------------------------------------------------------------------+
//|  Загрузка уровней из levels.txt (EA_DataReader → FILE_COMMON)   |
//|  Проверяет DATE == сегодня и STATUS == "READY"                   |
//+------------------------------------------------------------------+
bool ReadFromFile(string symbol, double tradingRatio, double leverage)
{
   OrbLevels lv;
   if(!ReadLevelsFile(lv))
   {
      LogDebug("ReadFromFile: orb_levels.txt не найден");
      return false;
   }

   string today = OrbTodayString();
   if(lv.date != today)
   {
      LogWarning(StringFormat("ReadFromFile: дата файла '%s' != сегодня '%s' — игнорируем",
                               lv.date, today));
      return false;
   }

   if(lv.status != "READY")
   {
      LogDebug(StringFormat("ReadFromFile: STATUS='%s' (ожидаем READY) — файл ещё пишется",
                             lv.status));
      return false;
   }

   if(lv.preHigh <= 0.0 || lv.preLow <= 0.0 || lv.preHigh <= lv.preLow)
   {
      LogError(StringFormat("ReadFromFile: некорректные уровни HIGH=%.5f LOW=%.5f",
                             lv.preHigh, lv.preLow));
      g_eaState = STATE_DISABLED_TODAY;
      GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
      SendEaAlert("ОШИБКА: некорректные уровни в levels.txt — торговля отменена",
                  true, false, false);
      return false;
   }

   g_preHigh  = lv.preHigh;
   g_preLow   = lv.preLow;

   g_dynEntryOffset = lv.entryOffset;
   g_dynBreakeven   = lv.breakeven;
   g_dynTP          = lv.takeProfit;
   g_dynReady       = true;

   GlobalVariableSet("ORB_ENTRY_OFFSET", g_dynEntryOffset);
   GlobalVariableSet("ORB_STOP_LOSS",    g_dynEntryOffset);
   GlobalVariableSet("ORB_BREAKEVEN",    g_dynBreakeven);
   GlobalVariableSet("ORB_TAKE_PROFIT",  g_dynTP);

   if(lv.closePrice > 0.0)
   {
      GlobalVariableSet("ORB_CLOSE_PRICE", lv.closePrice);
      CalcOrbLot(symbol, lv.closePrice, tradingRatio, leverage);
   }

   GlobalVariableSet("ORB_PRE_HIGH", g_preHigh);
   GlobalVariableSet("ORB_PRE_LOW",  g_preLow);
   GlobalVariableSet("ORB_STATE",    (double)STATE_LEVELS_SET);

   g_eaState     = STATE_LEVELS_SET;
   g_levelsFixed = true;

   string msg = StringFormat("Уровни загружены из файла | "
                              "PRE_HIGH=%.2f  PRE_LOW=%.2f  "
                              "Entry=%.2f  BE=%.2f  TP=%.2f  Lot=%.2f  "
                              "Время файла: %s",
                              g_preHigh, g_preLow,
                              g_dynEntryOffset, g_dynBreakeven, g_dynTP,
                              g_lotSize, lv.timestamp);
   LogInfo(msg);
   SendEaAlert(StringFormat("ORB уровни из файла | HIGH=%.2f  LOW=%.2f",
                             g_preHigh, g_preLow),
               true, false, false);
   return true;
}

//+------------------------------------------------------------------+
//|  Инициализация модуля — вызывается из OnInit()                   |
//|                                                                  |
//|  Параметры:                                                      |
//|    symbol             — торговый инструмент                      |
//|    etOffset           — смещение ET от UTC (-4 лето, -5 зима)    |
//|    hasOpenPosition    — есть ли открытая позиция с нашим Magic   |
//|    useExternalLevels  — читать уровни из levels.txt (DataReader) |
//|                                                                  |
//|  Сценарии позднего запуска (раздел 7.4):                         |
//|    A. Открытая позиция   → восстановить уровни, STATE_IN_TRADE   |
//|    B. После окна входа   → STATE_DISABLED_TODAY                  |
//|    C. В окне входа       → попытка восстановить уровни           |
//|    D. До фиксации        → STATE_WAITING, штатный запуск         |
//+------------------------------------------------------------------+
void InitLevels(string symbol, int etOffset, bool hasOpenPosition,
                bool useDynamic = false, double basePrice = 400.0,
                double tradingRatio = 0.7143, double leverage = 20.0,
                bool useExternalLevels = false)
{
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   int fixHour  = GetOrbCandleHour(etOffset);   // 13 (лето) / 14 (зима)
   int entryEnd = fixHour + 1;                   // 14 (лето) / 15 (зима)

   //--- Сценарий A: есть открытая позиция → восстанавливаем и продолжаем мониторинг
   if(hasOpenPosition)
   {
      if(!RestoreLevelsFromGV(symbol, useDynamic, basePrice, tradingRatio, leverage))
         FixLevelsFromHistory(symbol, etOffset, useDynamic, basePrice, tradingRatio, leverage);

      g_eaState = STATE_IN_TRADE;
      LogInfo(StringFormat("EA восстановлен с открытой позицией | "
                           "PRE_HIGH=%.2f  PRE_LOW=%.2f",
                           g_preHigh, g_preLow));
      return;
   }

   //--- Сценарий B: запуск после закрытия окна входа → ждём нового дня (00:00 GMT)
   if(now.hour >= entryEnd)
   {
      g_eaState = STATE_DISABLED_TODAY;
      GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
      LogInfo(StringFormat("EA запущен после окна входа (%02d:00 сервер) — "
                           "торговля отключена до 00:00 GMT",
                           entryEnd));
      return;
   }

   //--- Сценарий C: запуск в окне входа [fixHour:35, entryEnd:00) → восстановить уровни
   if(now.hour == fixHour && now.min >= 35)
   {
      LogInfo(StringFormat("EA запущен в окне входа (%02d:%02d сервер) — "
                           "восстановление уровней",
                           now.hour, now.min));

      if(!RestoreLevelsFromGV(symbol, useDynamic, basePrice, tradingRatio, leverage))
      {
         if(useExternalLevels)
         {
            if(!ReadFromFile(symbol, tradingRatio, leverage))
            {
               LogError("InitLevels: файл уровней недоступен при позднем старте");
               g_eaState = STATE_DISABLED_TODAY;
               GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
            }
         }
         else
            FixLevelsFromHistory(symbol, etOffset, useDynamic, basePrice, tradingRatio, leverage);
      }
      else
         g_eaState = STATE_LEVELS_SET;

      return;
   }

   //--- Сценарий D: запуск до начала свечи или во время её формирования → штатно
   g_eaState = STATE_WAITING;
   LogInfo(StringFormat("EA инициализирован | Ожидание фиксации уровней в %02d:35 сервер",
                         fixHour));
}

//+------------------------------------------------------------------+
//|  Обработка тика — вызывается из OnTick() каждый тик             |
//|                                                                  |
//|  При первом тике в минуте fixHour:30 (момент закрытия свечи):   |
//|    • Вызывает FixLevelsFromHistory()                             |
//|    • g_levelsFixed гарантирует однократную фиксацию             |
//+------------------------------------------------------------------+
void ProcessLevelTick(string symbol, int etOffset,
                      bool useDynamic = false, double basePrice = 400.0,
                      double tradingRatio = 0.7143, double leverage = 20.0,
                      bool useExternalLevels = false)
{
   if(g_levelsFixed)
      return;
   if(g_eaState == STATE_IN_TRADE || g_eaState == STATE_DISABLED_TODAY)
      return;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   int fixHour = GetOrbCandleHour(etOffset);

   if(useExternalLevels)
   {
      // Начинаем проверять файл только после fixHour:30 (когда EA_DataReader пишет файл)
      if(now.hour < fixHour || (now.hour == fixHour && now.min < 35))
         return;

      if(ReadFromFile(symbol, tradingRatio, leverage))
         return;

      // Таймаут: если прошло 5 минут после fixHour:30 — файл так и не появился
      bool pastTimeout = (now.hour > fixHour) ||
                         (now.hour == fixHour && now.min >= 40);
      if(pastTimeout)
      {
         string msg = StringFormat("EA_DataReader не записал levels.txt до %02d:40 сервер — "
                                   "торговля отменена", fixHour);
         LogError(msg);
         SendEaAlert(msg, true, false, false);
         g_eaState = STATE_DISABLED_TODAY;
         GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
      }
      return;
   }

   // Стандартный режим: самостоятельная фиксация из истории M5
   // Пробуем в минуту 30, и повторно в минуту 31 если свеча ещё не найдена
   // (на некоторых брокерах бар появляется в истории с задержкой 200–500мс)
   bool isFixMinute = (now.hour == fixHour) &&
                      (now.min == 35 || (now.min == 36 && !g_levelsFixed));
   if(isFixMinute)
   {
      LogDebug(StringFormat("Тик %02d:%02d:%02d — момент фиксации ORB-уровней",
                             now.hour, now.min, now.sec));
      FixLevelsFromHistory(symbol, etOffset, useDynamic, basePrice, tradingRatio, leverage);
   }
}

//+------------------------------------------------------------------+
//|  Сброс состояния модуля при смене даты (00:00 GMT)              |
//|  Вызывается из модуля Risk при обнаружении нового дня            |
//+------------------------------------------------------------------+
void ResetLevels()
{
   g_preHigh        = 0.0;
   g_preLow         = 0.0;
   g_eaState        = STATE_WAITING;
   g_levelsFixed    = false;
   g_dynEntryOffset = 0.0;
   g_dynBreakeven   = 0.0;
   g_dynTP          = 0.0;
   g_dynReady       = false;
   g_lotSize        = 0.0;

   GlobalVariableSet("ORB_PRE_HIGH",     0.0);
   GlobalVariableSet("ORB_PRE_LOW",      0.0);
   GlobalVariableSet("ORB_CLOSE_PRICE",  0.0);
   GlobalVariableSet("ORB_LOT_SIZE",     0.0);
   GlobalVariableSet("ORB_ENTRY_OFFSET", 0.0);
   GlobalVariableSet("ORB_STOP_LOSS",    0.0);
   GlobalVariableSet("ORB_BREAKEVEN",    0.0);
   GlobalVariableSet("ORB_TAKE_PROFIT",  0.0);
   GlobalVariableSet("ORB_STATE",        (double)STATE_WAITING);

   LogInfo("Уровни сброшены — начало нового торгового дня");
}

//+------------------------------------------------------------------+
//|  Вспомогательная: N-е вхождение дня недели в месяце              |
//|  dayOfWeek: 0=вс, 1=пн … 6=сб (формат MQL5)                     |
//+------------------------------------------------------------------+
datetime FindNthWeekday(int year, int month, int n, int dayOfWeek)
{
   MqlDateTime dt = {};
   dt.year = year;
   dt.mon  = month;
   dt.day  = 1;
   datetime firstDay = StructToTime(dt);
   MqlDateTime fdStruct;
   TimeToStruct(firstDay, fdStruct);
   int shift = (dayOfWeek - fdStruct.day_of_week + 7) % 7;
   dt.day    = 1 + shift + (n - 1) * 7;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//|  Автоматическое определение смещения ET относительно UTC          |
//|  EDT (−4): 2-е вс марта 07:00 UTC → 1-е вс ноября 06:00 UTC     |
//|  EST (−5): всё остальное время                                    |
//+------------------------------------------------------------------+
int CalcUSETOffset(datetime serverUTC)
{
   MqlDateTime dt;
   TimeToStruct(serverUTC, dt);
   int year = dt.year;

   datetime dstStart = FindNthWeekday(year,  3, 2, 0) + 7 * 3600;  // 2-е вс марта, 07:00 UTC
   datetime dstEnd   = FindNthWeekday(year, 11, 1, 0) + 6 * 3600;  // 1-е вс ноября, 06:00 UTC

   return (serverUTC >= dstStart && serverUTC < dstEnd) ? -4 : -5;
}

//+------------------------------------------------------------------+
//|  Режим заполнения ордера для закрытия позиции                    |
//|  IOC предпочтительнее FOK: допускает частичное исполнение,       |
//|  что надёжнее при EOD-закрытии на узком рынке                    |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingModeClose(string symbol)
{
   int modes = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   if((modes & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}

#endif // LEVELS_MQH
