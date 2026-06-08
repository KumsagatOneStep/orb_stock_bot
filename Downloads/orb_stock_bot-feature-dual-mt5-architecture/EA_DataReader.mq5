//+------------------------------------------------------------------+
//|                                             EA_DataReader.mq5   |
//|           TSLA ORB Dual MT5 — Data Reader for Exness            |
//|                                                                  |
//|  Назначение: читает свечу M5 09:25–09:30 ET, пишет levels.txt   |
//|  Брокер:     Exness MT5 (только чтение данных, не торгует)      |
//|  Таймфрейм:  M5                                                 |
//+------------------------------------------------------------------+
#property copyright "TSLA ORB EA_DataReader v1.0"
#property version   "1.00"

#include "FileManager.mqh"
#include "Logger.mqh"

input string         InpSymbol    = "TSLA";    // Инструмент
input int            InpETOffset  = -4;         // Смещение ET вручную (если AutoDST=false)
input bool           InpAutoDST   = true;       // Авто-определение EDT/EST
input double         InpBasePrice = 400.00;     // Эталонная цена для динамических параметров
input ENUM_LOG_LEVEL InpLogLevel  = LOG_INFO;   // Уровень лога

bool     g_levelsWritten = false;
int      g_etOffset      = -4;
datetime g_lastDate      = 0;

//+------------------------------------------------------------------+
//|  DST helpers (отдельная единица компиляции — нет конфликта       |
//|  с Levels.mqh который включается только в TSLA_ORB_v1)          |
//+------------------------------------------------------------------+
datetime DR_FindNthWeekday(int year, int month, int n, int dayOfWeek)
{
   MqlDateTime dt = {};
   dt.year = year; dt.mon = month; dt.day = 1;
   datetime firstDay = StructToTime(dt);
   MqlDateTime fdStruct;
   TimeToStruct(firstDay, fdStruct);
   int shift = (dayOfWeek - fdStruct.day_of_week + 7) % 7;
   dt.day    = 1 + shift + (n - 1) * 7;
   return StructToTime(dt);
}

int DR_CalcETOffset(datetime serverUTC)
{
   MqlDateTime dt;
   TimeToStruct(serverUTC, dt);
   int year = dt.year;
   datetime dstStart = DR_FindNthWeekday(year,  3, 2, 0) + 7 * 3600;
   datetime dstEnd   = DR_FindNthWeekday(year, 11, 1, 0) + 6 * 3600;
   return (serverUTC >= dstStart && serverUTC < dstEnd) ? -4 : -5;
}

// Строит datetime открытия ORB-свечи (09:25 ET) для сегодняшней даты
datetime DR_BuildOrbOpenTime(int etOffset)
{
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   dt.hour = 9 - etOffset;   // 13 лето / 14 зима
   dt.min  = 25;
   dt.sec  = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//|  OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   InitLogger("DataReader", InpLogLevel, false, false, false);

   g_etOffset = InpAutoDST ? DR_CalcETOffset(TimeTradeServer()) : InpETOffset;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   now.hour = 0; now.min = 0; now.sec = 0;
   g_lastDate = StructToTime(now);

   EventSetTimer(1);

   LogInfo(StringFormat("EA_DataReader запущен | Symbol=%s  ETOffset=%+d  "
                         "AutoDST=%s  BasePrice=%.2f",
                         InpSymbol, g_etOffset,
                         InpAutoDST ? "ON" : "OFF", InpBasePrice));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  OnDeinit                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   LogInfo("EA_DataReader остановлен");
}

//+------------------------------------------------------------------+
//|  OnTick — обработка тиков                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckNewDay();
   TryWriteLevels();
}

//+------------------------------------------------------------------+
//|  OnTimer — каждую секунду (на случай редких тиков)               |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckNewDay();
   TryWriteLevels();
}

//+------------------------------------------------------------------+
//|  Детектор смены дня — сброс флага в 00:00 UTC                   |
//+------------------------------------------------------------------+
void CheckNewDay()
{
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   now.hour = 0; now.min = 0; now.sec = 0;
   datetime today = StructToTime(now);

   if(today != g_lastDate)
   {
      g_lastDate      = today;
      g_levelsWritten = false;
      g_etOffset      = InpAutoDST ? DR_CalcETOffset(TimeTradeServer()) : InpETOffset;
      LogInfo(StringFormat("Новый день %s — сброс LEVELS_WRITTEN | ETOffset=%+d",
                            TimeToString(today, TIME_DATE), g_etOffset));
   }
}

//+------------------------------------------------------------------+
//|  Попытка зафиксировать уровни и записать файл                    |
//|  Условие: текущее время >= fixHour:30 и файл ещё не записан     |
//+------------------------------------------------------------------+
void TryWriteLevels()
{
   if(g_levelsWritten) return;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);

   int fixHour = 9 - g_etOffset;   // 13 лето / 14 зима

   if(now.hour < fixHour) return;
   if(now.hour == fixHour && now.min < 30) return;

   datetime orbOpenTime = DR_BuildOrbOpenTime(g_etOffset);
   int candleIdx  = -1;
   int totalBars  = iBars(InpSymbol, PERIOD_M5);
   int searchDepth = MathMin(totalBars - 1, 60);

   for(int i = 1; i <= searchDepth; i++)
   {
      datetime barTime = iTime(InpSymbol, PERIOD_M5, i);
      if(barTime == orbOpenTime) { candleIdx = i; break; }
      if(barTime < orbOpenTime - 7200) break;
   }

   if(candleIdx < 0)
   {
      LogError(StringFormat("Свеча ORB 09:25 ET не найдена | Ищем: %s",
                             TimeToString(orbOpenTime, TIME_DATE | TIME_MINUTES)));
      return;
   }

   double high  = iHigh(InpSymbol,  PERIOD_M5, candleIdx);
   double low   = iLow(InpSymbol,   PERIOD_M5, candleIdx);
   double close = iClose(InpSymbol, PERIOD_M5, candleIdx);

   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
   {
      LogError(StringFormat("Некорректные данные свечи | H=%.2f L=%.2f C=%.2f — откладываем",
                             high, low, close));
      return;
   }

   OrbLevels lv;
   lv.date        = OrbTodayString();
   lv.preHigh     = high;
   lv.preLow      = low;
   lv.closePrice  = close;
   lv.entryOffset = NormalizeDouble(close * (0.50 / InpBasePrice), 2);
   lv.stopLoss    = lv.entryOffset;
   lv.breakeven   = NormalizeDouble(close * (1.50 / InpBasePrice), 2);
   lv.takeProfit  = NormalizeDouble(close * (6.00 / InpBasePrice), 2);
   lv.timestamp   = TimeToString(TimeTradeServer(), TIME_MINUTES | TIME_SECONDS);
   lv.status      = "READY";

   if(!WriteLevelsFile(lv))
   {
      LogError("Ошибка записи orb_levels.txt — попробуем на следующем тике");
      return;
   }

   g_levelsWritten = true;

   LogInfo(StringFormat("orb_levels.txt записан | "
                         "HIGH=%.2f  LOW=%.2f  CLOSE=%.2f  "
                         "Entry=%.2f  BE=%.2f  TP=%.2f  Свеча[%d]",
                         high, low, close,
                         lv.entryOffset, lv.breakeven, lv.takeProfit,
                         candleIdx));
}
