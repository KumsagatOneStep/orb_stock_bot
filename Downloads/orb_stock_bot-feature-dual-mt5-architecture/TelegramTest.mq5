//+------------------------------------------------------------------+
//|                                              TelegramTest.mq5    |
//|           TSLA ORB — тест Telegram-уведомлений                   |
//|                                                                   |
//|  Как использовать:                                                |
//|    1. Скомпилировать и запустить из Navigator → Scripts           |
//|    2. Ввести Token и ChatID в окне параметров                     |
//|    3. Проверить что сообщение пришло в Telegram                   |
//+------------------------------------------------------------------+
#property script_show_inputs
#property copyright "TSLA ORB EA v2.0"
#property version   "1.00"

#include "Logger.mqh"

input string InpToken  = "";   // Bot Token от @BotFather (1234567890:ABC...)
input string InpChatId = "";   // Chat ID от @userinfobot (например 123456789)

void OnStart()
{
   InitLogger("TelegramTest", LOG_INFO, false, false, false);

   if(StringLen(InpToken) == 0 || StringLen(InpChatId) == 0)
   {
      Print("[TelegramTest] ОШИБКА: введите Token и ChatID в параметрах скрипта");
      return;
   }

   InitTelegram(InpToken, InpChatId);

   Print("[TelegramTest] Отправка тестового сообщения...");

   string msg = StringFormat(
      "TSLA_ORB Telegram тест\n"
      "Время сервера: %s\n"
      "Баланс: %.2f\n"
      "Telegram подключён успешно",
      TimeToString(TimeTradeServer(), TIME_DATE | TIME_SECONDS),
      AccountInfoDouble(ACCOUNT_BALANCE)
   );

   if(SendTelegramMessage(msg))
      Print("[TelegramTest] Успешно — проверьте Telegram");
   else
      Print("[TelegramTest] ОШИБКА — см. журнал выше");
}
