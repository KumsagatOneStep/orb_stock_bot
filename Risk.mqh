//+------------------------------------------------------------------+
//|                                                         Risk.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v1.5              |
//|           Модуль: расчёт лота, дневной лимит, сброс состояния    |
//|                                                                  |
//|  Функции:                                                        |
//|    • CalcLotSize()      — фиксированный лот или % от баланса     |
//|    • CheckDailyLoss()   — проверка дневного лимита убытка        |
//|    • CheckDrawdown()    — проверка максимальной просадки          |
//|    • CheckNewDay()      — обнаружение смены даты и сброс дня     |
//|    • PositionsTotalByMagic() — количество открытых позиций EA    |
//+------------------------------------------------------------------+
#ifndef RISK_MQH
#define RISK_MQH

#include "Logger.mqh"
#include "Levels.mqh"   // Нужен ResetLevels(), ENUM_EA_STATE, g_eaState

//+------------------------------------------------------------------+
//|  Разделяемые переменные риск-модуля                              |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|  Подсчёт открытых позиций с нашим Magic number                   |
//+------------------------------------------------------------------+
int PositionsTotalByMagic(int magic)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0)
         if((int)PositionGetInteger(POSITION_MAGIC) == magic)
            count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//|  Расчёт размера лота                                             |
//|                                                                  |
//|  Режим 1 (UseFixedLot=true):  возвращает FixedLot               |
//|  Режим 2 (UseFixedLot=false): RiskPercent % от баланса          |
//|    LotSize = (Balance * RiskPct/100) / (EntryOffset * 100)       |
//|                                                                  |
//|  Результат всегда зажат в [0.01, 10.00] с шагом 0.01            |
//+------------------------------------------------------------------+
double CalcLotSize(bool   useFixedLot,
                   double fixedLot,
                   double riskPercent,
                   double entryOffset)
{
   double lotSize;

   if(useFixedLot)
   {
      lotSize = fixedLot;
   }
   else
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0.0 || entryOffset <= 0.0)
      {
         LogError("CalcLotSize: некорректный баланс или EntryOffset — используем MinLot");
         return 0.01;
      }
      // ContractSize = 100 акций, MaxRisk в USD / (смещение × 100)
      lotSize = (balance * riskPercent / 100.0) / (entryOffset * 100.0);
   }

   // Округление до шага 0.01
   lotSize = MathFloor(lotSize / 0.01) * 0.01;

   // Зажимаем в допустимые пределы (раздел 7.8)
   if(lotSize > 10.0)
   {
      LogWarning(StringFormat("LotSize %.2f превышает MaxLot=10.00 — обрезан", lotSize));
      lotSize = 10.0;
   }
   lotSize = MathMax(lotSize, 0.01);

   // FIX BUG 7: DEBUG чтобы не спамить в логи на каждом тике
   LogDebug(StringFormat("Рассчитан лот: %.2f (%s)",
                          lotSize, useFixedLot ? "фиксированный" : "авто"));
   return lotSize;
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
void ResetDailyState()
{
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyTradeDone  = false;
   g_beDone          = false;
   g_levelALong      = false;
   g_levelAShort     = false;
   // FIX БАГ 1: сброс цены входа каждый день — иначе BE использует цену вчерашней сделки
   g_entryPrice        = 0.0;
   g_positionWasOpen   = false;
   g_eodCloseAttempts  = 0;   // BUG 12: сброс счётчика EOD-попыток

   // Сбрасываем GlobalVariables (раздел 5.2, 6.2)
   GlobalVariableSet("ORB_TRADE_DONE",  0.0);
   GlobalVariableSet("ORB_BE_DONE",     0.0);
   GlobalVariableSet("ORB_ENTRY_PRICE", 0.0);
   GlobalVariableSet("ORB_LAST_DATE",   (double)(long)TimeTradeServer());

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
void CheckNewDay()
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
      GlobalVariableSet("ORB_LAST_DATE", (double)(long)todayDate);   // BUG 7: (int) обрезал 64-bit datetime
      ResetDailyState();
   }
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
   g_lastTradeDate = StructToTime(nowStruct);

   // Восстанавливаем дневные флаги из GlobalVariables (раздел 7.3)
   if(GlobalVariableCheck("ORB_TRADE_DONE"))
      g_dailyTradeDone = (GlobalVariableGet("ORB_TRADE_DONE") > 0.5);

   if(GlobalVariableCheck("ORB_BE_DONE"))
      g_beDone = (GlobalVariableGet("ORB_BE_DONE") > 0.5);

   // FIX BUG 4: явный выбор позиции перед PositionGetDouble
   if(PositionsTotalByMagic(magic) > 0)
   {
      double entryPrice = GlobalVariableCheck("ORB_ENTRY_PRICE")
                          ? GlobalVariableGet("ORB_ENTRY_PRICE") : 0.0;

      // Выбираем позицию по Magic явно через PositionSelectByTicket
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong t = PositionGetTicket(i);
         if(t > 0 && (int)PositionGetInteger(POSITION_MAGIC) == magic)
         {
            if(PositionSelectByTicket(t))
            {
               double posSL = PositionGetDouble(POSITION_SL);
               if(entryPrice > 0.0 && MathAbs(posSL - entryPrice) < 0.001)
               {
                  g_beDone = true;
                  LogInfo("Синхронизация BE: SL == EntryPrice → BE_DONE=true");
               }
            }
            break;
         }
      }
   }

   LogInfo(StringFormat("Risk-модуль инициализирован | "
                        "Баланс дня: %.2f  TradeDone=%s  BeDone=%s",
                        g_dayStartBalance,
                        g_dailyTradeDone ? "true" : "false",
                        g_beDone         ? "true" : "false"));
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
