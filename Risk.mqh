//+------------------------------------------------------------------+
//|                                                         Risk.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v1.9              |
//|           Модуль: расчёт лота, дневной лимит, сброс состояния    |
//|                                                                  |
//|  Функции:                                                        |
//|    • CalcOrbLot()            — см. Levels.mqh (лот от ORB-цены, v1.8)  |
//|    • CheckDailyLoss()        — проверка дневного лимита убытка        |
//|    • CheckDrawdown()         — проверка максимальной просадки          |
//|    • CheckNewDay()           — обнаружение смены даты и сброс дня     |
//|    • PositionsTotalByMagic() — количество открытых позиций EA          |
//|    • InitMonthlyRisk()       — инициализация месячного риск-менеджмента|
//|    • CheckMonthlyStopLevel() — проверка месячного стоп-уровня (v1.7)  |
//+------------------------------------------------------------------+
#ifndef RISK_MQH
#define RISK_MQH

#include "Logger.mqh"
#include "Levels.mqh"   // Нужен ResetLevels(), ENUM_EA_STATE, g_eaState

//+------------------------------------------------------------------+
//|  Разделяемые переменные риск-модуля                              |
//+------------------------------------------------------------------+

// --- Месячный риск-менеджмент (v1.7) ---
double   g_startBalance     = 0.0;   // Стартовый баланс периода (фиксируется при запуске)
double   g_stopLevel        = 0.0;   // Уровень остановки EA (StartBalance × (1 - MaxLoss%))
double   g_tradingRatio     = 1.0;   // Доля баланса для расчёта торгового капитала
bool     g_stopLevelReached = false; // Флаг: стоп-уровень достигнут, новые сделки заблокированы
bool     g_stopLevelWarned  = false; // Флаг: предупреждение о приближении к стоп-уровню отправлено

// --- Дневные переменные ---
double   g_dayStartBalance  = 0.0;   // Баланс на 00:00 GMT текущего дня
datetime g_lastTradeDate    = 0;     // Дата последнего торгового дня (для детектора смены)
bool     g_dailyTradeDone   = false; // Флаг: сделка сегодня уже была
bool     g_beDone           = false; // Флаг: Breakeven уже перенесён
bool     g_levelALong       = false; // Флаг LEVEL_A для лонга (пробой PRE_HIGH)
bool     g_levelAShort      = false; // Флаг LEVEL_A для шорта (пробой PRE_LOW)

// Перенесено из Position.mqh — чтобы ResetDailyState() мог сбрасывать каждый день
double   g_entryPrice       = 0.0;   // Фактическая цена входа (из PositionGetDouble)
bool     g_positionWasOpen  = false; // Флаг для детектора закрытия брокером
int      g_eodCloseAttempts = 0;     // Счётчик попыток EOD-закрытия (BUG 12)

#define EOD_MAX_ATTEMPTS 10          // Лимит попыток EOD-закрытия

// Символ EA — устанавливается в OnInit, используется при отправке ордеров
string   g_eaSymbol         = "";

//+------------------------------------------------------------------+
//|  Проверка наличия открытой позиции (Hedging: по POSITION_MAGIC)  |
//|  GetPositionTicketByMagic() возвращает тикет для select/close    |
//+------------------------------------------------------------------+
int PositionsTotalByMagic(int magic)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && (int)PositionGetInteger(POSITION_MAGIC) == magic)
         count++;
   }
   return count;
}

ulong GetPositionTicketByMagic(int magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return ticket;
   }
   return 0;
}

//+------------------------------------------------------------------+
//|  Проверка дневного лимита убытка перед OrderSend()               |
//|                                                                  |
//|  Возвращает true  — торговать можно                              |
//|  Возвращает false — лимит достигнут, EA заблокирован             |
//|                                                                  |
//|  При maxDailyLossPercent = 0 — проверка отключена (раздел 5.2)  |
//+------------------------------------------------------------------+
bool CheckDailyLoss(double maxDailyLossPercent)
{
   if(maxDailyLossPercent <= 0.0)
      return true;   // Лимит отключён

   if(g_dayStartBalance <= 0.0)
      return true;   // Баланс ещё не зафиксирован

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentLoss    = g_dayStartBalance - currentBalance;
   double lossLimit      = g_dayStartBalance * maxDailyLossPercent / 100.0;

   if(currentLoss >= lossLimit)
   {
      AlertDailyLossLimit(currentLoss, maxDailyLossPercent);
      g_eaState = STATE_DISABLED_TODAY;
      GlobalVariableSet("ORB_STATE",      (double)STATE_DISABLED_TODAY);
      GlobalVariableSet("ORB_TRADE_DONE", 1.0);
      g_dailyTradeDone = true;
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|  Проверка максимальной просадки (MaxDrawdownPercent)             |
//|                                                                  |
//|  База: баланс первого запуска EA (g_dayStartBalance на OnInit)   |
//|  При достижении — EA полностью останавливается (раздел 5.4)      |
//|  Возвращает false если советник должен остановиться              |
//+------------------------------------------------------------------+
bool CheckDrawdown(double maxDrawdownPercent, double initialBalance)
{
   if(maxDrawdownPercent <= 0.0 || initialBalance <= 0.0)
      return true;   // Отключено

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdown       = (initialBalance - currentBalance) / initialBalance * 100.0;

   if(drawdown >= maxDrawdownPercent)
   {
      string msg = StringFormat("СТОП: максимальная просадка %.1f%% достигнута "
                                "(порог %.1f%%) — требуется ручной перезапуск",
                                drawdown, maxDrawdownPercent);
      LogError(msg);
      SendEaAlert(msg, true, true, true);
      return false;   // Сигнал главному модулю выполнить ExpertRemove()
   }

   return true;
}

//+------------------------------------------------------------------+
//|  Сброс всех дневных переменных и GlobalVariables                 |
//|  Вызывается при обнаружении смены даты (00:00 GMT)               |
//+------------------------------------------------------------------+
void ResetDailyState(int magic)
{
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyTradeDone  = false;
   g_beDone          = false;
   g_levelALong      = false;
   g_levelAShort     = false;
   // Не сбрасываем g_entryPrice и g_positionWasOpen если позиция открыта overnight
   // (CheckBreakeven и EOD-закрытие нуждаются в g_entryPrice для корректной работы)
   if(PositionsTotalByMagic(magic) == 0)
   {
      g_entryPrice      = 0.0;
      g_positionWasOpen = false;
   }
   g_eodCloseAttempts  = 0;

   // Сбрасываем GlobalVariables (раздел 5.2, 6.2)
   GlobalVariableSet("ORB_TRADE_DONE",    0.0);
   GlobalVariableSet("ORB_BE_DONE",       0.0);
   GlobalVariableSet("ORB_ENTRY_PRICE",   0.0);
   GlobalVariableSet("ORB_LEVEL_A_LONG",  0.0);   // БАГ 3 FIX
   GlobalVariableSet("ORB_LEVEL_A_SHORT", 0.0);   // БАГ 3 FIX
   GlobalVariableSet("ORB_ORDER_LOCK",    0.0);   // БАГ 13 FIX: сброс лока при смене дня
   // БАГ 6 FIX: пишем полночь (совпадает с форматом CheckNewDay) для корректного gvIsToday
   MqlDateTime midnightStruct;
   TimeToStruct(TimeTradeServer(), midnightStruct);
   midnightStruct.hour = 0; midnightStruct.min = 0; midnightStruct.sec = 0;
   GlobalVariableSet("ORB_LAST_DATE", (double)(long)StructToTime(midnightStruct));

   // Сбрасываем уровни через Levels.mqh
   ResetLevels();

   AlertNewDay(TimeTradeServer(), g_dayStartBalance);
}

//+------------------------------------------------------------------+
//|  Детектор смены торгового дня — вызывается в OnTick()            |
//|                                                                  |
//|  Сравнивает текущую дату сервера с g_lastTradeDate               |
//|  При смене — вызывает ResetDailyState() и обновляет дату         |
//|  Сброс происходит при переходе через 00:00 GMT (сервер UTC+0)    |
//+------------------------------------------------------------------+
bool CheckNewDay(int magic)
{
   MqlDateTime nowStruct;
   TimeToStruct(TimeTradeServer(), nowStruct);

   // Обнуляем время — оставляем только дату для сравнения
   nowStruct.hour = 0;
   nowStruct.min  = 0;
   nowStruct.sec  = 0;
   datetime todayDate = StructToTime(nowStruct);

   if(todayDate != g_lastTradeDate)
   {
      LogDebug(StringFormat("Смена даты: %s → %s",
                             TimeToString(g_lastTradeDate, TIME_DATE),
                             TimeToString(todayDate,       TIME_DATE)));
      g_lastTradeDate = todayDate;
      GlobalVariableSet("ORB_LAST_DATE", (double)(long)todayDate);
      ResetDailyState(magic);   // N11: передаём magic для проверки overnight позиции
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//|  Инициализация месячного риск-менеджмента (v1.7)                 |
//|                                                                  |
//|  startBalanceParam = 0 → берётся автоматически из AccountBalance |
//|  или восстанавливается из GlobalVariable если дата совпадает     |
//|                                                                  |
//|  Сохраняет StartBalance в ORB_START_BALANCE для восстановления   |
//|  при перезапуске в тот же день                                   |
//+------------------------------------------------------------------+
void InitMonthlyRisk(double startBalanceParam, double maxLossPercent, double tradingRatio)
{
   g_tradingRatio = tradingRatio;

   MqlDateTime nowStruct;
   TimeToStruct(TimeTradeServer(), nowStruct);
   nowStruct.hour = 0; nowStruct.min = 0; nowStruct.sec = 0;
   datetime today = StructToTime(nowStruct);

   double startBalance    = startBalanceParam;
   bool   samePeriodFromGV = false;   // true если startBalance восстановлен из GV того же периода

   if(startBalance <= 0.0)
   {
      // Попытка восстановить из GlobalVariable (тот же день)
      if(GlobalVariableCheck("ORB_START_BALANCE") && GlobalVariableCheck("ORB_START_BAL_DATE"))
      {
         double savedBalance = GlobalVariableGet("ORB_START_BALANCE");
         datetime savedDay   = (datetime)(long)GlobalVariableGet("ORB_START_BAL_DATE");
         if(savedBalance > 0.0 && savedDay == today)
         {
            startBalance    = savedBalance;
            samePeriodFromGV = true;
            LogInfo(StringFormat("StartBalance восстановлен из GV: %.2f", startBalance));
         }
      }
      if(startBalance <= 0.0)
      {
         startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         LogInfo(StringFormat("StartBalance = AccountBalance(): %.2f", startBalance));
      }
   }
   else
   {
      LogInfo(StringFormat("StartBalance задан вручную: %.2f", startBalance));
   }

   g_startBalance = startBalance;

   // maxLossPercent=0 означает "отключён" — аналогично maxDailyLossPercent=0 в CheckDailyLoss
   if(maxLossPercent <= 0.0)
   {
      g_stopLevel = 0.0;
      LogInfo("Месячный стоп-уровень отключён (MaxLossPercent=0)");
      GlobalVariableSet("ORB_START_BALANCE",  g_startBalance);
      GlobalVariableSet("ORB_START_BAL_DATE", (double)(long)today);
      return;
   }

   g_stopLevel = NormalizeDouble(startBalance * (1.0 - maxLossPercent / 100.0), 2);

   GlobalVariableSet("ORB_START_BALANCE",  g_startBalance);
   GlobalVariableSet("ORB_START_BAL_DATE", (double)(long)today);

   // БАГ B FIX: ORB_STOP_WARNED восстанавливаем только если это тот же торговый период.
   // При новом периоде (новый StartBalance) флаг должен сброситься — иначе предупреждение
   // о приближении к стоп-уровню не будет отправлено никогда в новом периоде.
   if(samePeriodFromGV && GlobalVariableCheck("ORB_STOP_WARNED"))
      g_stopLevelWarned = (GlobalVariableGet("ORB_STOP_WARNED") > 0.5);
   else
   {
      g_stopLevelWarned = false;
      GlobalVariableSet("ORB_STOP_WARNED",  0.0);
      GlobalVariableSet("ORB_STOP_REACHED", 0.0);   // новый период — сбрасываем и алерт-флаг
   }

   double tradingCapital = AccountInfoDouble(ACCOUNT_BALANCE) * tradingRatio;
   LogInfo(StringFormat("Месячный риск | StartBalance=%.2f  StopLevel=%.2f  "
                        "TradingCapital=%.2f  TradingRatio=%.4f  MaxLoss=%.1f%%  Warned=%s",
                        g_startBalance, g_stopLevel, tradingCapital, tradingRatio, maxLossPercent,
                        g_stopLevelWarned ? "true" : "false"));
}

//+------------------------------------------------------------------+
//|  Проверка месячного стоп-уровня — вызывается в OnTick()          |
//|                                                                  |
//|  Возвращает false если EA должен заблокировать новые сделки      |
//|  Открытые позиции НЕ закрываются (SL/TP брокера их защищают)     |
//|  После остановки требуется ручной перезапуск EA                  |
//+------------------------------------------------------------------+
bool CheckMonthlyStopLevel()
{
   if(g_stopLevel <= 0.0)
      return true;   // Не инициализирован — пропускаем

   if(g_stopLevelReached)
      return false;  // Уже достигнут — блокируем навсегда до перезапуска

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Предупреждение при прохождении 90% пути от StartBalance до StopLevel
   if(!g_stopLevelWarned && currentBalance > g_stopLevel)
   {
      double warningLevel = g_stopLevel + (g_startBalance - g_stopLevel) * 0.10;
      if(currentBalance <= warningLevel)
      {
         g_stopLevelWarned = true;
         GlobalVariableSet("ORB_STOP_WARNED", 1.0);   // БАГ 5 FIX: сохраняем для рестарта
         AlertStopLevelApproaching(currentBalance, g_stopLevel);
      }
   }

   if(currentBalance <= g_stopLevel)
   {
      g_stopLevelReached = true;
      // Инвалидируем GV дату — на следующем запуске EA возьмёт AccountBalance() как новый StartBalance,
      // а не восстановит старый, при котором стоп снова немедленно сработает
      GlobalVariableSet("ORB_START_BAL_DATE", 0.0);
      // БАГ C FIX: ORB_STOP_REACHED подавляет дублирующий алерт при рестарте.
      // Флаг сбрасывается в InitMonthlyRisk при новом периоде (samePeriodFromGV=false).
      bool alreadyNotified = (GlobalVariableCheck("ORB_STOP_REACHED") &&
                              GlobalVariableGet("ORB_STOP_REACHED") > 0.5);
      if(!alreadyNotified)
      {
         GlobalVariableSet("ORB_STOP_REACHED", 1.0);
         AlertStopLevelReached(currentBalance, g_stopLevel);
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|  Инициализация риск-модуля — вызывается из OnInit()              |
//|  Восстанавливает дневное состояние из GlobalVariables            |
//+------------------------------------------------------------------+
void InitRisk(int magic)
{
   // Фиксируем баланс на начало дня
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Устанавливаем текущую дату как базовую
   MqlDateTime nowStruct;
   TimeToStruct(TimeTradeServer(), nowStruct);
   nowStruct.hour = 0; nowStruct.min = 0; nowStruct.sec = 0;
   datetime today = StructToTime(nowStruct);
   g_lastTradeDate = today;

   // БАГ 2 FIX: восстанавливаем дневные флаги только если GV актуальны для СЕГОДНЯ.
   // Без этой проверки GV от вчера (EA остановился до полуночи) блокировали торговлю:
   // g_dailyTradeDone=true читался из устаревшего ORB_TRADE_DONE=1, а CheckNewDay
   // не срабатывал т.к. g_lastTradeDate уже установлен в today.
   bool gvIsToday = false;
   if(GlobalVariableCheck("ORB_LAST_DATE"))
   {
      datetime savedDate = (datetime)(long)GlobalVariableGet("ORB_LAST_DATE");
      gvIsToday = (savedDate == today);
   }

   if(gvIsToday)
   {
      if(GlobalVariableCheck("ORB_TRADE_DONE"))
         g_dailyTradeDone = (GlobalVariableGet("ORB_TRADE_DONE") > 0.5);

      if(GlobalVariableCheck("ORB_BE_DONE"))
         g_beDone = (GlobalVariableGet("ORB_BE_DONE") > 0.5);

      // БАГ 3 FIX: восстанавливаем LEVEL_A флаги (теряются при рестарте в окне входа)
      if(GlobalVariableCheck("ORB_LEVEL_A_LONG"))
         g_levelALong = (GlobalVariableGet("ORB_LEVEL_A_LONG") > 0.5);

      if(GlobalVariableCheck("ORB_LEVEL_A_SHORT"))
         g_levelAShort = (GlobalVariableGet("ORB_LEVEL_A_SHORT") > 0.5);
   }
   // Если GV устарели — все флаги остаются false (default), торговля разрешена
   // БАГ 13 FIX (часть 2): сбрасываем лок при старте если GV не сегодняшние
   if(!gvIsToday)
      GlobalVariableSet("ORB_ORDER_LOCK", 0.0);

   // Hedging: ищем позицию по POSITION_MAGIC
   ulong posTicket = GetPositionTicketByMagic(magic);
   if(posTicket > 0 && PositionSelectByTicket(posTicket))
   {
      double entryPrice = GlobalVariableCheck("ORB_ENTRY_PRICE")
                          ? GlobalVariableGet("ORB_ENTRY_PRICE") : 0.0;

      double posSL = PositionGetDouble(POSITION_SL);
      if(entryPrice > 0.0 && MathAbs(posSL - entryPrice) < 0.001)
      {
         g_beDone = true;
         LogInfo("Синхронизация BE: SL == EntryPrice → BE_DONE=true");
      }
   }

   LogInfo(StringFormat("Risk-модуль инициализирован | GV=%s  "
                        "Баланс дня: %.2f  TradeDone=%s  BeDone=%s  LevelA=%s/%s",
                        gvIsToday ? "сегодня" : "устарели",
                        g_dayStartBalance,
                        g_dailyTradeDone ? "true" : "false",
                        g_beDone         ? "true" : "false",
                        g_levelALong     ? "L" : "-",
                        g_levelAShort    ? "S" : "-"));
}

//+------------------------------------------------------------------+
//|  Четыре проверки перед OrderSend() (раздел 7.6)                  |
//|  Возвращает true — вход разрешён, false — вход заблокирован       |
//+------------------------------------------------------------------+
bool IsEntryAllowed(int magic, int etOffset)
{
   // 1. Сделка сегодня уже была
   if(g_dailyTradeDone)
   {
      LogDebug("Вход заблокирован: DAILY_TRADE_DONE=true");
      return false;
   }

   // 2. Уже есть открытая позиция
   if(PositionsTotalByMagic(magic) > 0)
   {
      LogDebug("Вход заблокирован: позиция уже открыта");
      return false;
   }

   // 3. Окно входа закрыто
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   int entryEnd = (9 - etOffset) + 1;   // 14 (лето) / 15 (зима)
   if(now.hour >= entryEnd)
   {
      LogDebug(StringFormat("Вход заблокирован: окно входа закрыто (%02d:00 сервер)",
                             entryEnd));
      return false;
   }

   // 4. EA отключён на сегодня
   if(g_eaState == STATE_DISABLED_TODAY)
   {
      LogDebug("Вход заблокирован: STATE_DISABLED_TODAY");
      return false;
   }

   return true;
}

#endif // RISK_MQH
