//+------------------------------------------------------------------+
//|                                                        Entry.mqh |
//|           TSLA Pre-Market ORB Level Break EA — v3.0 (M3, 09:30-09:33)|
//|           Модуль: логика входа (LEVEL_A флаги, триггеры)         |
//+------------------------------------------------------------------+
#ifndef ENTRY_MQH
#define ENTRY_MQH

#include "Logger.mqh"
#include "Levels.mqh"
#include "Risk.mqh"

//+------------------------------------------------------------------+
//|  FIX BUG 8: определяет поддерживаемый режим заполнения ордера   |
//|  Capital.com обычно поддерживает FOK, но проверяем динамически   |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode(string symbol)
{
   int modes = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((modes & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//|  Фильтр спайков — аномальных котировок (раздел 7.5)              |
//+------------------------------------------------------------------+
bool IsSpikeOk(double ask, double bid, double spikeFilterThreshold)
{
   double spread = ask - bid;
   if(spikeFilterThreshold > 0.0 && spread > spikeFilterThreshold)
   {
      LogDebug(StringFormat("Спайк: Ask=%.2f Bid=%.2f Spread=%.2f > %.2f — тик пропущен",
                             ask, bid, spread, spikeFilterThreshold));
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//|  Обновление LEVEL_A флагов на каждом тике (шаг A логики A→B)    |
//+------------------------------------------------------------------+
void UpdateLevelAFlags(double ask, double bid)
{
   if(!g_levelALong && ask >= g_preHigh)
   {
      g_levelALong = true;
      GlobalVariableSet("ORB_LEVEL_A_LONG", 1.0);   // БАГ 3 FIX: сохраняем для рестарта в окне входа
      LogInfo(StringFormat("LEVEL_A_LONG | Ask=%.2f >= PRE_HIGH=%.2f", ask, g_preHigh));
   }
   if(!g_levelAShort && bid <= g_preLow)
   {
      g_levelAShort = true;
      GlobalVariableSet("ORB_LEVEL_A_SHORT", 1.0);  // БАГ 3 FIX
      LogInfo(StringFormat("LEVEL_A_SHORT | Bid=%.2f <= PRE_LOW=%.2f", bid, g_preLow));
   }
}

//+------------------------------------------------------------------+
//|  Gap-детектор: первый тик окна сразу за обоими уровнями (7.2)   |
//+------------------------------------------------------------------+
bool IsGapTick(double ask, double bid, double longEntry, double shortEntry)
{
   if(ask >= longEntry && bid <= shortEntry)
   {
      AlertGapDetected();
      g_eaState        = STATE_DISABLED_TODAY;
      g_dailyTradeDone = true;                           // БАГ A FIX: gap-фильтр должен блокировать как и любой вход
      GlobalVariableSet("ORB_STATE",      (double)STATE_DISABLED_TODAY);
      GlobalVariableSet("ORB_TRADE_DONE", 1.0);          // БАГ A FIX: иначе при рестарте gvIsToday=true читает 0 → вход разрешён
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//|  Отправка рыночного ордера с retry при реквоте (раздел 4.4)      |
//|                                                                  |
//|  FIX BUG 3: добавлен параметр entryOffset для корректной        |
//|  проверки уровня при повторных попытках                          |
//|  FIX BUG 8: режим заполнения определяется динамически            |
//+------------------------------------------------------------------+
ulong SendMarketOrder(string symbol,
                      ENUM_ORDER_TYPE orderType,
                      double lot,
                      double sl,
                      double tp,
                      double entryOffset,   // FIX BUG 3
                      int    maxSlippage,
                      int    retryDelay,
                      int    magic,
                      int    etOffset)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = symbol;
   req.volume       = lot;
   req.type         = orderType;
   req.sl           = sl;
   req.tp           = tp;
   req.deviation    = maxSlippage;
   req.magic        = magic;
   req.type_filling = GetFillingMode(symbol);   // FIX BUG 8
   req.comment      = "TSLA_ORB_v1";

   // FIX BUG 3: корректные уровни триггера (с отступом), не голые PRE_HIGH/PRE_LOW
   double longEntry  = g_preHigh + entryOffset;
   double shortEntry = g_preLow  - entryOffset;

   int maxRetries = 3;

   for(int attempt = 1; attempt <= maxRetries; attempt++)
   {
      req.price = (orderType == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(symbol, SYMBOL_BID);

      if(!OrderSend(req, res))
      {
         int err = GetLastError();
         AlertRetry(attempt, err);

         if(attempt >= maxRetries)
         {
            AlertOrderRejected(err);
            g_dailyTradeDone = true;
            GlobalVariableSet("ORB_TRADE_DONE", 1.0);
            return 0;
         }

         Sleep(retryDelay);

         // Перепроверка перед retry (раздел 4.4)
         if(!IsEntryAllowed(magic, etOffset))
         {
            LogWarning("Retry отменён: условия входа не выполнены");
            g_dailyTradeDone = true;
            GlobalVariableSet("ORB_TRADE_DONE", 1.0);
            return 0;
         }

         double askNow = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bidNow = SymbolInfoDouble(symbol, SYMBOL_BID);

         // FIX BUG 3: проверяем ENTRY-уровень, не PRE уровень
         if(orderType == ORDER_TYPE_BUY && askNow < longEntry)
         {
            LogWarning(StringFormat("Retry отменён: Ask=%.2f < LONG_ENTRY=%.2f",
                                     askNow, longEntry));
            g_dailyTradeDone = true;
            GlobalVariableSet("ORB_TRADE_DONE", 1.0);
            return 0;
         }
         if(orderType == ORDER_TYPE_SELL && bidNow > shortEntry)
         {
            LogWarning(StringFormat("Retry отменён: Bid=%.2f > SHORT_ENTRY=%.2f",
                                     bidNow, shortEntry));
            g_dailyTradeDone = true;
            GlobalVariableSet("ORB_TRADE_DONE", 1.0);
            return 0;
         }
         continue;
      }

      if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
      {
         LogInfo(StringFormat("Ордер исполнен | Ticket=%d  Цена=%.2f  Лот=%.2f  SL=%.2f  TP=%.2f",
                               res.order, res.price, lot, sl, tp));
         return res.order;
      }
      else
      {
         AlertRetry(attempt, (int)res.retcode);
         Sleep(retryDelay);
      }
   }

   AlertOrderRejected((int)res.retcode);
   g_dailyTradeDone = true;
   GlobalVariableSet("ORB_TRADE_DONE", 1.0);
   return 0;
}

//+------------------------------------------------------------------+
//|  Главная функция входа — вызывается из OnTick()                  |
//|                                                                  |
//|  FIX BUG 2: добавлен параметр maxDailyLossPercent               |
//|  FIX BUG 3: entryOffset передаётся в SendMarketOrder            |
//+------------------------------------------------------------------+
ulong ProcessEntryTick(string symbol,
                       int    etOffset,
                       double entryOffset,
                       double lot,
                       double takeProfit,
                       double maxDailyLossPercent,   // FIX BUG 2
                       int    maxSlippage,
                       int    retryDelay,
                       int    magic,
                       double spikeFilter,
                       bool   isFirstTick)
{
   if(g_eaState != STATE_LEVELS_SET)
      return 0;

   // BUG 3: entryOffset=0 → SL == цена входа → ордер отклонён брокером
   if(entryOffset <= 0.0)
   {
      LogError("ProcessEntryTick: entryOffset должен быть > 0 — вход заблокирован");
      return 0;
   }

   if(!IsEntryAllowed(magic, etOffset))
      return 0;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   if(!IsSpikeOk(ask, bid, spikeFilter))
      return 0;

   double longEntry  = g_preHigh + entryOffset;
   double shortEntry = g_preLow  - entryOffset;

   if(isFirstTick && IsGapTick(ask, bid, longEntry, shortEntry))
   {
      LogWarning(StringFormat("GAP | Ask=%.2f Bid=%.2f LONG=%.2f SHORT=%.2f",
                               ask, bid, longEntry, shortEntry));
      return 0;
   }

   UpdateLevelAFlags(ask, bid);

   // === LONG-вход ===
   if(g_levelALong && ask >= longEntry)
   {
      // FIX BUG 2: реальный maxDailyLossPercent, не 0.0
      if(!CheckDailyLoss(maxDailyLossPercent))
         return 0;

      double sl      = ask - entryOffset;   // SL на фиксированной дистанции от цены входа — сохраняет R:R=12:1
      double tpPrelim = ask + takeProfit;

      LogInfo(StringFormat("LONG-триггер | Ask=%.2f >= %.2f | SL=%.2f",
                            ask, longEntry, sl));

      ulong ticket = SendMarketOrder(symbol, ORDER_TYPE_BUY, lot,
                                     sl, tpPrelim, entryOffset,   // FIX BUG 3
                                     maxSlippage, retryDelay, magic, etOffset);
      if(ticket > 0)
      {
         g_dailyTradeDone = true;
         g_eaState        = STATE_IN_TRADE;
         GlobalVariableSet("ORB_TRADE_DONE", 1.0);
         GlobalVariableSet("ORB_STATE",      (double)STATE_IN_TRADE);
         AlertTradeOpen("BUY", lot, sl, tpPrelim, ask);
      }
      return ticket;
   }

   // === SHORT-вход ===
   if(g_levelAShort && bid <= shortEntry)
   {
      if(!CheckDailyLoss(maxDailyLossPercent))   // FIX BUG 2
         return 0;

      double sl      = bid + entryOffset;   // SL на фиксированной дистанции от цены входа — сохраняет R:R=12:1
      double tpPrelim = bid - takeProfit;

      LogInfo(StringFormat("SHORT-триггер | Bid=%.2f <= %.2f | SL=%.2f",
                            bid, shortEntry, sl));

      ulong ticket = SendMarketOrder(symbol, ORDER_TYPE_SELL, lot,
                                     sl, tpPrelim, entryOffset,   // FIX BUG 3
                                     maxSlippage, retryDelay, magic, etOffset);
      if(ticket > 0)
      {
         g_dailyTradeDone = true;
         g_eaState        = STATE_IN_TRADE;
         GlobalVariableSet("ORB_TRADE_DONE", 1.0);
         GlobalVariableSet("ORB_STATE",      (double)STATE_IN_TRADE);
         AlertTradeOpen("SELL", lot, sl, tpPrelim, bid);
      }
      return ticket;
   }

   return 0;
}

//+------------------------------------------------------------------+
//|  FIX BUG 5: убрана граничная секунда 14:00:00                   |
//|  Окно строго [fixHour:30, fixHour+1:00) — не включает 14:00     |
//+------------------------------------------------------------------+
bool IsInEntryWindow(int etOffset)
{
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   int fixHour = GetOrbCandleHour(etOffset);   // 13 или 14
   return (now.hour == fixHour && now.min >= 33);
}

//+------------------------------------------------------------------+
//|  Истечение окна без входа (раздел 4.3)                           |
//+------------------------------------------------------------------+
void CheckEntryWindowExpiry(int etOffset)
{
   if(g_eaState != STATE_LEVELS_SET)
      return;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   int entryEnd = GetOrbCandleHour(etOffset) + 1;   // 14 или 15

   if(now.hour >= entryEnd)
   {
      LogInfo(StringFormat("Окно входа истекло (%02d:00 сервер) — сделок сегодня нет",
                            entryEnd));
      g_eaState = STATE_DISABLED_TODAY;
      GlobalVariableSet("ORB_STATE", (double)STATE_DISABLED_TODAY);
   }
}

#endif // ENTRY_MQH
