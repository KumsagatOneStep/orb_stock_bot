//+------------------------------------------------------------------+
//|                                                     Position.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v1.5              |
//|           Модуль: управление позицией (BE, TP-коррекция, EOD)    |
//|                                                                  |
//|  Функции:                                                        |
//|    • OnPositionOpened()   — коррекция TP по фактической цене     |
//|    • CheckBreakeven()     — перенос SL в безубыток               |
//|    • CheckEodClose()      — принудительное закрытие в 15:55 ET   |
//|    • CheckPositionClosed()— детектор закрытия SL/TP брокером     |
//+------------------------------------------------------------------+
#ifndef POSITION_MQH
#define POSITION_MQH

#include "Logger.mqh"
#include "Levels.mqh"
#include "Risk.mqh"

// g_entryPrice и g_positionWasOpen объявлены в Risk.mqh (сброс каждый день)

//+------------------------------------------------------------------+
//|  Вызывается сразу после открытия позиции                         |
//|  1. Читает фактическую цену входа                                |
//|  2. Пересчитывает и модифицирует TP от фактической цены          |
//|  3. Сохраняет EntryPrice в GlobalVariables                       |
//+------------------------------------------------------------------+
void OnPositionOpened(string symbol, int magic, double takeProfit)
{
   // FIX BUG 6: явный поиск и выбор позиции через PositionSelectByTicket
   // PositionSelect(symbol) в Hedging может выбрать чужую позицию на этом символе
   ulong ticket = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t) &&   // N1: select перед чтением MAGIC/SYMBOL
         (int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == symbol)
      {
         ticket = t;
         break;
      }
   }

   if(ticket == 0 || !PositionSelectByTicket(ticket))
   {
      LogError("OnPositionOpened: позиция не найдена");
      return;
   }

   // Фактическая цена исполнения (раздел 3.3, 3.4)
   g_entryPrice      = PositionGetDouble(POSITION_PRICE_OPEN);
   g_positionWasOpen = true;

   GlobalVariableSet("ORB_ENTRY_PRICE", g_entryPrice);

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Пересчёт TP от фактической цены входа
   double newTP;
   if(posType == POSITION_TYPE_BUY)
      newTP = g_entryPrice + takeProfit;
   else
      newTP = g_entryPrice - takeProfit;

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   // FIX БАГ 2: не отправляем модификацию если TP уже правильный (избегаем ошибки 4756)
   if(MathAbs(currentTP - newTP) < 0.001)
   {
      LogInfo(StringFormat("TP уже корректен | EntryPrice=%.2f  TP=%.2f",
                            g_entryPrice, newTP));
      return;
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = symbol;
   req.sl       = currentSL;
   req.tp       = newTP;
   req.position = PositionGetInteger(POSITION_TICKET);

   if(!OrderSend(req, res))
      LogWarning(StringFormat("TP не скорректирован: ошибка %d", GetLastError()));
   else
      LogInfo(StringFormat("TP скорректирован | EntryPrice=%.2f  TP=%.2f  SL=%.2f",
                            g_entryPrice, newTP, currentSL));
}

//+------------------------------------------------------------------+
//|  Проверка и перенос SL в безубыток — вызывается из OnTick()     |
//|  Только один раз: после переноса флаг g_beDone = true           |
//|                                                                  |
//|  LONG:  если (Bid - EntryPrice) >= BreakevenThreshold            |
//|           → SL = EntryPrice                                      |
//|  SHORT: если (EntryPrice - Ask) >= BreakevenThreshold            |
//|           → SL = EntryPrice                                      |
//+------------------------------------------------------------------+
void CheckBreakeven(string symbol, int magic, double breakevenThreshold)
{
   // Применяется только один раз
   if(g_beDone)
      return;

   if(breakevenThreshold <= 0.0)
      return;   // N5: breakevenThreshold=0 иначе BE срабатывал бы на каждом прибыльном тике

   if(g_entryPrice <= 0.0)
      return;

   // Выбираем позицию по Magic (Hedging — перебор)
   bool found = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;   // N2: select до MAGIC-фильтра
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      found = true;
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double profit_move;

      if(posType == POSITION_TYPE_BUY)
         profit_move = bid - g_entryPrice;
      else
         profit_move = g_entryPrice - ask;

      if(profit_move >= breakevenThreshold)
      {
         double oldSL = PositionGetDouble(POSITION_SL);
         double newSL = g_entryPrice;
         double curTP = PositionGetDouble(POSITION_TP);

         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action   = TRADE_ACTION_SLTP;
         req.symbol   = symbol;
         req.sl       = newSL;
         req.tp       = curTP;
         req.position = ticket;

         if(OrderSend(req, res) &&
            (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED))
         {
            g_beDone = true;
            GlobalVariableSet("ORB_BE_DONE", 1.0);
            AlertBreakeven(oldSL, newSL);
         }
         else
         {
            LogWarning(StringFormat("Breakeven не установлен: ошибка %d / retcode %d",
                                     GetLastError(), res.retcode));
         }
      }
      break;   // Только одна позиция EA в день
   }

   if(!found)
   {
      // Позиция закрылась (SL/TP) — обновим состояние
      g_positionWasOpen = false;
   }
}

//+------------------------------------------------------------------+
//|  Принудительное EOD-закрытие (раздел 4.2)                        |
//|  15:55 ET = 19:55 UTC (лето) / 20:55 UTC (зима)                  |
//|  Возвращает true если закрытие выполнено                          |
//+------------------------------------------------------------------+
bool CheckEodClose(string symbol, int magic, int etOffset)
{
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   // EOD: 15:55 ET → UTC
   // UTC = 15:55 - ETOffset = 15:55 + |ETOffset|
   // Лето (ETOffset=-4): 19:55 UTC
   // Зима (ETOffset=-5): 20:55 UTC
   int eodHour = 15 - etOffset;   // 15 - (-4) = 19, 15 - (-5) = 20
   int eodMin  = 55;

   if(now.hour < eodHour) return false;
   if(now.hour == eodHour && now.min < eodMin) return false;

   // BUG 12: ограничение числа попыток — не спамим ошибками если биржа закрыта
   if(g_eodCloseAttempts >= EOD_MAX_ATTEMPTS)
      return false;

   // Ищем позицию с нашим Magic
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;   // N4: select до MAGIC-фильтра (BUG A fix был неполным)
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      double pnl = PositionGetDouble(POSITION_PROFIT);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_DEAL;
      req.symbol    = symbol;
      req.volume    = PositionGetDouble(POSITION_VOLUME);
      req.deviation = 50;   // Широкий слиппаж для гарантированного закрытия
      req.magic     = magic;
      req.position  = ticket;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)
      {
         req.type  = ORDER_TYPE_SELL;
         req.price = SymbolInfoDouble(symbol, SYMBOL_BID);
      }
      else
      {
         req.type  = ORDER_TYPE_BUY;
         req.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      }
      req.type_filling = ORDER_FILLING_IOC;

      if(OrderSend(req, res) &&
         (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED))
      {
         g_dailyTradeDone  = true;
         g_eaState         = STATE_DISABLED_TODAY;
         g_positionWasOpen = false;

         GlobalVariableSet("ORB_TRADE_DONE", 1.0);
         GlobalVariableSet("ORB_STATE",      (double)STATE_DISABLED_TODAY);

         AlertEodClose(pnl);
         return true;
      }
      else
      {
         g_eodCloseAttempts++;
         LogError(StringFormat("EOD закрытие не удалось (попытка %d/%d): retcode=%d  ошибка=%d",
                                g_eodCloseAttempts, EOD_MAX_ATTEMPTS, res.retcode, GetLastError()));
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//|  Детектор закрытия позиции брокером (SL или TP)                  |
//|  Вызывается из OnTick(), пока STATE=IN_TRADE                     |
//|                                                                  |
//|  Если позиция исчезла → читаем PnL из истории сделок             |
//|  и переводим в DISABLED_TODAY                                    |
//+------------------------------------------------------------------+
void CheckPositionClosed(string symbol, int magic)
{
   if(!g_positionWasOpen)
      return;

   // Проверяем, есть ли ещё позиция
   bool stillOpen = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t <= 0) continue;
      if(!PositionSelectByTicket(t)) continue;   // BUG 9: явный выбор перед чтением POSITION_MAGIC
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
      {
         stillOpen = true;
         break;
      }
   }

   if(stillOpen)
      return;

   // Позиция закрылась — ищем результат в истории за последние сутки
   HistorySelect(TimeTradeServer() - 86400, TimeTradeServer());   // BUG 5: TimeCurrent() != серверное время

   double totalPnl = 0.0;
   string closeReason = "SL/TP";

   int dealsTotal = HistoryDealsTotal();
   for(int i = dealsTotal - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= 0) continue;
      if(!HistoryDealSelect(dealTicket)) continue;   // BUG E: без select все Get* читают из предыдущей сделки
      if((int)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != magic) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != symbol) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      totalPnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
               + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
               + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

      // Определяем причину: SL или TP
      ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
      if(reason == DEAL_REASON_SL)       closeReason = "SL";
      else if(reason == DEAL_REASON_TP)  closeReason = "TP";
      break;
   }

   g_positionWasOpen = false;
   g_eaState         = STATE_DISABLED_TODAY;
   g_dailyTradeDone  = true;

   GlobalVariableSet("ORB_TRADE_DONE", 1.0);
   GlobalVariableSet("ORB_STATE",      (double)STATE_DISABLED_TODAY);

   AlertPositionClosed(closeReason, totalPnl);
}

//+------------------------------------------------------------------+
//|  Инициализация модуля позиции — вызывается из OnInit()           |
//+------------------------------------------------------------------+
void InitPosition(int magic)
{
   // Восстанавливаем EntryPrice из GV
   if(GlobalVariableCheck("ORB_ENTRY_PRICE"))
   {
      double saved = GlobalVariableGet("ORB_ENTRY_PRICE");
      if(saved > 0.0)
         g_entryPrice = saved;
   }

   // Проверяем, есть ли сейчас открытая позиция
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t <= 0) continue;
      if(!PositionSelectByTicket(t)) continue;   // BUG B: явный выбор перед чтением свойств
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      g_positionWasOpen = true;

      // Если EntryPrice не восстановлен из GV — берём из позиции
      if(g_entryPrice <= 0.0)
         g_entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      LogInfo(StringFormat("Position-модуль: позиция восстановлена | "
                            "EntryPrice=%.2f  BeDone=%s",
                            g_entryPrice,
                            g_beDone ? "true" : "false"));
      break;
   }
}

#endif // POSITION_MQH
