//+------------------------------------------------------------------+
//|                                                      Logger.mqh  |
//|           TSLA Pre-Market ORB Level Break EA — v1.5              |
//|           Модуль: логирование и уведомления                      |
//+------------------------------------------------------------------+
#ifndef LOGGER_MQH
#define LOGGER_MQH

enum ENUM_LOG_LEVEL
{
   LOG_DEBUG   = 0,
   LOG_INFO    = 1,
   LOG_WARNING = 2,
   LOG_ERROR   = 3
};

ENUM_LOG_LEVEL g_logLevel    = LOG_INFO;
bool           g_enablePush  = true;
bool           g_enableEmail = false;
bool           g_enableSound = true;
string         g_eaTag       = "TSLA_ORB";

void InitLogger(string eaTag, ENUM_LOG_LEVEL logLevel,
                bool enablePush, bool enableEmail, bool enableSound)
{
   g_eaTag       = eaTag;
   g_logLevel    = logLevel;
   g_enablePush  = enablePush;
   g_enableEmail = enableEmail;
   g_enableSound = enableSound;
}

// FIX BUG 10: переименовано из _Log → LogWrite (избегаем имён с ведущим _)
void LogWrite(ENUM_LOG_LEVEL level, string message)
{
   if(level < g_logLevel)
      return;

   string levelStr;
   switch(level)
   {
      case LOG_DEBUG:   levelStr = "DEBUG";   break;
      case LOG_INFO:    levelStr = "INFO";    break;
      case LOG_WARNING: levelStr = "WARNING"; break;
      case LOG_ERROR:   levelStr = "ERROR";   break;
      default:          levelStr = "INFO";    break;
   }

   string ts = TimeToString(TimeTradeServer(), TIME_DATE | TIME_SECONDS);
   Print(StringFormat("[%s] [%s] [%s] %s", g_eaTag, ts, levelStr, message));
}

void LogDebug(string msg)   { LogWrite(LOG_DEBUG,   msg); }
void LogInfo(string msg)    { LogWrite(LOG_INFO,    msg); }
void LogWarning(string msg) { LogWrite(LOG_WARNING, msg); }
void LogError(string msg)   { LogWrite(LOG_ERROR,   msg); }

//+------------------------------------------------------------------+
//|  FIX BUG 1: переименовано SendNotification → SendEaAlert         |
//|  Причина: конфликт с MT5 встроенной SendNotification(string)     |
//|  Внутри вызываем MT5 built-in напрямую — нет рекурсии            |
//+------------------------------------------------------------------+
void SendEaAlert(string message, bool doPush, bool doEmail, bool doSound)
{
   if(doPush && g_enablePush)
   {
      // Вызов MT5 встроенной функции (1 параметр — нет конфликта)
      if(!SendNotification(message))
         LogWrite(LOG_WARNING, "Push не отправлен: " + (string)GetLastError());
   }

   if(doEmail && g_enableEmail)
   {
      if(!SendMail(g_eaTag + " | Уведомление", message))
         LogWrite(LOG_WARNING, "Email не отправлен: " + (string)GetLastError());
   }

   if(doSound && g_enableSound)
      PlaySound("alert.wav");
}

//--- Алерт-функции для типовых событий (раздел 6.6)

void AlertTradeOpen(string direction, double lot, double sl, double tp, double entryPrice)
{
   string msg = StringFormat("Вход %s | Лот=%.2f  Цена=%.2f  SL=%.2f  TP=%.2f",
                              direction, lot, entryPrice, sl, tp);
   LogInfo(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertBreakeven(double oldSL, double newSL)
{
   string msg = StringFormat("Breakeven активирован | SL: %.2f → %.2f", oldSL, newSL);
   LogInfo(msg);
   SendEaAlert(msg, true, false, false);
}

void AlertEodClose(double pnl)
{
   string msg = StringFormat("EOD принудительное закрытие | PnL=%.2f", pnl);
   LogInfo(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertPositionClosed(string reason, double pnl)
{
   string msg = StringFormat("Позиция закрыта [%s] | PnL=%.2f", reason, pnl);
   LogInfo(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertDailyLossLimit(double currentLoss, double limitPercent)
{
   string msg = StringFormat("Дневной лимит убытка | Убыток=%.2f (лимит %.1f%%)",
                              currentLoss, limitPercent);
   LogWarning(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertGapDetected()
{
   string msg = "GAP — оба уровня пробиты в одном тике, торговля отключена";
   LogWarning(msg);
   SendEaAlert(msg, true, false, false);
}

void AlertRetry(int attempt, int errorCode)
{
   LogWarning(StringFormat("Реквот/ошибка [%d], попытка повтора #%d", errorCode, attempt));
}

void AlertOrderRejected(int errorCode)
{
   string msg = StringFormat("Ордер отклонён после retry | Код: %d", errorCode);
   LogError(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertEaDisabled(string reason)
{
   string msg = StringFormat("EA отключён | Причина: %s", reason);
   LogWarning(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertNewDay(datetime newDate, double dayStartBalance)
{
   LogInfo(StringFormat("Новый торговый день %s | Баланс: %.2f",
                         TimeToString(newDate, TIME_DATE), dayStartBalance));
}

#endif // LOGGER_MQH
