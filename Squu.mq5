//+------------------------------------------------------------------+
//|                                     SuperTrend_Squeeze_EA.mq5    |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade Trade;

//--- Input Parameters
input group "SuperTrend Settings"
input int      InpATRPeriod = 10;       // ATR Period
input double   InpATRMultiplier = 3.0;  // ATR Multiplier

input group "Squeeze Momentum Settings"
input int      InpBBLength = 20;        // Bollinger Bands Length
input double   InpBBMult = 2.0;         // BB Multiplier
input int      InpKCLength = 20;        // Keltner Channel Length
input double   InpKCMult = 1.5;         // KC Multiplier
input double   InpSqzRedThreshold = 0.5;// Red Threshold
input double   InpSqzGreenThreshold = 0.5;// Green Threshold

input group "Risk Management"
input double   InpRiskPercent = 1.0;    // Risk Percentage
input double   InpRRRatio = 2.0;        // Risk/Reward Ratio
input int      InpMaxSpread = 20;       // Max Allowed Spread (points)

input group "Time Settings"
input string   InpTradeStart = "00:00"; // Trading Start Time
input string   InpTradeEnd = "23:59";   // Trading End Time

//--- Global Variables
int    SuperTrendHandle, SqueezeHandle;
double SuperTrendBuffer0[], SuperTrendBuffer1[], SuperTrendBuffer2[];
double SqueezeHisto[], SqueezeColors[];
datetime LastBarTime;
int      CurrentTrend = -1; // -1=Undefined, 0=Downtrend, 1=Uptrend
bool     IsNewBar = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize Indicators
   SuperTrendHandle = iCustom(_Symbol, _Period, "SuperTrend", InpATRPeriod, InpATRMultiplier);
   SqueezeHandle = iCustom(_Symbol, _Period, "SqueezeMomentumIndicator", InpBBLength, InpBBMult, InpKCLength, InpKCMult, PRICE_CLOSE);
   
   // Set Array Series
   ArraySetAsSeries(SuperTrendBuffer0, true);
   ArraySetAsSeries(SuperTrendBuffer1, true);
   ArraySetAsSeries(SuperTrendBuffer2, true);
   ArraySetAsSeries(SqueezeHisto, true);
   ArraySetAsSeries(SqueezeColors, true);
   
   // Verify Indicators
   if(SuperTrendHandle == INVALID_HANDLE || SqueezeHandle == INVALID_HANDLE)
   {
      Alert("Error loading indicators!");
      return(INIT_FAILED);
   }
   
   Trade.SetExpertMagicNumber(12345);
   Print("....................شروع ربات...................");
   Print("اندیکاتور 1: تایید شد");
   Print("اندیکاتور 2: تایید شد");
   Print("شروع ربات");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check New Bar
   IsNewBar = CheckNewBar();
   if(!IsNewBar) return;
   
   // Check Trading Time
   if(!IsTradeTime()) return;
   
   // Update Indicator Data
   if(!UpdateIndicatorData()) return;
   
   // Check Trend Change
   int NewTrend = CheckSuperTrendChange();
   
   // Process Trading Logic
   if(NewTrend != -1 && NewTrend != CurrentTrend)
   {
      ProcessTrendChange(NewTrend);
      CurrentTrend = NewTrend;
   }
   
   // Check for Reverse Trend
   CheckForReverseTrend();
}

//+------------------------------------------------------------------+
//| Check for New Bar                                                |
//+------------------------------------------------------------------+
bool CheckNewBar()
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
//| Update Indicator Data                                            |
//+------------------------------------------------------------------+
bool UpdateIndicatorData()
{
   // Copy SuperTrend Data (3 buffers)
   if(CopyBuffer(SuperTrendHandle, 0, 0, 3, SuperTrendBuffer0) != 3 ||
      CopyBuffer(SuperTrendHandle, 1, 0, 3, SuperTrendBuffer1) != 3 ||
      CopyBuffer(SuperTrendHandle, 2, 0, 3, SuperTrendBuffer2) != 3)
   {
      Print("Error copying SuperTrend data!");
      return false;
   }
   
   // Copy Squeeze Data (2 buffers)
   if(CopyBuffer(SqueezeHandle, 0, 0, 3, SqueezeHisto) != 3 ||
      CopyBuffer(SqueezeHandle, 1, 0, 3, SqueezeColors) != 3)
   {
      Print("Error copying Squeeze data!");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check SuperTrend Trend Change                                    |
//+------------------------------------------------------------------+
int CheckSuperTrendChange()
{
   int trendCandle1 = -1;
   int trendCandle2 = -1;
   
   // Check trend for candle 2 (previous)
   if(SuperTrendBuffer0[2] < SuperTrendBuffer1[2]) trendCandle2 = 1;
   else if(SuperTrendBuffer0[2] > SuperTrendBuffer1[2]) trendCandle2 = 0;
   
   // Check trend for candle 1 (current)
   if(SuperTrendBuffer0[1] < SuperTrendBuffer1[1]) trendCandle1 = 1;
   else if(SuperTrendBuffer0[1] > SuperTrendBuffer1[1]) trendCandle1 = 0;
   
   // Log trend values
   Print("...............................سیکنال یابی...................................");
   Print("تغییر روند: ", (trendCandle1 != trendCandle2 ? "OK" : "No Change"), " در تاریخ و ساعت ", TimeToString(TimeCurrent()), " قیمت کلوز: ", iClose(_Symbol, _Period, 1));
   
   if(trendCandle1 != trendCandle2) 
   {
      Print("رنگ فعلی اسکویزی: ", GetSqueezeColorName((int)SqueezeColors[1]));
      Print("مقدار اسکویزی: ", SqueezeHisto[1]);
      Print("مقایسه مقدار اسکویزی با آستانه: ", SqueezeHisto[1], " <=> ", (trendCandle1 == 1 ? InpSqzRedThreshold : InpSqzGreenThreshold));
      Print("نتیجه سیگنال: ", (IsSqueezeConfirmed(trendCandle1) ? "تیک" : "ضربدر"));
      return trendCandle1;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Process Trend Change                                             |
//+------------------------------------------------------------------+
void ProcessTrendChange(int newTrend)
{
   if(!IsSqueezeConfirmed(newTrend)) return;
   
   // Check Spread
   int currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > InpMaxSpread)
   {
      Print("Spread too high: ", currentSpread);
      return;
   }
   
   // Execute Trade
   ExecuteTrade(newTrend == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   double entryPrice = orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = SuperTrendBuffer2[1];
   double takeProfit = orderType == ORDER_TYPE_BUY ? entryPrice + (entryPrice - stopLoss) * InpRRRatio : entryPrice - (stopLoss - entryPrice) * InpRRRatio;
   
   double slDistance = MathAbs(entryPrice - stopLoss);
   double pipValue = GetPipValue();
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double lotSize = NormalizeDouble(riskAmount / (slDistance * pipValue), 2);
   
   // Apply Lot Size Limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMin(MathMax(lotSize, minLot), maxLot);
   
   // Execute Trade
   if(orderType == ORDER_TYPE_BUY)
      Trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Buy Order");
   else
      Trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Sell Order");
   
   // Log Trade Details
   Print("..................................................محاسبه ............................");
   Print("استاپ: ", stopLoss);
   Print("استاپ به پیپ: ", slDistance / GetPipValue());
   Print("تارکت: ", takeProfit);
   Print("تارکت به پیپ: ", MathAbs(takeProfit - entryPrice) / GetPipValue());
   Print("محاسبه حجم: ", lotSize);
}

//+------------------------------------------------------------------+
//| Check for Reverse Trend                                          |
//+------------------------------------------------------------------+
void CheckForReverseTrend()
{
   if(PositionsTotal() == 0) return;
   
   int currentTrend = CheckSuperTrendChange();
   if(currentTrend != -1 && currentTrend != CurrentTrend)
   {
      CloseAllPositions();
      Print("------------------خروج معامله--------------------");
      Print("خروج به دلیل تغییر روند: تیک");
   }
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetSymbol(i) == _Symbol)
         Trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| Get Pip Value                                                    |
//+------------------------------------------------------------------+
double GetPipValue()
{
   string symbol = _Symbol;
   double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pipValue = 0.01; // مقدار پیش‌فرض برای جفت‌های ارزی
   
   if(symbol == "XAUUSD" || symbol == "GOLD")
   {
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE); // معمولاً 100 برای طلا
      pipValue = pipSize * contractSize; // محاسبه صحیح برای طلا
   }
   else
   {
      pipValue = pipSize * 10; // برای جفت‌های ارزی استاندارد
   }
   
   return pipValue;
}

//+------------------------------------------------------------------+
//| Check Trading Time                                               |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
   datetime currentTime = TimeCurrent();
   datetime startTime = StringToTime(InpTradeStart);
   datetime endTime = StringToTime(InpTradeEnd);
   
   if(currentTime >= startTime && currentTime <= endTime)
      return true;
      
   return false;
}

//+------------------------------------------------------------------+
//| Get Squeeze Color Name                                           |
//+------------------------------------------------------------------+
string GetSqueezeColorName(int color)
{
   switch(color)
   {
      case 0: return "سبز تیره";
      case 1: return "سبز";
      case 2: return "قرمز";
      case 3: return "قرمز تیره";
      default: return "نامشخص";
   }
}

//+------------------------------------------------------------------+
//| Check Squeeze Confirmation                                       |
//+------------------------------------------------------------------+
bool IsSqueezeConfirmed(int trend)
{
   double sqzValue = SqueezeHisto[1];
   int    sqzColor = (int)SqueezeColors[1];
   
   if(trend == 1) // Uptrend
      return (sqzColor == 3 && sqzValue <= InpSqzRedThreshold);
   else if(trend == 0) // Downtrend
      return (sqzColor == 0 && sqzValue >= InpSqzGreenThreshold);
   
   return false;
}
//+------------------------------------------------------------------+
