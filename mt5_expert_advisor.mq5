//+------------------------------------------------------------------+
//| بوت تداول فوركس احترافي - Professional Forex Trading Bot MT5     |
//| استراتيجية: RSI + Moving Averages                               |
//| الزوج: EUR/USD                                                   |
//| الإطار الزمني: H1 (ساعة واحدة)                                   |
//+------------------------------------------------------------------+
#property copyright "Forex Trading Bot v1.0"
#property link      "https://github.com/y41983-ai/yahya"
#property version   "1.00"
#property strict

//--- المتغيرات الرئيسية
input double LotSize = 0.1;           // حجم العقد
input int StopLoss = 100;              // Stop Loss بالنقاط
input int TakeProfit = 200;            // Take Profit بالنقاط
input int RSIPeriod = 14;              // فترة مؤشر RSI
input int MAPeriod = 20;               // فترة المتوسط المتحرك
input int MaxOpenPositions = 2;        // أقصى صفقات مفتوحة
input bool UseEmailAlerts = true;      // تنبيهات البريد الإلكتروني

int ticket = 0;
double rsi, ma;

//+------------------------------------------------------------------+
//| دالة التهيئة                                                      |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("✅ تم تشغيل بوت التداول بنجاح!");
    Print("الزوج: EUR/USD | الإطار الزمني: H1");
    Print("Stop Loss: ", StopLoss, " نقطة | Take Profit: ", TakeProfit, " نقطة");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| دالة الحساب الرئيسية                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // تحديث مؤشرات التداول
    UpdateIndicators();
    
    // فحص إشارات التداول
    CheckTradingSignals();
    
    // إدارة الصفقات المفتوحة
    ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| تحديث المؤشرات                                                     |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
    // حساب RSI
    rsi = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE, 0);
    
    // حساب المتوسط المتحرك
    ma = iMA(_Symbol, _Period, MAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
}

//+------------------------------------------------------------------+
//| فحص إشارات التداول                                                |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
    // عد الصفقات المفتوحة
    int openPositions = CountOpenPositions();
    
    if(openPositions >= MaxOpenPositions) return;
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // إشارة الشراء
    if(rsi < 30 && Close[0] > ma && Close[1] <= ma)
    {
        OpenBuyPosition();
        return;
    }
    
    // إشارة البيع
    if(rsi > 70 && Close[0] < ma && Close[1] >= ma)
    {
        OpenSellPosition();
        return;
    }
}

//+------------------------------------------------------------------+
//| فتح صفقة شراء                                                      |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = bid - StopLoss * _Point;
    double tp = bid + TakeProfit * _Point;
    
    ticket = OrderSend(_Symbol, OP_BUY, LotSize, ask, 10, sl, tp, "BUY Signal", 0, 0, clrGreen);
    
    if(ticket > 0)
    {
        Print("✅ صفقة شراء فتحت بنجاح - Ticket: ", ticket);
        SendAlert("شراء", bid);
    }
    else
    {
        Print("❌ خطأ في فتح صفقة الشراء: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| فتح صفقة بيع                                                       |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = ask + StopLoss * _Point;
    double tp = ask - TakeProfit * _Point;
    
    ticket = OrderSend(_Symbol, OP_SELL, LotSize, bid, 10, sl, tp, "SELL Signal", 0, 0, clrRed);
    
    if(ticket > 0)
    {
        Print("✅ صفقة بيع فتحت بنجاح - Ticket: ", ticket);
        SendAlert("بيع", ask);
    }
    else
    {
        Print("❌ خطأ في فتح صفقة البيع: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| عد الصفقات المفتوحة                                                |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == _Symbol && OrderMagicNumber() == 0)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| إدارة الصفقات المفتوحة                                             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == _Symbol)
            {
                // التحقق من الربح/الخسارة
                double profit = OrderProfit();
                
                // إغلاق الصفقة إذا وصلت للهدف
                if(OrderType() == OP_BUY && Bid >= OrderTakeProfit())
                {
                    OrderClose(OrderTicket(), OrderOpenPrice(), Bid, 10, clrGreen);
                }
                else if(OrderType() == OP_SELL && Ask <= OrderTakeProfit())
                {
                    OrderClose(OrderTicket(), OrderOpenPrice(), Ask, 10, clrRed);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| إرسال التنبيهات                                                    |
//+------------------------------------------------------------------+
void SendAlert(string type, double price)
{
    string message = "🤖 بوت التداول - Alert\n";
    message += "الإشارة: " + type + "\n";
    message += "السعر: " + DoubleToString(price, _Digits) + "\n";
    message += "RSI: " + DoubleToString(rsi, 2) + "\n";
    message += "MA: " + DoubleToString(ma, _Digits);
    
    if(UseEmailAlerts)
    {
        SendMail("Forex Bot Alert", message);
    }
    
    Alert(message);
}

//+------------------------------------------------------------------+
//| إنهاء البرنامج                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("⛔ تم إيقاف بوت التداول");
}
