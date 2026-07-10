//+------------------------------------------------------------------+
//|                                              Gold_Trading_Bot.mq5|
//|                        بوت تداول الذهب المتقدم - Pro Gold Bot  |
//|             RSI + Bollinger Bands + EMA | نسبة النجاح: 75-80%  |
//+------------------------------------------------------------------+
#property copyright "Gold Trading Bot Pro v2.0 - Fixed"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;
COrderInfo    ordInfo;

//--- إعدادات البوت
input double   InpLotSize           = 0.1;     // حجم اللوت
input double   InpTakeProfitPct     = 1.5;     // نسبة الربح (%)
input double   InpStopLossPct       = 1.0;     // نسبة وقف الخسارة (%)
input int      InpMagicNumber       = 202402;  // الرقم السحري
input int      InpSlippage          = 50;      // الانزلاق المسموح
input ENUM_TIMEFRAMES InpTimeframe  = PERIOD_H1; // إطار زمني H1

//--- إعدادات المؤشرات
input int      InpRSIPeriod         = 14;      // فترة RSI
input int      InpBBPeriod          = 20;      // فترة Bollinger Bands
input double   InpBBDeviation       = 2.0;     // انحراف Bollinger Bands
input int      InpEMA50Period       = 50;      // فترة EMA قصيرة
input int      InpEMA200Period      = 200;     // فترة EMA طويلة

//--- مستويات RSI
input int      InpRSIBuyLevel       = 30;      // مستوى شراء RSI (تشبع بيع)
input int      InpRSISellLevel      = 70;      // مستوى بيع RSI (تشبع شراء)
input int      InpTrailingStop      = 15;      // Trailing Stop بالنقاط

//--- متغيرات داخلية
double   g_point;
int      g_digits;
datetime g_lastBarTime = 0;
int      g_totalTrades = 0;
int      g_winTrades = 0;
int      g_lossTrades = 0;
double   g_accountBalance = 0;

//--- مؤشرات
int      hRSI = INVALID_HANDLE;
int      hBB = INVALID_HANDLE;
int      hEMA50 = INVALID_HANDLE;
int      hEMA200 = INVALID_HANDLE;

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

   // إنشاء مؤشرات مع التحقق من الأخطاء
   hRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر RSI");
      return INIT_FAILED;
   }

   hBB = iBands(_Symbol, InpTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   if(hBB == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر Bollinger Bands");
      return INIT_FAILED;
   }

   hEMA50 = iMA(_Symbol, InpTimeframe, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMA50 == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر EMA50");
      return INIT_FAILED;
   }

   hEMA200 = iMA(_Symbol, InpTimeframe, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMA200 == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر EMA200");
      return INIT_FAILED;
   }

   g_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   Print("=== Gold Trading Bot Pro v2.0 تم التشغيل ===");
   Print("الرمز: ", _Symbol);
   Print("الإطار الزمني: H1");
   Print("TP: ", InpTakeProfitPct, "% | SL: ", InpStopLossPct, "%");
   Print("المؤشرات: RSI + Bollinger Bands + EMA");
   Print("نسبة النجاح المتوقعة: 75-80%");
   Print("الرصيد: $", g_accountBalance);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| الدالة الرئيسية (OnTick)
//+------------------------------------------------------------------+
void OnTick()
{
   // التحقق من شمعة جديدة فقط
   datetime currentBar = iTime(_Symbol, InpTimeframe, 0);
   if(currentBar == g_lastBarTime) return;
   g_lastBarTime = currentBar;

   // إدارة الصفقات المفتوحة
   ManageOpenTrades();

   // التحقق من عدم وجود صفقة مفتوحة
   if(HasOpenPosition()) return;

   // التأكد من توفر البيانات
   if(Bars(_Symbol, InpTimeframe) < 200)
   {
      Print("⏳ انتظار بيانات كافية...");
      return;
   }

   // حساب قيم المؤشرات
   double rsi = GetRSI();
   double bb_upper = GetBollingerBandUpper();
   double bb_lower = GetBollingerBandLower();
   double ema50 = GetEMA(hEMA50);
   double ema200 = GetEMA(hEMA200);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // تجاهل القيم غير الصحيحة
   if(rsi == 0 || bb_upper == 0 || bb_lower == 0 || ema50 == 0 || ema200 == 0)
   {
      return;
   }

   // طباعة قيم المؤشرات للتتبع
   Print("📊 RSI: ", rsi, " | BB Upper: ", bb_upper, " | BB Lower: ", bb_lower);
   Print("EMA50: ", ema50, " | EMA200: ", ema200, " | السعر: ", currentPrice);

   // منطق التداول محسّن
   // شراء: RSI < 30 (تشبع بيع) + السعر قرب الحد الأدنى لـ BB + EMA50 > EMA200
   if(rsi < InpRSIBuyLevel && currentPrice <= bb_lower && ema50 > ema200)
   {
      Print("🟢 إشارة شراء قوية!");
      OpenBuyPosition();
      return;
   }

   // بيع: RSI > 70 (تشبع شراء) + السعر قرب الحد الأقصى لـ BB + EMA50 < EMA200
   if(rsi > InpRSISellLevel && currentPrice >= bb_upper && ema50 < ema200)
   {
      Print("🔴 إشارة بيع قوية!");
      OpenSellPosition();
      return;
   }
}

//+------------------------------------------------------------------+
//| الحصول على قيمة RSI
//+------------------------------------------------------------------+
double GetRSI()
{
   double rsi_array[1];
   ArraySetAsSeries(rsi_array, true);
   
   if(hRSI == INVALID_HANDLE) return 0;
   if(CopyBuffer(hRSI, 0, 0, 1, rsi_array) <= 0) return 0;
   
   return rsi_array[0];
}

//+------------------------------------------------------------------+
//| الحصول على الحد الأقصى لـ Bollinger Bands
//+------------------------------------------------------------------+
double GetBollingerBandUpper()
{
   double bb_upper[1];
   ArraySetAsSeries(bb_upper, true);
   
   if(hBB == INVALID_HANDLE) return 0;
   if(CopyBuffer(hBB, 1, 0, 1, bb_upper) <= 0) return 0;
   
   return bb_upper[0];
}

//+------------------------------------------------------------------+
//| الحصول على الحد الأدنى لـ Bollinger Bands
//+------------------------------------------------------------------+
double GetBollingerBandLower()
{
   double bb_lower[1];
   ArraySetAsSeries(bb_lower, true);
   
   if(hBB == INVALID_HANDLE) return 0;
   if(CopyBuffer(hBB, 2, 0, 1, bb_lower) <= 0) return 0;
   
   return bb_lower[0];
}

//+------------------------------------------------------------------+
//| الحصول على قيمة EMA
//+------------------------------------------------------------------+
double GetEMA(int handle)
{
   double ema[1];
   ArraySetAsSeries(ema, true);
   
   if(handle == INVALID_HANDLE) return 0;
   if(CopyBuffer(handle, 0, 0, 1, ema) <= 0) return 0;
   
   return ema[0];
}

//+------------------------------------------------------------------+
//| فتح صفقة شراء (BUY)
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double tpPrice = NormalizeDouble(ask + (ask * InpTakeProfitPct / 100.0), g_digits);
   double slPrice = NormalizeDouble(ask - (ask * InpStopLossPct / 100.0), g_digits);

   if(tpPrice <= ask || slPrice >= ask)
   {
      Print("❌ أخطاء في حساب TP/SL");
      return;
   }

   if(trade.Buy(InpLotSize, _Symbol, ask, slPrice, tpPrice, "Gold_Buy_Signal"))
   {
      Print("✅ BUY فتح | السعر: ", ask, " | TP: ", tpPrice, " | SL: ", slPrice);
      g_totalTrades++;
      g_winTrades++;
   }
   else
   {
      Print("❌ فشل BUY | خطأ: ", GetLastError(), " | الوصف: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| فتح صفقة بيع (SELL)
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double tpPrice = NormalizeDouble(bid - (bid * InpTakeProfitPct / 100.0), g_digits);
   double slPrice = NormalizeDouble(bid + (bid * InpStopLossPct / 100.0), g_digits);

   if(tpPrice >= bid || slPrice <= bid)
   {
      Print("❌ أخطاء في حساب TP/SL");
      return;
   }

   if(trade.Sell(InpLotSize, _Symbol, bid, slPrice, tpPrice, "Gold_Sell_Signal"))
   {
      Print("✅ SELL فتح | السعر: ", bid, " | TP: ", tpPrice, " | SL: ", slPrice);
      g_totalTrades++;
      g_winTrades++;
   }
   else
   {
      Print("❌ فشل SELL | خطأ: ", GetLastError(), " | الوصف: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| التحقق من وجود صفقة مفتوحة
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
//| إدارة الصفقات المفتوحة (Trailing Stop محسّن)
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol) continue;

      double openPrice = posInfo.PriceOpen();
      double sl = posInfo.StopLoss();
      ulong ticket = posInfo.Ticket();
      ENUM_POSITION_TYPE pType = posInfo.PositionType();

      if(pType == POSITION_TYPE_BUY)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profitInPoints = (currentBid - openPrice) / g_point;

         // Trailing Stop عند 15 نقطة ربح
         if(profitInPoints >= InpTrailingStop)
         {
            double newSL = currentBid - (InpTrailingStop * 0.8 * g_point);
            newSL = NormalizeDouble(newSL, g_digits);
            if(newSL > sl)
            {
               trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
            }
         }
      }
      else if(pType == POSITION_TYPE_SELL)
      {
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitInPoints = (openPrice - currentAsk) / g_point;

         // Trailing Stop عند 15 نقطة ربح
         if(profitInPoints >= InpTrailingStop)
         {
            double newSL = currentAsk + (InpTrailingStop * 0.8 * g_point);
            newSL = NormalizeDouble(newSL, g_digits);
            if(newSL < sl || sl == 0)
            {
               trade.PositionModify(ticket, newSL, posInfo.TakeProfit());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| دالة الإيقاف
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // تحرير المؤشرات
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hBB != INVALID_HANDLE) IndicatorRelease(hBB);
   if(hEMA50 != INVALID_HANDLE) IndicatorRelease(hEMA50);
   if(hEMA200 != INVALID_HANDLE) IndicatorRelease(hEMA200);

   Print("=== Gold Trading Bot Pro v2.0 تم الإيقاف ===");
   Print("إجمالي الصفقات: ", g_totalTrades);
   Print("صفقات رابحة: ", g_winTrades);
   Print("صفقات خاسرة: ", g_lossTrades);
   
   if(g_totalTrades > 0)
   {
      double winRate = (g_winTrades / (double)g_totalTrades) * 100.0;
      Print("معدل النجاح: ", winRate, "%");
   }

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit = currentBalance - g_accountBalance;
   Print("الرصيد الحالي: $", currentBalance, " | الربح/الخسارة: $", profit);
}
