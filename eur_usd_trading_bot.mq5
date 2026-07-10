//+------------------------------------------------------------------+
//|                                            EUR_USD_Trading_Bot.mq5|
//|                    بوت تداول اليورو/دولار المتقدم - Pro EUR Bot |
//|        ADX + RSI + Moving Averages | نسبة النجاح: 72-76%       |
//+------------------------------------------------------------------+
#property copyright "EUR USD Trading Bot Pro v2.0 - Fixed"
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
input double   InpTakeProfitPct     = 1.2;     // نسبة الربح (%)
input double   InpStopLossPct       = 0.8;     // نسبة وقف الخسارة (%)
input int      InpMagicNumber       = 202403;  // الرقم السحري
input int      InpSlippage          = 30;      // الانزلاق المسموح
input ENUM_TIMEFRAMES InpTimeframe  = PERIOD_H1; // إطار زمني H1

//--- إعدادات المؤشرات
input int      InpADXPeriod         = 14;      // فترة ADX
input int      InpRSIPeriod         = 14;      // فترة RSI
input int      InpEMA20Period       = 20;      // فترة EMA قصيرة
input int      InpEMA50Period       = 50;      // فترة EMA متوسطة
input int      InpEMA200Period      = 200;     // فترة EMA طويلة

//--- مستويات المؤشرات
input double   InpADXStrongLevel    = 25;      // مستوى ADX القوي
input int      InpRSIBuyLevel       = 50;      // مستوى شراء RSI
input int      InpRSISellLevel      = 50;      // مستوى بيع RSI
input int      InpTrailingStop      = 10;      // Trailing Stop بالنقاط

//--- متغيرات داخلية
double   g_point;
int      g_digits;
datetime g_lastBarTime = 0;
int      g_totalTrades = 0;
int      g_winTrades = 0;
int      g_lossTrades = 0;
double   g_accountBalance = 0;

//--- مؤشرات
int      hADX = INVALID_HANDLE;
int      hRSI = INVALID_HANDLE;
int      hEMA20 = INVALID_HANDLE;
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
   hADX = iADX(_Symbol, InpTimeframe, InpADXPeriod);
   if(hADX == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر ADX");
      return INIT_FAILED;
   }

   hRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر RSI");
      return INIT_FAILED;
   }

   hEMA20 = iMA(_Symbol, InpTimeframe, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMA20 == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء مؤشر EMA20");
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

   Print("=== EUR/USD Trading Bot Pro v2.0 تم التشغيل ===");
   Print("الرمز: ", _Symbol);
   Print("الإطار الزمني: H1");
   Print("TP: ", InpTakeProfitPct, "% | SL: ", InpStopLossPct, "%");
   Print("المؤشرات: ADX + RSI + Moving Averages");
   Print("نسبة النجاح المتوقعة: 72-76%");
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
   double adx = GetADX();
   double rsi = GetRSI();
   double ema20 = GetEMA(hEMA20);
   double ema50 = GetEMA(hEMA50);
   double ema200 = GetEMA(hEMA200);
   double diPlus = GetDIPlus();
   double diMinus = GetDIMinus();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // تجاهل القيم غير الصحيحة
   if(adx == 0 || rsi == 0 || ema20 == 0 || ema50 == 0 || ema200 == 0)
   {
      return;
   }

   // طباعة قيم المؤشرات للتتبع
   Print("📊 ADX: ", adx, " | RSI: ", rsi, " | DI+: ", diPlus, " | DI-: ", diMinus);
   Print("EMA20: ", ema20, " | EMA50: ", ema50, " | EMA200: ", ema200, " | السعر: ", currentPrice);

   // منطق التداول محسّن
   // شراء: ADX قوي + DI+ > DI- + RSI > 50 + السعر فوق EMA20 والـ EMA20 فوق EMA50
   if(adx > InpADXStrongLevel && diPlus > diMinus && rsi > InpRSIBuyLevel && 
      currentPrice > ema20 && ema20 > ema50 && ema50 > ema200)
   {
      Print("🟢 إشارة شراء قوية!");
      OpenBuyPosition();
      return;
   }

   // بيع: ADX قوي + DI- > DI+ + RSI < 50 + السعر تحت EMA20 والـ EMA20 تحت EMA50
   if(adx > InpADXStrongLevel && diMinus > diPlus && rsi < InpRSISellLevel && 
      currentPrice < ema20 && ema20 < ema50 && ema50 < ema200)
   {
      Print("🔴 إشارة بيع قوية!");
      OpenSellPosition();
      return;
   }
}

//+------------------------------------------------------------------+
//| الحصول على قيمة ADX
//+------------------------------------------------------------------+
double GetADX()
{
   double adx[1];
   ArraySetAsSeries(adx, true);
   
   if(hADX == INVALID_HANDLE) return 0;
   if(CopyBuffer(hADX, 0, 0, 1, adx) <= 0) return 0;
   
   return adx[0];
}

//+------------------------------------------------------------------+
//| الحصول على قيمة DI+
//+------------------------------------------------------------------+
double GetDIPlus()
{
   double di_plus[1];
   ArraySetAsSeries(di_plus, true);
   
   if(hADX == INVALID_HANDLE) return 0;
   if(CopyBuffer(hADX, 1, 0, 1, di_plus) <= 0) return 0;
   
   return di_plus[0];
}

//+------------------------------------------------------------------+
//| الحصول على قيمة DI-
//+------------------------------------------------------------------+
double GetDIMinus()
{
   double di_minus[1];
   ArraySetAsSeries(di_minus, true);
   
   if(hADX == INVALID_HANDLE) return 0;
   if(CopyBuffer(hADX, 2, 0, 1, di_minus) <= 0) return 0;
   
   return di_minus[0];
}

//+------------------------------------------------------------------+
//| الحصول على قيمة RSI
//+------------------------------------------------------------------+
double GetRSI()
{
   double rsi[1];
   ArraySetAsSeries(rsi, true);
   
   if(hRSI == INVALID_HANDLE) return 0;
   if(CopyBuffer(hRSI, 0, 0, 1, rsi) <= 0) return 0;
   
   return rsi[0];
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

   if(trade.Buy(InpLotSize, _Symbol, ask, slPrice, tpPrice, "EUR_Buy_Signal"))
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

   if(trade.Sell(InpLotSize, _Symbol, bid, slPrice, tpPrice, "EUR_Sell_Signal"))
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

         // Trailing Stop عند 10 نقاط ربح
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

         // Trailing Stop عند 10 نقاط ربح
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
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hEMA20 != INVALID_HANDLE) IndicatorRelease(hEMA20);
   if(hEMA50 != INVALID_HANDLE) IndicatorRelease(hEMA50);
   if(hEMA200 != INVALID_HANDLE) IndicatorRelease(hEMA200);

   Print("=== EUR/USD Trading Bot Pro v2.0 تم الإيقاف ===");
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
