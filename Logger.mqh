//+------------------------------------------------------------------+
//|                                                      Logger.mqh  |
//|           TSLA Pre-Market ORB Level Break EA — v1.9              |
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

// --- Telegram (v2.0) ---
bool   g_enableTelegram = false;
string g_telegramToken  = "";
string g_telegramChatId = "";

void InitLogger(string eaTag, ENUM_LOG_LEVEL logLevel,
                bool enablePush, bool enableEmail, bool enableSound)
{
   g_eaTag       = eaTag;
   g_logLevel    = logLevel;
   g_enablePush  = enablePush;
   g_enableEmail = enableEmail;
   g_enableSound = enableSound;
}

void InitTelegram(string token, string chatId)
{
   g_enableTelegram = (StringLen(token) > 0 && StringLen(chatId) > 0);
   g_telegramToken  = token;
   g_telegramChatId = chatId;
   if(g_enableTelegram)
      Print(StringFormat("[%s] Telegram инициализирован | ChatID=%s", g_eaTag, chatId));
}

string TgEscape(string s)
{
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\r", "\\r");
   return s;
}

bool SendTelegramMessage(string message)
{
   if(!g_enableTelegram) return false;

   string url  = "https://api.telegram.org/bot" + g_telegramToken + "/sendMessage";
   string body = "{\"chat_id\":\"" + g_telegramChatId + "\",\"text\":\"" + TgEscape(message) + "\"}";

   char   post[], result[];
   string headers = "Content-Type: application/json; charset=utf-8\r\n";
   string responseHeaders;

   int bodyLen = StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8) - 1;
   ArrayResize(post, bodyLen);

   int httpCode = WebRequest("POST", url, headers, 5000, post, result, responseHeaders);

   if(httpCode == -1)
   {
      Print(StringFormat("[%s] Telegram: ошибка %d — добавьте api.telegram.org в Tools→Options→Expert Advisors→WebRequest",
                          g_eaTag, GetLastError()));
      return false;
   }
   if(httpCode != 200)
   {
      Print(StringFormat("[%s] Telegram: HTTP %d", g_eaTag, httpCode));
      return false;
   }
   return true;
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
      if(!SendNotification(message))
         LogWrite(LOG_WARNING, "Push не отправлен: " + (string)GetLastError());
   }

   if(doPush && g_enableTelegram)
      SendTelegramMessage(message);

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

void AlertStopLevelApproaching(double currentBalance, double stopLevel)
{
   string msg = StringFormat("ПРЕДУПРЕЖДЕНИЕ: баланс приближается к стоп-уровню | "
                              "Баланс=%.2f  StopLevel=%.2f",
                              currentBalance, stopLevel);
   LogWarning(msg);
   SendEaAlert(msg, true, true, true);
}

void AlertStopLevelReached(double currentBalance, double stopLevel)
{
   string msg = StringFormat("СТОП: стоп-уровень достигнут — EA остановлен | "
                              "Баланс=%.2f  StopLevel=%.2f  Требуется ручной перезапуск",
                              currentBalance, stopLevel);
   LogWarning(msg);
   SendEaAlert(msg, true, true, true);
}

#endif // LOGGER_MQH
