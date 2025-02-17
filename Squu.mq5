//+------------------------------------------------------------------+
//|                                  SmartTrendSqueezeEA.mq5         |
//|                        Copyright 2024, Developed by ForexExpert   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
CTrade Trade;

//--- پارامترهای ورودی
input group "SuperTrend"
input int      ATRPeriod = 10;          // ATR Period
input double   ATRMultiplier = 3.0;     // ATR Multiplier

input group "Squeeze Momentum"
input int      BBLength = 20;           // Bollinger Bands Length
input double   BBMult = 2.0;            // BB Multiplier
input int      KCLength = 20;           // Keltner Channel Length
input double   KCMult = 1.5;            // KC Multiplier
input double   SqzRedThreshold = 0.5;   // Red Threshold
input double   SqzGreenThreshold = 0.5; // Green Threshold

input group "Risk Management"
input double   RiskPercent = 1.0;       // Risk Percentage
input double   RRRatio = 2.0;           // Risk/Reward Ratio
input int      MaxSpread = 20;          // Max Spread (points)

//--- متغیرهای سراسری
int    SuperTrendHandle, SqueezeHandle;
double SuperTrendBuffer0[], SuperTrendBuffer1[], SuperTrendBuffer2[];
double SqueezeHisto[], SqueezeColors[];
datetime LastBarTime;
int      CurrentTrend = -1; // -1=تعریف نشده, 0=نزولی, 1=صعودی

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
   
   Trade.SetExpertMagicNumber(12345);
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
   if(!IsNewBar()) return;
   
   // بروزرسانی داده‌ها
   if(CopyBuffer(SuperTrendHandle, 0, 0, 3, SuperTrendBuffer0) != 3 ||
      CopyBuffer(SuperTrendHandle, 1, 0, 3, SuperTrendBuffer1) != 3 ||
      CopyBuffer(SuperTrendHandle, 2, 0, 3, SuperTrendBuffer2) != 3 ||
      CopyBuffer(SqueezeHandle, 0, 0, 3, SqueezeHisto) != 3 ||
      CopyBuffer(SqueezeHandle, 1, 0, 3, SqueezeColors) != 3)
   {
      Print("خطا در دریافت داده‌ها!");
      return;
   }

   // تشخیص تغییر روند
   int trendCandle2 = GetTrendDirection(2); // کندل قبلی
   int trendCandle1 = GetTrendDirection(1); // کندل جاری
   
   if(trendCandle1 != trendCandle2)
   {
      string trendStr = (trendCandle1 == 1) ? "صعودی ▲" : "نزولی ▼";
      string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
      Print("====================== سیگنال یابی =====================");
      PrintFormat("تغییر روند: تایید شد در %s | قیمت بسته‌شدن: %.5f", timeStr, Close[1]);
      Print("روند جدید: ", trendStr);
      
      // بررسی اسکوییز
      double sqzValue = SqueezeHisto[1];
      int    sqzColor = (int)SqueezeColors[1];
      string colorStr = GetColorName(sqzColor);
      string thresholdStr = (trendCandle1 == 1) ? 
                           FormatDouble(SqzRedThreshold) + " (قرمز)" : 
                           FormatDouble(SqzGreenThreshold) + " (سبز)";
      
      PrintFormat("رنگ اسکوییز: %s | مقدار اسکوییز: %s", colorStr, FormatDouble(sqzValue));
      PrintFormat("مقایسه با آستانه: %s vs %s", FormatDouble(sqzValue), thresholdStr);

      // اعتبارسنجی سیگنال
      bool isSignalValid = false;
      if(trendCandle1 == 1 && sqzColor == 3 && sqzValue <= SqzRedThreshold) isSignalValid = true;
      if(trendCandle1 == 0 && sqzColor == 0 && sqzValue >= SqzGreenThreshold) isSignalValid = true;
      
      if(isSignalValid)
      {
         Print("نتیجه سیگنال: تایید شد ✓✓✓");
         ExecuteTrade(trendCandle1);
      }
      else
      {
         Print("نتیجه سیگنال: رد شد ✗✗✗");
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
   if(SuperTrendBuffer0[shift] < SuperTrendBuffer1[shift]) return 1;
   if(SuperTrendBuffer0[shift] > SuperTrendBuffer1[shift]) return 0;
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
//| مدیریت خروج                                                     |
//+------------------------------------------------------------------+
void CheckForExit()
{
   if(PositionsTotal() == 0) return;
   
   int currentTrend = GetTrendDirection(1);
   if(currentTrend != CurrentTrend)
   {
      CloseAllPositions();
      Print("====================== خروج معامله =====================");
      Print("دلیل خروج: تغییر روند ✓");
      Print("همه پوزیشن‌ها بسته شدند");
      Print("========================================================");
   }
}

//+------------------------------------------------------------------+
//| توابع کمکی                                                      |
//+------------------------------------------------------------------+
string GetColorName(int colorCode)
{
   switch(colorCode)
   {
      case 0: return "سبز تیره";
      case 1: return "سبز";
      case 2: return "قرمز تیره";
      case 3: return "قرمز";
      default: return "نامشخص";
   }
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

string FormatDouble(double value)
{
   return DoubleToString(value, 2);
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetSymbol(i) == _Symbol)
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
