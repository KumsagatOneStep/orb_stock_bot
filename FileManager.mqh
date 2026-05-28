//+------------------------------------------------------------------+
//|                                                  FileManager.mqh |
//|           TSLA ORB Dual MT5 — Shared File I/O Module            |
//|  Запись: EA_DataReader (Exness)                                  |
//|  Чтение: TSLA_ORB_v1   (Capital.com)                            |
//+------------------------------------------------------------------+
#ifndef FILEMANAGER_MQH
#define FILEMANAGER_MQH

#define ORB_FILE_NAME "orb_levels.txt"

struct OrbLevels
{
   string date;          // "2026.05.28"
   double preHigh;       // PRE_HIGH
   double preLow;        // PRE_LOW
   double closePrice;    // CLOSE_PRICE
   double entryOffset;   // ENTRY_OFFSET (== STOP_LOSS дистанция)
   double stopLoss;      // STOP_LOSS
   double breakeven;     // BREAKEVEN
   double takeProfit;    // TAKE_PROFIT
   string timestamp;     // "13:30:05"
   string status;        // "READY" | "WRITING"
};

string OrbTodayString()
{
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   return StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
}

bool WriteLevelsFile(const OrbLevels &lv)
{
   int fh = FileOpen(ORB_FILE_NAME, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
   if(fh == INVALID_HANDLE)
   {
      Print("[FileManager] ERROR: открытие для записи — код ", GetLastError());
      return false;
   }

   FileWriteString(fh, "DATE="         + lv.date                           + "\n");
   FileWriteString(fh, "PRE_HIGH="     + DoubleToString(lv.preHigh,    5)  + "\n");
   FileWriteString(fh, "PRE_LOW="      + DoubleToString(lv.preLow,     5)  + "\n");
   FileWriteString(fh, "CLOSE_PRICE="  + DoubleToString(lv.closePrice, 5)  + "\n");
   FileWriteString(fh, "ENTRY_OFFSET=" + DoubleToString(lv.entryOffset,2)  + "\n");
   FileWriteString(fh, "STOP_LOSS="    + DoubleToString(lv.stopLoss,   2)  + "\n");
   FileWriteString(fh, "BREAKEVEN="    + DoubleToString(lv.breakeven,  2)  + "\n");
   FileWriteString(fh, "TAKE_PROFIT="  + DoubleToString(lv.takeProfit, 2)  + "\n");
   FileWriteString(fh, "TIMESTAMP="    + lv.timestamp                      + "\n");
   FileWriteString(fh, "STATUS="       + lv.status                         + "\n");

   FileClose(fh);
   return true;
}

bool ReadLevelsFile(OrbLevels &lv)
{
   if(!FileIsExist(ORB_FILE_NAME, FILE_COMMON))
      return false;

   int fh = FileOpen(ORB_FILE_NAME, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
   if(fh == INVALID_HANDLE)
   {
      Print("[FileManager] ERROR: открытие для чтения — код ", GetLastError());
      return false;
   }

   while(!FileIsEnding(fh))
   {
      string line = FileReadString(fh);
      int sep = StringFind(line, "=");
      if(sep < 0) continue;

      string key = StringSubstr(line, 0, sep);
      string val = StringSubstr(line, sep + 1);
      StringTrimRight(val);   // убираем \r при Windows line endings

      if     (key == "DATE")         lv.date        = val;
      else if(key == "PRE_HIGH")     lv.preHigh     = StringToDouble(val);
      else if(key == "PRE_LOW")      lv.preLow      = StringToDouble(val);
      else if(key == "CLOSE_PRICE")  lv.closePrice  = StringToDouble(val);
      else if(key == "ENTRY_OFFSET") lv.entryOffset = StringToDouble(val);
      else if(key == "STOP_LOSS")    lv.stopLoss    = StringToDouble(val);
      else if(key == "BREAKEVEN")    lv.breakeven   = StringToDouble(val);
      else if(key == "TAKE_PROFIT")  lv.takeProfit  = StringToDouble(val);
      else if(key == "TIMESTAMP")    lv.timestamp   = val;
      else if(key == "STATUS")       lv.status      = val;
   }

   FileClose(fh);
   return true;
}

#endif // FILEMANAGER_MQH
