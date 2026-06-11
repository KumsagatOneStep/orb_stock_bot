//+------------------------------------------------------------------+
//|                                                     Position.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v1.9              |
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
void OnPositionOpened(string symbol, int magic, double takeProfit, double entryOffset)
{
   // Hedging: ищем позицию по POSITION_MAGIC
   ulong posTicket = GetPositionTicketByMagic(magic);
   if(!PositionSelectByTicket(posTicket))
   {
      LogError("OnPositionOpened: позиция не найдена");
      return;
   }

   // Фактическая цена исполнения (раздел 3.3, 3.4)
   g_entryPrice      = PositionGetDouble(POSITION_PRICE_OPEN);
   g_positionWasOpen = true;

   GlobalVariableSet("ORB_ENTRY_PRICE", g_entryPrice);

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Пересчёт SL и TP от фактической цены входа — сохраняет R:R при слиппаже
   double newSL, newTP;
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = g_entryPrice - entryOffset;
      newTP = g_entryPrice + takeProfit;
   }
   else
   {
      newSL = g_entryPrice + entryOffset;
      newTP = g_entryPrice - takeProfit;
   }

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   // Не отправляем модификацию если оба уровня уже корректны (избегаем ошибки 4756)
   bool slOk = (MathAbs(currentSL - newSL) < 0.001);
   bool tpOk = (MathAbs(currentTP - newTP) < 0.001);
   if(slOk && tpOk)
   {
      LogInfo(StringFormat("SL/TP уже корректны | EntryPrice=%.2f  SL=%.2f  TP=%.2f",
                            g_entryPrice, newSL, newTP));
      return;
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = symbol;
   req.sl       = newSL;
   req.tp       = newTP;
   req.position = PositionGetInteger(POSITION_TICKET);   // Hedging: SLTP требует ticket позиции

   if(!OrderSend(req, res))
      LogWarning(StringFormat("SL/TP не скорректированы: ошибка %d", GetLastError()));
   else
      LogInfo(StringFormat("SL/TP скорректированы | EntryPrice=%.2f  SL: %.2f→%.2f  TP: %.2f→%.2f",
                            g_entryPrice, currentSL, newSL, currentTP, newTP));
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

   // Hedging: ищем позицию по POSITION_MAGIC
   ulong posTicket = GetPositionTicketByMagic(magic);
   if(!PositionSelectByTicket(posTicket))
   {
      g_positionWasOpen = false;
      return;
   }

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
      double oldSL  = PositionGetDouble(POSITION_SL);
      double newSL  = g_entryPrice;
      double curTP  = PositionGetDouble(POSITION_TP);
      ulong  ticket = PositionGetInteger(POSITION_TICKET);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = symbol;
      req.sl       = newSL;
      req.tp       = curTP;
      req.position = ticket;   // Hedging: SLTP требует ticket позиции

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
   int eodMin  = 50;

   if(now.hour < eodHour) return false;
   if(now.hour == eodHour && now.min < eodMin) return false;

   // BUG 12: ограничение числа попыток — не спамим ошибками если биржа закрыта
   if(g_eodCloseAttempts >= EOD_MAX_ATTEMPTS)
      return false;

   // Hedging: ищем позицию по POSITION_MAGIC
   ulong posTicket = GetPositionTicketByMagic(magic);
   if(!PositionSelectByTicket(posTicket))
      return false;

   double pnl    = PositionGetDouble(POSITION_PROFIT);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = symbol;
   req.volume    = volume;
   req.deviation = 50;   // Широкий слиппаж для гарантированного закрытия
   req.magic     = magic;
   req.position  = posTicket;

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
   req.type_filling = GetFillingModeClose(symbol);

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
      if(res.retcode == TRADE_RETCODE_MARKET_CLOSED)
      {
         LogWarning(StringFormat("EOD: биржа закрыта (10018), ожидаем открытия | попытка %d/%d",
                                  g_eodCloseAttempts, EOD_MAX_ATTEMPTS));
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

   // Hedging: проверка по POSITION_MAGIC
   if(GetPositionTicketByMagic(magic) > 0)
      return;

   // Позиция закрылась — ищем результат в истории за последние сутки
   HistorySelect(TimeTradeServer() - 86400, TimeTradeServer());

   double totalPnl = 0.0;
   string closeReason = "SL/TP";

   int dealsTotal = HistoryDealsTotal();
   for(int i = dealsTotal - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= 0) continue;
      if(!HistoryDealSelect(dealTicket)) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != symbol) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      totalPnl = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
               + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
               + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

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

   // Hedging: ищем позицию по POSITION_MAGIC
   ulong posTicket = GetPositionTicketByMagic(magic);
   if(posTicket > 0 && PositionSelectByTicket(posTicket))
   {
      g_positionWasOpen = true;

      if(g_entryPrice <= 0.0)
         g_entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      LogInfo(StringFormat("Position-модуль: позиция восстановлена | "
                            "EntryPrice=%.2f  BeDone=%s",
                            g_entryPrice,
                            g_beDone ? "true" : "false"));
   }
}

//+------------------------------------------------------------------+
//|  Аварийное закрытие overnight — вызывается из OnTick()           |
//|  Срабатывает если позиция осталась открытой после 00:00 UTC      |
//|  (т.е. CheckEodClose не сработал — биржа была закрыта весь       |
//|  вечерний период или EOD_MAX_ATTEMPTS исчерпаны досрочно)        |
//+------------------------------------------------------------------+
void CheckOvernightClose(string symbol, int magic)
{
   if(!g_positionWasOpen)
      return;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   // Активируем только в ранние утренние часы (00:00–06:00 UTC)
   // Вне торговых часов TSLA — гарантированно не US сессия
   if(now.hour >= 6)
      return;

   // Hedging: ищем позицию по POSITION_MAGIC
   ulong posTicket = GetPositionTicketByMagic(magic);
   if(!PositionSelectByTicket(posTicket))
      return;

   double pnl    = PositionGetDouble(POSITION_PROFIT);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = symbol;
   req.volume    = volume;
   req.deviation = 100;   // Широкий слиппаж — закрытие любой ценой
   req.magic     = magic;
   req.position  = posTicket;

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
   req.type_filling = GetFillingModeClose(symbol);

   LogWarning(StringFormat("OVERNIGHT CLOSE: позиция осталась с прошлого дня — экстренное закрытие | "
                            "PnL=%.2f", pnl));

   if(OrderSend(req, res) &&
      (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED))
   {
      g_dailyTradeDone  = true;
      g_eaState         = STATE_DISABLED_TODAY;
      g_positionWasOpen = false;

      GlobalVariableSet("ORB_TRADE_DONE", 1.0);
      GlobalVariableSet("ORB_STATE",      (double)STATE_DISABLED_TODAY);

      string msg = StringFormat("OVERNIGHT CLOSE выполнено | PnL=%.2f", pnl);
      LogError(msg);
      SendEaAlert(msg, true, true, true);
   }
   else
   {
      LogError(StringFormat("OVERNIGHT CLOSE не удалось: retcode=%d  ошибка=%d",
                             res.retcode, GetLastError()));
   }
}

#endif // POSITION_MQH
