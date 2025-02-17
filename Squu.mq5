//+------------------------------------------------------------------+
//|                                  SmartTrendSqueezeEA.mq5         |
//|                        Copyright 2024, Developed by ForexExpert   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "4.00"
#property strict

#include <Trade\Trade.mqh>
CTrade Trade;

//--- پارامترهای ورودی
input group "General Settings"
input ulong    MagicNumber  = 12345;    // Magic Number

input group "SuperTrend"
input int      ATRPeriod = 10;          // ATR Period
input double   ATRMultiplier = 3.0;     // ATR Multiplier

input group "Squeeze Momentum"
input int      BBLength = 20;           // Bollinger Bands Length
input double   BBMult = 2.0;            // BB Multiplier
input int      KCLength = 20;           // Keltner Channel Length
input double   KCMult = 1.5;            // KC Multiplier
input double   SqzRedThreshold = -0.5;  // آستانه قرمز (منفی)
input double   SqzGreenThreshold = 0.5; // آستانه سبز (مثبت)

input group "Squeeze Color Buffers"
input int      DarkGreenBuffer = 0;     // بافر سبز تیره
input int      LightGreenBuffer = 1;    // بافر سبز روشن
input int      DarkRedBuffer = 2;       // بافر قرمز تیره
input int      LightRedBuffer = 3;      // بافر قرمز روشن

input group "Risk Management"
input double   RiskPercent = 1.0;       // درصد ریسک
input double   RRRatio = 2.0;           // نسبت ریسک/پاداش
input int      MaxSpread = 20;          // حداکثر اسپرد (پیپ)

//--- متغیرهای سراسری
int    SuperTrendHandle, SqueezeHandle;
double SuperTrendBuffer0[], SuperTrendBuffer1[], SuperTrendBuffer2[];
double SqueezeHisto[], SqueezeColors[];
datetime LastBarTime;

//+------------------------------------------------------------------+
//| تابع اولیه                                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   SuperTrendHandle = iCustom(_Symbol, _Period, "SuperTrend", ATRPeriod, ATRMultiplier);
   SqueezeHandle = iCustom(_Symbol, _Period, "SqueezeMomentumIndicator", BBLength, BBMult, KCLength, KCMult, PRICE_CLOSE);
   
   ArraySetAsSeries(SuperTrendBuffer0, true);
   ArraySetAsSeries(SuperTrendBuffer1, true);
   ArraySetAsSeries(SuperTrendBuffer2, true);
   ArraySetAsSeries(SqueezeHisto, true);
   ArraySetAsSeries(SqueezeColors, true);
   
   if(SuperTrendHandle == INVALID_HANDLE || SqueezeHandle == INVALID_HANDLE)
   {
      Alert("خطا در بارگذاری اندیکاتورها!");
      return(INIT_FAILED);
   }
   
   Trade.SetExpertMagicNumber(MagicNumber);
   Print("======================= شروع ربات =======================");
   Print("اندیکاتور 1: SuperTrend → تایید شد");
   Print("اندیکاتور 2: Squeeze Momentum → تایید شد");
   Print("========================================================");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع تیک                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // بروزرسانی داده‌ها در هر تیک
   if(CopyBuffer(SuperTrendHandle, 0, 0, 3, SuperTrendBuffer0) != 3 ||
      CopyBuffer(SuperTrendHandle, 1, 0, 3, SuperTrendBuffer1) != 3 ||
      CopyBuffer(SuperTrendHandle, 2, 0, 3, SuperTrendBuffer2) != 3 ||
      CopyBuffer(SqueezeHandle, 0, 0, 3, SqueezeHisto) != 3 ||
      CopyBuffer(SqueezeHandle, 1, 0, 3, SqueezeColors) != 3)
   {
      Print("خطا در دریافت داده‌ها!");
      return;
   }

   // نمایش اطلاعات روی چارت در هر تیک
   DisplayInfoOnChart();
   
   if(!IsNewBar()) return;

   // تشخیص تغییر روند
   int trendCandle2 = GetTrendDirection(2); // کندل قبلی
   int trendCandle1 = GetTrendDirection(1); // کندل جاری
   
   if(trendCandle1 != trendCandle2)
   {
      string trendStr = (trendCandle1 == 1) ? "صعودی ▲" : "نزولی ▼";
      string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
      Print("====================== سیگنال یابی =====================");
      PrintFormat("تغییر روند: تایید شد در %s | قیمت بسته‌شدن: %.5f", timeStr, iClose(_Symbol, _Period, 1));
      Print("روند جدید: ", trendStr);
      
      // بررسی اسکوییز
      double sqzValue = SqueezeHisto[1];
      int    sqzColor = (int)SqueezeColors[1];
      string colorStr = GetColorName(sqzColor);
      string thresholdStr = (trendCandle1 == 1) ? 
                           DoubleToString(SqzRedThreshold, 2) + " (قرمز)" : 
                           DoubleToString(SqzGreenThreshold, 2) + " (سبز)";
      
      PrintFormat("رنگ اسکوییز: %s | مقدار اسکوییز: %s", colorStr, DoubleToString(sqzValue, 2));
      PrintFormat("مقایسه با آستانه: %s vs %s", DoubleToString(sqzValue, 2), thresholdStr);

      // اعتبارسنجی سیگنال
      bool isSignalValid = false;
      string reason = "";
      if(trendCandle1 == 1) // صعودی
      {
         if(sqzColor == DarkRedBuffer && sqzValue <= SqzRedThreshold)
         {
            isSignalValid = true;
         }
         else
         {
            if(sqzColor != DarkRedBuffer) reason += "رنگ اسکوییز قرمز تیره نیست. ";
            if(sqzValue > SqzRedThreshold) reason += "مقدار اسکوییز از آستانه بیشتر است.";
         }
      }
      else if(trendCandle1 == 0) // نزولی
      {
         if(sqzColor == DarkGreenBuffer && sqzValue >= SqzGreenThreshold)
         {
            isSignalValid = true;
         }
         else
         {
            if(sqzColor != DarkGreenBuffer) reason += "رنگ اسکوییز سبز تیره نیست. ";
            if(sqzValue < SqzGreenThreshold) reason += "مقدار اسکوییز از آستانه کمتر است.";
         }
      }
      
      if(isSignalValid)
      {
         Print("نتیجه سیگنال: تایید شد ✓✓✓");
         ExecuteTrade(trendCandle1);
         MarkTradeOnChart(trendCandle1);
      }
      else
      {
         Print("نتیجه سیگنال: رد شد ✗✗✗");
         Print("دلیل رد: ", (reason == "" ? "نامشخص" : reason));
      }
      Print("========================================================");
   }
   
   // بررسی خروج
   CheckForExit();
}

//+------------------------------------------------------------------+
//| تشخیص جهت روند                                                  |
//+------------------------------------------------------------------+
int GetTrendDirection(int shift)
{
   if(SuperTrendBuffer0[shift] < SuperTrendBuffer1[shift]) return 1; // صعودی
   if(SuperTrendBuffer0[shift] > SuperTrendBuffer1[shift]) return 0; // نزولی
   return -1;
}

//+------------------------------------------------------------------+
//| اجرای معامله                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(int trendDirection)
{
   // محاسبه پارامترها
   double entryPrice = (trendDirection == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = SuperTrendBuffer2[1];
   double slDistance = MathAbs(entryPrice - stopLoss);
   double pipValue = GetPipValue();
   
   // محاسبه حجم با مدیریت ریسک
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
   double lotSize = riskAmount / (slDistance * pipValue);
   lotSize = NormalizeLotSize(lotSize);
   
   // محاسبه تارگت
   double takeProfit = (trendDirection == 1) ? 
                      entryPrice + (slDistance * RRRatio) : 
                      entryPrice - (slDistance * RRRatio);
   
   // اعتبارسنجی نهایی
   if(lotSize <= 0 || SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread)
   {
      Print("خطا در اجرای معامله: حجم نامعتبر یا اسپرد بالا!");
      return;
   }

   // اجرای دستور
   string comment = (trendDirection == 1) ? "Buy Signal" : "Sell Signal";
   if(trendDirection == 1)
      Trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, comment);
   else
      Trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, comment);
   
   // لاگ جزئیات
   Print("===================== جزئیات معامله ======================");
   PrintFormat("استاپ لاس: %.5f | تارگت: %.5f", stopLoss, takeProfit);
   PrintFormat("فاصله پیپ: SL=%.1f pip | TP=%.1f pip", PriceToPips(slDistance), PriceToPips(slDistance * RRRatio));
   PrintFormat("حجم معامله: %.2f لات | مبلغ ریسک: %.2f $", lotSize, riskAmount);
   Print("========================================================");
}

//+------------------------------------------------------------------+
//| علامت‌گذاری روی چارت                                            |
//+------------------------------------------------------------------+
void MarkTradeOnChart(int trendDirection)
{
   string arrowName = "TradeArrow_" + IntegerToString(TimeCurrent());
   if(trendDirection == 1)
   {
      ObjectCreate(0, arrowName, OBJ_ARROW_BUY, 0, TimeCurrent(), iClose(_Symbol, _Period, 1));
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrGreen);
   }
   else
   {
      ObjectCreate(0, arrowName, OBJ_ARROW_SELL, 0, TimeCurrent(), iClose(_Symbol, _Period, 1));
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
   }
}

//+------------------------------------------------------------------+
//| نمایش اطلاعات روی چارت                                          |
//+------------------------------------------------------------------+
void DisplayInfoOnChart()
{
   int currentTrend = GetTrendDirection(0); // روند فعلی
   string trendStr = (currentTrend == 1) ? "صعودی ▲" : (currentTrend == 0) ? "نزولی ▼" : "نامشخص";
   int currentColor = (int)SqueezeColors[0];
   string colorStr = GetColorName(currentColor);
   
   string infoText = "روند فعلی سوپرترند: " + trendStr + "\n" +
                     "رنگ فعلی اسکوییز: " + colorStr;
   
   ObjectDelete(0, "InfoText");
   ObjectCreate(0, "InfoText", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "InfoText", OBJPROP_TEXT, infoText);
   ObjectSetInteger(0, "InfoText", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "InfoText", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "InfoText", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "InfoText", OBJPROP_FONTSIZE, 12);
}

//+------------------------------------------------------------------+
//| مدیریت خروج                                                     |
//+------------------------------------------------------------------+
void CheckForExit()
{
   bool closeBuy = false;
   bool closeSell = false;
   
   // شرط خروج برای پوزیشن‌های خرید: بافر0 > بافر1 در کندل قبلی
   if(SuperTrendBuffer0[1] > SuperTrendBuffer1[1]) 
   {
      closeBuy = true;
   }
   
   // شرط خروج برای پوزیشن‌های فروش: بافر0 < بافر1 در کندل قبلی
   if(SuperTrendBuffer0[1] < SuperTrendBuffer1[1]) 
   {
      closeSell = true;
   }
   
   // بستن پوزیشن‌ها
   if(closeBuy || closeSell)
   {
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if((type == POSITION_TYPE_BUY && closeBuy) || (type == POSITION_TYPE_SELL && closeSell))
            {
               Trade.PositionClose(ticket);
            }
         }
      }
      
      // چاپ لاگ
      if(closeBuy)
      {
         Print("====================== خروج معامله =====================");
         Print("دلیل خروج: تغییر روند به نزولی ✓");
         Print("همه پوزیشن‌های خرید بسته شدند");
         Print("========================================================");
      }
      if(closeSell)
      {
         Print("====================== خروج معامله =====================");
         Print("دلیل خروج: تغییر روند به صعودی ✓");
         Print("همه پوزیشن‌های فروش بسته شدند");
         Print("========================================================");
      }
   }
}

//+------------------------------------------------------------------+
//| توابع کمکی                                                      |
//+------------------------------------------------------------------+
string GetColorName(int colorCode)
{
   if(colorCode == DarkGreenBuffer) return "سبز تیره";
   if(colorCode == LightGreenBuffer) return "سبز روشن";
   if(colorCode == DarkRedBuffer) return "قرمز تیره";
   if(colorCode == LightRedBuffer) return "قرمز روشن";
   return "نامشخص";
}

double NormalizeLotSize(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathRound(lots / lotStep) * lotStep;
   return MathMin(MathMax(lots, minLot), maxLot);
}

double GetPipValue()
{
   string symbol = _Symbol;
   double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(symbol == "XAUUSD" || symbol == "GOLD")
      return pipSize * 100; // ارزش هر 0.01 برای طلا = 1 دلار
   return pipSize * 10;
}

double PriceToPips(double price)
{
   return price / GetPipValue();
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         Trade.PositionClose(ticket);
   }
}

bool IsNewBar()
{
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(currentTime != LastBarTime)
   {
      LastBarTime = currentTime;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
