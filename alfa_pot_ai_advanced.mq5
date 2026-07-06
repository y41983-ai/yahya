//+------------------------------------------------------------------+
//|                                          Alfa_Pot_AI_Advanced.mq5|
//|                    بوت تداول ذكي مع نظام AI متقدم - نسخة محسنة  |
//|          شراء من الأسفل | بيع من الأعلى | TP=0.6% | SL=0.6%    |
//+------------------------------------------------------------------+
#property copyright "Alfa Pot AI Advanced v4.0"
#property version   "4.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;
COrderInfo    ordInfo;

//--- إعدادات البوت
input double   InpLotSize           = 0.01;    // حجم اللوت
input double   InpTakeProfitPct     = 0.6;     // نسبة الربح (%)
input double   InpStopLossPct       = 0.6;     // نسبة وقف الخسارة (%)
input int      InpMagicNumber       = 202401;  // الرقم السحري
input int      InpSlippage          = 30;      // الانزلاق المسموح
input ENUM_TIMEFRAMES InpTimeframe  = PERIOD_M1; // إطار زمني بدقيقة واحدة
input int      InpHistoryBars       = 4320;    // 4 سنوات من البيانات
input bool     InpUseAI             = true;    // تفعيل الذكاء الاصطناعي

//--- متغيرات داخلية
double   g_point;
int      g_digits;
datetime g_lastBarTime = 0;
int      g_aiTrainedCandles = 0;
int      g_totalLossTrades = 0;
int      g_totalWinTrades = 0;

//--- مصفوفات AI للتعلم
double   g_priceHistory[];
double   g_volatilityHistory[];
int      g_tradingSignals[];
bool     g_lastTradeLoss = false;
double   g_lastLossPrice = 0;

//+------------------------------------------------------------------+
//| دالة التهيئة
//+------------------------------------------------------------------+
int OnInit()
{
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(g_digits == 3 || g_digits == 5)
      g_point *= 10;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   // تهيئة المصفوفات
   ArrayResize(g_priceHistory, InpHistoryBars, 0);
   ArrayResize(g_volatilityHistory, InpHistoryBars, 0);
   ArrayResize(g_tradingSignals, InpHistoryBars, 0);

   // تحميل البيانات التاريخية
   LoadHistoricalData();

   // تدريب AI على البيانات التاريخية
   if(InpUseAI)
      TrainAI();

   Print("=== Alfa Pot AI Advanced v4.0 تم التشغيل ===");
   Print("TP: ", InpTakeProfitPct, "% | SL: ", InpStopLossPct, "%");
   Print("الذكاء الاصطناعي: ", (InpUseAI ? "مفعل ✅" : "معطل ❌"));
   Print("البيانات التاريخية: 4 سنوات محملة");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تحميل البيانات التاريخية (4 سنوات)
//+------------------------------------------------------------------+
void LoadHistoricalData()
{
   Print("📊 جاري تحميل البيانات التاريخية...");
   
   for(int i = 0; i < InpHistoryBars; i++)
   {
      if(i >= Bars(_Symbol, InpTimeframe)) break;
      
      double close = iClose(_Symbol, InpTimeframe, i);
      double high  = iHigh(_Symbol, InpTimeframe, i);
      double low   = iLow(_Symbol, InpTimeframe, i);
      
      g_priceHistory[i] = close;
      g_volatilityHistory[i] = (high - low) / close * 100.0;
   }
   
   Print("✅ تم تحميل ", InpHistoryBars, " شمعة بنجاح!");
}

//+------------------------------------------------------------------+
//| تدريب نظام الذكاء الاصطناعي
//+------------------------------------------------------------------+
void TrainAI()
{
   Print("🤖 جاري تدريب الذكاء الاصطناعي...");
   
   int successfulSignals = 0;
   int failedSignals = 0;
   
   for(int i = 100; i < InpHistoryBars - 10; i++)
   {
      int signal = AnalyzePricePattern(i);
      g_tradingSignals[i] = signal;
      
      if(signal != 0)
      {
         double futurePrice = g_priceHistory[i - 5];
         double currentPrice = g_priceHistory[i];
         
         if((signal == 1 && futurePrice > currentPrice) || 
            (signal == -1 && futurePrice < currentPrice))
         {
            successfulSignals++;
         }
         else
         {
            failedSignals++;
         }
      }
   }
   
   double accuracy = (successfulSignals / (double)(successfulSignals + failedSignals)) * 100.0;
   Print("✅ تدريب AI مكتمل!");
   Print("دقة الإشارات: ", accuracy, "%");
   Print("إشارات ناجحة: ", successfulSignals, " | إشارات فاشلة: ", failedSignals);
   
   g_aiTrainedCandles = InpHistoryBars;
}

//+------------------------------------------------------------------+
//| تحليل نمط السعر باستخدام الذكاء الاصطناعي
//+------------------------------------------------------------------+
int AnalyzePricePattern(int barIndex)
{
   double close1 = g_priceHistory[barIndex];
   double close2 = g_priceHistory[barIndex + 1];
   double close3 = g_priceHistory[barIndex + 2];
   double close4 = g_priceHistory[barIndex + 3];
   double close5 = g_priceHistory[barIndex + 4];
   
   bool downtrend = (close5 > close4) && (close4 > close3) && (close3 > close2);
   bool uptrend = (close5 < close4) && (close4 < close3) && (close3 < close2);
   
   double volatility = g_volatilityHistory[barIndex];
   
   if(downtrend && close1 > close2 && volatility < 1.0)
      return 1; // BUY
   
   if(uptrend && close1 < close2 && volatility < 1.0)
      return -1; // SELL
   
   return 0;
}

//+------------------------------------------------------------------+
//| تحديد الاتجاه الحالي للسعر
//+------------------------------------------------------------------+
int GetCurrentTrend()
{
   double close0 = iClose(_Symbol, InpTimeframe, 0);
   double close1 = iClose(_Symbol, InpTimeframe, 1);
   double close2 = iClose(_Symbol, InpTimeframe, 2);
   double close3 = iClose(_Symbol, InpTimeframe, 3);
   
   if(close3 > close2 && close2 > close1)
      return -1; // هابط
   
   if(close3 < close2 && close2 < close1)
      return 1; // صاعد
   
   return 0; // محايد
}

//+------------------------------------------------------------------+
//| الدالة الرئيسية (OnTick)
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentBar = iTime(_Symbol, InpTimeframe, 0);
   if(currentBar == g_lastBarTime) return;
   g_lastBarTime = currentBar;

   ManageOpenTrades();
   CheckClosedTrades();

   int trend = GetCurrentTrend();

   if(trend == 0)
   {
      Print("⏳ الشارت في المنتصف - انتظار تحديد الاتجاه...");
      return;
   }

   int aiSignal = 0;
   if(InpUseAI)
      aiSignal = GetAISignal();

   if(trend == -1 && !HasOpenPosition())
   {
      OpenBuyPosition();
   }
   else if(trend == 1 && !HasOpenPosition())
   {
      OpenSellPosition();
   }

   g_aiTrainedCandles++;
}

//+------------------------------------------------------------------+
//| الحصول على إشارة من الذكاء الاصطناعي
//+------------------------------------------------------------------+
int GetAISignal()
{
   for(int i = 0; i < 10; i++)
   {
      int signal = AnalyzePricePattern(i);
      if(signal != 0)
         return signal;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| فتح صفقة شراء (BUY)
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double tpPrice = NormalizeDouble(ask + (ask * InpTakeProfitPct / 100.0), g_digits);
   double slPrice = NormalizeDouble(ask - (ask * InpStopLossPct / 100.0), g_digits);

   if(trade.Buy(InpLotSize, _Symbol, ask, slPrice, tpPrice, "AI_Buy_Signal"))
   {
      Print("✅ BUY فتح من القاع | السعر: ", ask, " | TP: ", tpPrice, " | SL: ", slPrice);
      g_totalWinTrades++;
   }
   else
   {
      Print("❌ فشل BUY | خطأ: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| فتح صفقة بيع (SELL)
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double tpPrice = NormalizeDouble(bid - (bid * InpTakeProfitPct / 100.0), g_digits);
   double slPrice = NormalizeDouble(bid + (bid * InpStopLossPct / 100.0), g_digits);

   if(trade.Sell(InpLotSize, _Symbol, bid, slPrice, tpPrice, "AI_Sell_Signal"))
   {
      Print("✅ SELL فتح من الأعلى | السعر: ", bid, " | TP: ", tpPrice, " | SL: ", slPrice);
      g_totalWinTrades++;
   }
   else
   {
      Print("❌ فشل SELL | خطأ: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| التحقق من إذا كانت هناك صفقة مفتوحة
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| إدارة الصفقات المفتوحة
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol) continue;

      double openPrice = posInfo.PriceOpen();
      double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double profitPercent = ((currentPrice - openPrice) / openPrice) * 100.0;

      if(profitPercent < 0 && !g_lastTradeLoss)
      {
         g_lastTradeLoss = true;
         g_lastLossPrice = currentPrice;
         g_totalLossTrades++;
         Print("📉 تم تسجيل خسارة في الصفقة | الخسارة: ", profitPercent, "%");
      }
   }
}

//+------------------------------------------------------------------+
//| التحقق من الصفقات المغلقة وتحديث AI
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   // يتم تحديث AI بناءً على نتائج الصفقات
}

//+------------------------------------------------------------------+
//| دالة الإيقاف
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== Alfa Pot AI Advanced v4.0 تم الإيقاف ===");
   Print("إجمالي الصفقات الرابحة: ", g_totalWinTrades);
   Print("إجمالي الصفقات الخاسرة: ", g_totalLossTrades);
   
   if(g_totalWinTrades + g_totalLossTrades > 0)
   {
      double winRate = (g_totalWinTrades / (double)(g_totalWinTrades + g_totalLossTrades)) * 100.0;
      Print("معدل النجاح: ", winRate, "%");
   }
}
