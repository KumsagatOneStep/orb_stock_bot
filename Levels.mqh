//+------------------------------------------------------------------+
//|                                                       Levels.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v1.6              |
//|           Модуль: фиксация уровней PRE_HIGH / PRE_LOW            |
//|                                                                  |
//|  Логика:                                                         |
//|    • Ищет M5-свечу с открытием в 09:25 ET (13:25 / 14:25 UTC)   |
//|    • При её закрытии (13:30 / 14:30 UTC) фиксирует HIGH и LOW    |
//|    • Сохраняет уровни в GlobalVariables                          |
//|    • Обрабатывает поздний старт, обрыв соединения, no-candle     |
//+------------------------------------------------------------------+
#ifndef LEVELS_MQH
#define LEVELS_MQH

#include "Logger.mqh"

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
bool          g_dynReady       = false;         // Флаг: динамические параметры вычислены

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
   double ratio     = currentPrice / basePrice;
   g_dynEntryOffset = NormalizeDouble(0.50 * ratio, 2);
   g_dynTP          = NormalizeDouble(6.00 * ratio, 2);
   g_dynReady       = true;
   LogInfo(StringFormat("Dynamic params | Price=$%.2f  EntryOffset=$%.2f  TP=$%.2f  Ratio=%.4f",
                         currentPrice, g_dynEntryOffset, g_dynTP, currentPrice / basePrice));
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
   dt.min  = 25;
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
                          bool useDynamic = false, double basePrice = 400.0)
{
   int candleIdx = FindOrbCandleIndex(symbol, etOffset);

   if(candleIdx < 0)
   {
      // Свеча 09:25 ET отсутствует в истории M5
      string errMsg = StringFormat("[%s] Свеча ORB 09:25 ET (%s) не найдена — "
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

   // v1.6: динамические параметры по цене закрытия ORB-свечи
   if(useDynamic && basePrice > 0.0)
   {
      double currentPrice = iClose(symbol, PERIOD_M5, candleIdx);
      if(currentPrice > 0.0)
         CalcDynamicParams(currentPrice, basePrice);
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
bool RestoreLevelsFromGV()
{
   if(!GlobalVariableCheck("ORB_PRE_HIGH") || !GlobalVariableCheck("ORB_PRE_LOW"))
      return false;

   double savedHigh = GlobalVariableGet("ORB_PRE_HIGH");
   double savedLow  = GlobalVariableGet("ORB_PRE_LOW");

   // Проверка валидности: значения должны быть положительными, HIGH > LOW
   if(savedHigh <= 0.0 || savedLow <= 0.0 || savedHigh <= savedLow)
      return false;

   g_preHigh     = savedHigh;
   g_preLow      = savedLow;
   g_levelsFixed = true;

   LogInfo(StringFormat("Уровни восстановлены из GlobalVariables | "
                        "PRE_HIGH=%.2f  PRE_LOW=%.2f",
                        g_preHigh, g_preLow));
   return true;
}

//+------------------------------------------------------------------+
//|  Инициализация модуля — вызывается из OnInit()                   |
//|                                                                  |
//|  Параметры:                                                      |
//|    symbol          — торговый инструмент                         |
//|    etOffset        — смещение ET от UTC (-4 лето, -5 зима)       |
//|    hasOpenPosition — есть ли открытая позиция с нашим Magic      |
//|                                                                  |
//|  Сценарии позднего запуска (раздел 7.4):                         |
//|    A. Открытая позиция   → восстановить уровни, STATE_IN_TRADE   |
//|    B. После окна входа   → STATE_DISABLED_TODAY                  |
//|    C. В окне входа       → попытка восстановить уровни           |
//|    D. До фиксации        → STATE_WAITING, штатный запуск         |
//+------------------------------------------------------------------+
void InitLevels(string symbol, int etOffset, bool hasOpenPosition,
                bool useDynamic = false, double basePrice = 400.0)
{
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   int fixHour  = GetOrbCandleHour(etOffset);   // 13 (лето) / 14 (зима)
   int entryEnd = fixHour + 1;                   // 14 (лето) / 15 (зима)

   //--- Сценарий A: есть открытая позиция → восстанавливаем и продолжаем мониторинг
   if(hasOpenPosition)
   {
      if(!RestoreLevelsFromGV())
         FixLevelsFromHistory(symbol, etOffset, useDynamic, basePrice);   // Fallback: ищем в M5

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

   //--- Сценарий C: запуск в окне входа [fixHour:30, entryEnd:00) → восстановить уровни
   if(now.hour == fixHour && now.min >= 30)
   {
      LogInfo(StringFormat("EA запущен в окне входа (%02d:%02d сервер) — "
                           "восстановление уровней",
                           now.hour, now.min));

      if(!RestoreLevelsFromGV())
         FixLevelsFromHistory(symbol, etOffset, useDynamic, basePrice);
      else
         g_eaState = STATE_LEVELS_SET;   // BUG 6: без этого EA молчит после реконнекта
      // При неудаче FixLevelsFromHistory сам выставит STATE_DISABLED_TODAY

      return;
   }

   //--- Сценарий D: запуск до начала свечи или во время её формирования → штатно
   g_eaState = STATE_WAITING;
   LogInfo(StringFormat("EA инициализирован | Ожидание фиксации уровней в %02d:30 сервер",
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
                      bool useDynamic = false, double basePrice = 400.0)
{
   // Уже зафиксированы / не нужна обработка
   if(g_levelsFixed)
      return;
   if(g_eaState == STATE_IN_TRADE || g_eaState == STATE_DISABLED_TODAY)
      return;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   int fixHour = GetOrbCandleHour(etOffset);   // 13 или 14

   // Момент закрытия ORB-свечи: первый тик в минуте fixHour:30
   if(now.hour == fixHour && now.min == 30)
   {
      LogDebug(StringFormat("Тик %02d:%02d:%02d — момент фиксации ORB-уровней",
                             now.hour, now.min, now.sec));
      FixLevelsFromHistory(symbol, etOffset, useDynamic, basePrice);
      // g_levelsFixed выставляется внутри при успехе → защита от повтора
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
   g_dynTP          = 0.0;
   g_dynReady       = false;

   GlobalVariableSet("ORB_PRE_HIGH", 0.0);
   GlobalVariableSet("ORB_PRE_LOW",  0.0);
   GlobalVariableSet("ORB_STATE",    (double)STATE_WAITING);

   LogInfo("Уровни сброшены — начало нового торгового дня");
}

#endif // LEVELS_MQH
