//+------------------------------------------------------------------+
//|                                               TSLA_ORB_v1.mq5   |
//|           TSLA Pre-Market ORB Level Break EA — v1.9              |
//|                                                                  |
//|  Стратегия: пробой уровней последней 5M свечи премаркета         |
//|  Свеча:     09:25–09:30 ET (13:25–13:30 / 14:25–14:30 UTC)      |
//|  Окно:      09:30–10:00 ET (30 минут)                            |
//|  EOD:       15:50 ET принудительное закрытие                     |
//|  Брокер:    Capital.com MT5, Hedging, ContractSize=1              |
//+------------------------------------------------------------------+
#property copyright "TSLA ORB EA v1.9"
#property version   "1.90"

#include "Logger.mqh"
#include "Levels.mqh"
#include "Risk.mqh"
#include "Entry.mqh"
#include "Position.mqh"

//+------------------------------------------------------------------+
//|  Входные параметры (раздел 6.3)                                  |
//+------------------------------------------------------------------+
input string   InpSymbol              = "TSLA";     // Торговый инструмент
input double   InpLeverage            = 20.0;       // Плечо (1:N) для расчёта лота
input double   InpEntryOffset         = 0.50;       // Отступ от уровня для входа ($)
input double   InpTakeProfit          = 6.00;       // TP в USD от цены входа
input double   InpBreakevenThreshold  = 1.50;       // Движение для переноса SL в BE ($)
input int      InpMaxSlippage         = 30;         // Макс. слиппаж в пунктах
input int      InpRetryDelay          = 500;        // Задержка повтора в мс
input int      InpETOffset            = -4;         // Смещение ET вручную (если AutoDST=false)
input bool     InpAutoDST             = true;       // Авто-определение летнего/зимнего ET (US DST)
input double   InpMaxDailyLossPercent = 2.0;        // Дневной лимит убытка (0=откл.)
input double   InpMaxDrawdownPercent  = 0.0;        // Макс. просадка (0=откл.)
// --- Месячный риск-менеджмент (v1.7) ---
input double   InpTradingRatio        = 0.7143;     // Доля баланса для торговли (71.43%)
input double   InpMaxLossPercent      = 28.5;       // Макс. потеря от StartBalance (%)
input double   InpStartBalance        = 0.0;        // Стартовый баланс периода (0=авто)
input double   InpSpikeFilterThreshold= 2.00;       // Фильтр спайков в USD (0=откл.)
input double   InpBasePrice           = 400.00;     // Эталонная цена $ для динамических параметров
input bool     InpUseDynamicParams    = true;       // Динамический EntryOffset/SL/TP (v1.6)
input int      InpMagic               = 20250101;   // Magic number EA
input bool     InpEnablePush          = true;       // Push-уведомления
input bool     InpEnableEmail         = false;      // Email-уведомления
input bool     InpEnableSound         = true;       // Звуковые алерты
input ENUM_LOG_LEVEL InpLogLevel      = LOG_INFO;   // Уровень детализации лога

//+------------------------------------------------------------------+
//|  Внутренние переменные главного модуля                           |
//+------------------------------------------------------------------+
double   g_initialBalance    = 0.0;    // Баланс на момент запуска EA (для MaxDrawdown)
bool     g_firstEntryTick    = true;   // Флаг первого тика в окне входа (gap-детектор)
bool     g_inEntryWindow     = false;  // Текущий статус: находимся в окне входа
int      g_etOffset          = -4;     // Эффективное смещение ET: обновляется при запуске и смене дня

void UpdateETOffset()
{
   g_etOffset = InpAutoDST ? CalcUSETOffset(TimeTradeServer()) : InpETOffset;
   LogInfo(StringFormat("ET смещение: %+d (%s)",
                         g_etOffset, g_etOffset == -4 ? "EDT (лето)" : "EST (зима)"));
}

//+------------------------------------------------------------------+
//|  OnInit — инициализация EA                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- 1. Проверка типа счёта (Capital.com BAH = Hedging)
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
      != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[TSLA_ORB] ОШИБКА: требуется Hedging-счёт (ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)");
      return INIT_FAILED;
   }

   //--- 2. Инициализация логгера
   InitLogger("TSLA_ORB", InpLogLevel, InpEnablePush, InpEnableEmail, InpEnableSound);

   //--- 2a. Символ EA — используется в функциях управления позицией
   g_eaSymbol = InpSymbol;

   //--- 3. Фиксируем начальный баланс для MaxDrawdown
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- 4. Инициализация риск-модуля (восстановление из GV)
   InitRisk(InpMagic);

   //--- 4a. Инициализация месячного риск-менеджмента (v1.7)
   InitMonthlyRisk(InpStartBalance, InpMaxLossPercent, InpTradingRatio);

   //--- 5. Инициализация модуля позиции (восстановление EntryPrice, BE)
   InitPosition(InpMagic);

   //--- 6. Определение смещения ET + инициализация модуля уровней (сценарии позднего запуска 7.4)
   UpdateETOffset();
   bool hasPosition = (PositionsTotalByMagic(InpMagic) > 0);
   InitLevels(InpSymbol, g_etOffset, hasPosition, InpUseDynamicParams, InpBasePrice,
              InpTradingRatio, InpLeverage);

   //--- 7. Информационный лог запуска
   LogInfo(StringFormat("EA запущен | Инструмент=%s  Баланс=%.2f  "
                         "Leverage=1:%.0f  TradingRatio=%.4f  DynParams=%s(Base=$%.2f)  "
                         "EntryOffset=%.2f  TP=%.2f  BE=%.2f  ETOffset=%+d  AutoDST=%s  Magic=%d  "
                         "StartBalance=%.2f  StopLevel=%.2f  TradingCapital=%.2f",
                         InpSymbol,
                         g_initialBalance,
                         InpLeverage,
                         InpTradingRatio,
                         InpUseDynamicParams ? "ON" : "OFF",
                         InpBasePrice,
                         InpEntryOffset,
                         InpTakeProfit,
                         InpBreakevenThreshold,
                         g_etOffset,
                         InpAutoDST ? "ON" : "OFF",
                         InpMagic,
                         g_startBalance,
                         g_stopLevel,
                         g_initialBalance * InpTradingRatio));

   //--- 8. Установка таймера для периодических задач (каждую секунду)
   EventSetTimer(1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  OnDeinit — завершение EA                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   string reasonStr;
   switch(reason)
   {
      case REASON_REMOVE:    reasonStr = "удалён с графика";       break;
      case REASON_CHARTCLOSE:reasonStr = "закрыт график";          break;
      case REASON_RECOMPILE: reasonStr = "перекомпиляция";         break;
      case REASON_PARAMETERS:reasonStr = "изменены параметры";     break;
      case REASON_ACCOUNT:   reasonStr = "смена счёта";            break;
      default:               reasonStr = StringFormat("код %d", reason); break;
   }

   LogInfo(StringFormat("EA остановлен | Причина: %s", reasonStr));
}

//+------------------------------------------------------------------+
//|  OnTick — главный цикл обработки тиков                          |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- 0a. Месячный стоп-уровень (v1.7): блокируем новые сделки навсегда до перезапуска
   //        EOD-закрытие открытых позиций продолжает работать через OnTimer независимо
   if(!CheckMonthlyStopLevel())
      return;

   //--- 0b. MaxDrawdown: останавливаем EA при превышении просадки (раздел 5.4)
   if(!CheckDrawdown(InpMaxDrawdownPercent, g_initialBalance))
   {
      ExpertRemove();
      return;
   }

   //--- 1. Детектор смены дня (00:00 GMT → сброс состояния, раздел 5.2)
   if(CheckNewDay(InpMagic))
   {
      g_inEntryWindow  = false;
      g_firstEntryTick = true;
      UpdateETOffset();
   }

   //--- 2. Фиксация ORB-уровней в момент закрытия свечи 09:25–09:30 ET
   ProcessLevelTick(InpSymbol, g_etOffset, InpUseDynamicParams, InpBasePrice,
                    InpTradingRatio, InpLeverage);

   //--- 3. Нет смысла продолжать если советник отключён на сегодня
   if(g_eaState == STATE_DISABLED_TODAY)
      return;

   //--- 3a. Активный порог Breakeven: динамический (v1.9) или фиксированный
   double activeBEThreshold = (InpUseDynamicParams && g_dynReady)
                              ? g_dynBreakeven : InpBreakevenThreshold;

   //--- 4. Управление открытой позицией
   if(g_eaState == STATE_IN_TRADE || PositionsTotalByMagic(InpMagic) > 0)
   {
      // 4a. Детектор закрытия позиции брокером (SL/TP)
      CheckPositionClosed(InpSymbol, InpMagic);

      // 4b. Breakeven (однократно, только если позиция ещё открыта)
      if(g_eaState == STATE_IN_TRADE)
         CheckBreakeven(InpSymbol, InpMagic, activeBEThreshold);

      // 4c. EOD принудительное закрытие в 15:50 ET
      CheckEodClose(InpSymbol, InpMagic, g_etOffset);

      // 4d. Аварийное закрытие если позиция осталась overnight
      CheckOvernightClose(InpSymbol, InpMagic);

      return;
   }

   //--- 5. Проверка истечения окна входа (раздел 4.3)
   CheckEntryWindowExpiry(g_etOffset);

   //--- 6. Логика входа (только если уровни зафиксированы)
   if(g_eaState != STATE_LEVELS_SET)
      return;

   //--- 6b. Управление флагом первого тика в окне входа (gap-детектор)
   bool nowInWindow = IsInEntryWindow(g_etOffset);
   if(nowInWindow && !g_inEntryWindow)
   {
      // Вошли в окно входа — следующий тик будет первым
      g_inEntryWindow  = true;
      g_firstEntryTick = true;
   }
   if(!nowInWindow && g_inEntryWindow)   // N10: только при переходе ИЗ окна, не каждый тик
   {
      g_inEntryWindow  = false;
      g_firstEntryTick = true;
   }

   //--- 6c. Выбор активных параметров: динамические или фиксированные (v1.6)
   double activeEntryOffset = (InpUseDynamicParams && g_dynReady)
                              ? g_dynEntryOffset : InpEntryOffset;
   double activeTakeProfit  = (InpUseDynamicParams && g_dynReady)
                              ? g_dynTP : InpTakeProfit;

   //--- 6d. Лот рассчитан при фиксации ORB-свечи (v1.8: плечо 1:N от TradingCapital)
   double lot = g_lotSize;
   if(lot <= 0.0)
   {
      LogError("g_lotSize=0 — цена ORB свечи недоступна, вход заблокирован на сегодня");
      g_eaState = STATE_DISABLED_TODAY;
      GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
      return;
   }

   //--- 6e. Попытка входа
   // FIX BUG 2: передаём InpMaxDailyLossPercent в ProcessEntryTick
   ulong ticket = ProcessEntryTick(InpSymbol,
                                    g_etOffset,
                                    activeEntryOffset,
                                    lot,
                                    activeTakeProfit,
                                    InpMaxDailyLossPercent,   // FIX BUG 2
                                    InpMaxSlippage,
                                    InpRetryDelay,
                                    InpMagic,
                                    InpSpikeFilterThreshold,
                                    g_firstEntryTick);

   //--- 6f. Немедленная пост-обработка после открытия (FIX БАГ 1 + БАГ 2)
   //  Вызываем OnPositionOpened сразу — иначе CheckBreakeven на следующем тике
   //  использует g_entryPrice от вчерашней сделки и срабатывает некорректно
   if(ticket > 0)
      OnPositionOpened(InpSymbol, InpMagic, activeTakeProfit, activeEntryOffset);

   // После первого тика в окне сбрасываем флаг
   if(g_firstEntryTick && nowInWindow)
      g_firstEntryTick = false;
}

//+------------------------------------------------------------------+
//|  OnTimer — периодические задачи (каждую секунду)                 |
//|  Используется для надёжного детектирования EOD                   |
//|  когда тики могут приходить редко                                |
//+------------------------------------------------------------------+
void OnTimer()
{
   // N14: сброс дня и через таймер — не ждём первого тика
   if(CheckNewDay(InpMagic))
   {
      g_inEntryWindow  = false;
      g_firstEntryTick = true;
      UpdateETOffset();
   }

   if(g_eaState == STATE_IN_TRADE || PositionsTotalByMagic(InpMagic) > 0)
   {
      CheckPositionClosed(InpSymbol, InpMagic);
      if(g_eaState == STATE_IN_TRADE)
      {
         double activeBEThreshold = (InpUseDynamicParams && g_dynReady)
                                    ? g_dynBreakeven : InpBreakevenThreshold;
         CheckBreakeven(InpSymbol, InpMagic, activeBEThreshold);
      }
      CheckEodClose(InpSymbol, InpMagic, g_etOffset);
      CheckOvernightClose(InpSymbol, InpMagic);
   }
   else
   {
      // БАГ 1 FIX: фиксируем уровни через таймер если тик в минуту 13:30 не пришёл
      ProcessLevelTick(InpSymbol, g_etOffset, InpUseDynamicParams,
                       InpBasePrice, InpTradingRatio, InpLeverage);
      CheckEntryWindowExpiry(g_etOffset);
   }
}

//+------------------------------------------------------------------+
//|  OnTradeTransaction — реакция на закрытие позиции (SL/TP)        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // Интересуют только сделки типа OUT (закрытие позиции)
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket))
   {
      LogWarning(StringFormat("OnTradeTransaction: HistoryDealSelect(%I64u) failed — PnL лог потерян", dealTicket));
      return;
   }
   if((int)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagic) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT) return;

   // Позиция закрыта — CheckPositionClosed обработает на следующем тике,
   // но логируем немедленно для точного времени
   double pnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
              + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
              + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

   ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
   string reasonStr = (reason == DEAL_REASON_SL)   ? "SL"  :
                      (reason == DEAL_REASON_TP)   ? "TP"  :
                      (reason == DEAL_REASON_EXPERT)? "EA" : "другое";

   LogInfo(StringFormat("Сделка закрыта [%s] | PnL=%.2f  Deal#%I64u",
                         reasonStr, pnl, dealTicket));
}
