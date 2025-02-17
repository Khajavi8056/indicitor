//+------------------------------------------------------------------+
//|                                  SmartTrendSqueezeEA.mq5         |
//|                        Copyright 2024, Developed by ForexExpert   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

CTrade Trade;
ChartObjectLabel lblTrend, lblSqueeze;

//--- پارامترهای ورودی
input group "SuperTrend"
input int      ATRPeriod = 10;          // ATR Period
input double   ATRMultiplier = 3.0;     // ATR Multiplier

input group "Squeeze Momentum"
input int      BBLength = 20;           // Bollinger Bands Length
input double   BBMult = 2.0;            // BB Multiplier
input int      KCLength = 20;           // Keltner Channel Length
input double   KCMult = 1.5;            // KC Multiplier
input double   SqzRedThreshold = -0.5;  // Red Threshold (منفی)
input double   SqzGreenThreshold = 0.5; // Green Threshold (مثبت)

input group "Risk Management"
input double   RiskPercent = 1.0;       // Risk Percentage
input double   RRRatio = 2.0;           // Risk/Reward Ratio
input int      MaxSpread = 20;          // Max Spread (points)

input group "Display Settings"
input string   FontFace = "Arial";      // Font Name
input int      FontSize = 10;           // Font Size
input color    TrendColor = clrWhite;   // Trend Text Color
input color    SqueezeColor = clrWhite; // Squeeze Text Color

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
   // بارگذاری اندیکاتورها
   SuperTrendHandle = iCustom(_Symbol, _Period, "SuperTrend", ATRPeriod, ATRMultiplier);
   SqueezeHandle = iCustom(_Symbol, _Period, "SqueezeMomentumIndicator", BBLength, BBMult, KCLength, KCMult, PRICE_CLOSE);
   
   // تنظیم آرایه‌ها به صورت سری زمانی
   ArraySetAsSeries(SuperTrendBuffer0, true);
   ArraySetAsSeries(SuperTrendBuffer1, true);
   ArraySetAsSeries(SuperTrendBuffer2, true);
   ArraySetAsSeries(SqueezeHisto, true);
   ArraySetAsSeries(SqueezeColors, true);
   
   // بررسی خطاهای اندیکاتورها
   if(SuperTrendHandle == INVALID_HANDLE || SqueezeHandle == INVALID_HANDLE)
   {
      Alert("خطا در بارگذاری اندیکاتورها!");
      return(INIT_FAILED);
   }
   
   // تنظیمات اولیه
   Trade.SetExpertMagicNumber(12345);
   InitializeChartLabels();
   
   Print("======================= شروع ربات =======================");
   Print("اندیکاتور 1: SuperTrend → تایید شد");
   Print("اندیکاتور 2: Squeeze Momentum → تایید شد");
   Print("========================================================");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع دینی                                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   lblTrend.Delete();
   lblSqueeze.Delete();
}

//+------------------------------------------------------------------+
//| تابع تیک                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // بروزرسانی داده‌ها و نمایش وضعیت
   UpdateChartLabels();
   
   if(!IsNewBar()) return;
   
   // دریافت داده‌های اندیکاتورها
   if(!RefreshIndicatorData()) return;

   // تشخیص تغییر روند
   int trendCandle2 = GetTrendDirection(2); // کندل قبلی
   int trendCandle1 = GetTrendDirection(1); // کندل جاری
   
   if(trendCandle1 != trendCandle2)
   {
      ProcessSignal(trendCandle1, trendCandle2);
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
//| پردازش سیگنال                                                   |
//+------------------------------------------------------------------+
void ProcessSignal(int newTrend, int oldTrend)
{
   string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   string trendStr = (newTrend == 1) ? "صعودی ▲" : "نزولی ▼";
   
   Print("====================== سیگنال یابی =====================");
   PrintFormat("تغییر روند: %s → %s در %s | قیمت: %.5f", 
               GetTrendName(oldTrend), trendStr, timeStr, iClose(_Symbol, _Period, 1));

   // بررسی اسکوییز
   double sqzValue = SqueezeHisto[1];
   int    sqzColor = (int)SqueezeColors[1];
   string colorStr = GetColorName(sqzColor);
   
   PrintFormat("رنگ اسکوییز: %s | مقدار اسکوییز: %s", colorStr, DoubleToString(sqzValue, 2));

   // اعتبارسنجی سیگنال
   string rejectionReason = "";
   bool isSignalValid = ValidateSignal(newTrend, sqzColor, sqzValue, rejectionReason);
   
   if(isSignalValid)
   {
      Print("نتیجه سیگنال: تایید شد ✓✓✓");
      ExecuteTrade(newTrend);
      MarkTradeOnChart(newTrend);
   }
   else
   {
      PrintFormat("نتیجه سیگنال: رد شد ✗✗✗ | دلیل: %s", rejectionReason);
   }
   Print("========================================================");
}

//+------------------------------------------------------------------+
//| اعتبارسنجی سیگنال                                               |
//+------------------------------------------------------------------+
bool ValidateSignal(int trend, int color, double value, string &reason)
{
   // بررسی اسپرد
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread)
   {
      reason = "اسپرد بالاتر از حد مجاز";
      return false;
   }

   // بررسی شرایط رنگ و آستانه
   if(trend == 1) // صعودی
   {
      if(color != 2) // قرمز تیره
      {
         reason = "رنگ اسکوییز قرمز تیره نیست";
         return false;
      }
      if(value > SqzRedThreshold)
      {
         reason = "مقدار اسکوییز از آستانه قرمز بالاتر است";
         return false;
      }
   }
   else if(trend == 0) // نزولی
   {
      if(color != 0) // سبز تیره
      {
         reason = "رنگ اسکوییز سبز تیره نیست";
         return false;
      }
      if(value < SqzGreenThreshold)
      {
         reason = "مقدار اسکوییز از آستانه سبز پایین‌تر است";
         return false;
      }
   }
   
   return true;
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
   if(lotSize <= 0)
   {
      Print("خطا: حجم معامله نامعتبر!");
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
   PrintFormat("ورود به معامله: %s | حجم: %.2f لات", (trendDirection == 1 ? "خرید" : "فروش"), lotSize);
   PrintFormat("استاپ لاس: %.5f | تارگت: %.5f", stopLoss, takeProfit);
   PrintFormat("فاصله پیپ: SL=%.1f | TP=%.1f", PriceToPips(slDistance), PriceToPips(slDistance * RRRatio));
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
//| توابع کمکی پیشرفته                                              |
//+------------------------------------------------------------------+
void InitializeChartLabels()
{
   // ایجاد لیبل برای روند
   lblTrend.Create(0, "lblTrend", 0, 10, 20);
   lblTrend.Description("روند فعلی: ");
   lblTrend.Font(FontFace);
   lblTrend.FontSize(FontSize);
   lblTrend.Color(TrendColor);
   
   // ایجاد لیبل برای اسکوییز
   lblSqueeze.Create(0, "lblSqueeze", 0, 10, 40);
   lblSqueeze.Description("وضعیت اسکوییز: ");
   lblSqueeze.Font(FontFace);
   lblSqueeze.FontSize(FontSize);
   lblSqueeze.Color(SqueezeColor);
}

void UpdateChartLabels()
{
   // بروزرسانی متن و رنگ لیبل‌ها
   string trendText = "روند فعلی: " + GetTrendName(GetTrendDirection(1));
   string squeezeText = "وضعیت اسکوییز: " + GetColorName((int)SqueezeColors[0]);
   
   lblTrend.Description(trendText);
   lblSqueeze.Description(squeezeText);
   
   // تغییر رنگ متن اسکوییز بر اساس رنگ فعلی
   color squeezeColor = GetSqueezeColor((int)SqueezeColors[0]);
   lblSqueeze.Color(squeezeColor);
}

color GetSqueezeColor(int colorCode)
{
   switch(colorCode)
   {
      case 0: return clrDarkGreen;
      case 1: return clrLime;
      case 2: return clrDarkRed;
      case 3: return clrRed;
      default: return clrGray;
   }
}

string GetTrendName(int trend)
{
   switch(trend)
   {
      case 1: return "صعودی ▲";
      case 0: return "نزولی ▼";
      default: return "نامشخص";
   }
}

string GetColorName(int colorCode)
{
   switch(colorCode)
   {
      case 0: return "سبز تیره";
      case 1: return "سبز روشن";
      case 2: return "قرمز تیره";
      case 3: return "قرمز روشن";
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
      return pipSize * 100; // 1 pip = 1 دلار برای طلا
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

bool RefreshIndicatorData()
{
   return CopyBuffer(SuperTrendHandle, 0, 0, 3, SuperTrendBuffer0) == 3 &&
          CopyBuffer(SuperTrendHandle, 1, 0, 3, SuperTrendBuffer1) == 3 &&
          CopyBuffer(SuperTrendHandle, 2, 0, 3, SuperTrendBuffer2) == 3 &&
          CopyBuffer(SqueezeHandle, 0, 0, 3, SqueezeHisto) == 3 &&
          CopyBuffer(SqueezeHandle, 1, 0, 3, SqueezeColors) == 3;
}

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
