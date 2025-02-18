//+------------------------------------------------------------------+
//| DashboardLibrary.mqh                                             |
//| کتابخانه نمایش اطلاعات گرافیکی روی چارت                         |
//+------------------------------------------------------------------+
#ifndef DASHBOARD_LIBRARY_MQH
#define DASHBOARD_LIBRARY_MQH

#include <Trade\Trade.mqh>

//--- تعریف متغیر Trade به‌صورت extern
extern CTrade Trade;

//--- پارامترهای ورودی
input bool ShowPanel = true; // فعال/غیرفعال کردن نمایش پنل

//+------------------------------------------------------------------+
//| نمایش اطلاعات گرافیکی پیشرفته روی چارت                           |
//+------------------------------------------------------------------+
void DisplayInfoOnChart(double riskPercent, int maxSpread)
{
   //--- حذف آبجکت‌های قدیمی
   if (!ShowPanel) {
      ObjectsDeleteAll(0, "GUI_");
      return;
   }

   //--- تنظیمات اولیه
   int baseX = 10; // موقعیت X پایه (سمت چپ)
   int baseY = 30; // موقعیت Y پایه

   // 1. سرعت‌سنج ریسک (Speedometer)
   CreateGauge(baseX + 120, baseY + 150, 50, "RiskGauge", CalculateRiskPercentage(), 0, 100);

   // 2. نوارهای پیشرفت (Progress Bars)
   CreateProgressBar(baseX, baseY + 40, 200, 15, "RiskBar", riskPercent, 0, 100, clrDodgerBlue);
   CreateProgressBar(baseX, baseY + 70, 200, 15, "SpreadBar", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), 0, maxSpread, clrOrangeRed);
   CreateProgressBar(baseX, baseY + 100, 200, 15, "TradesBar", PositionsTotal(), 0, 10, clrMediumPurple);

   // 3. شاخص‌های وضعیت (Status Indicators)
   CreateStatusIndicator(baseX + 220, baseY + 40, "TradeSignal", GetTradeSignalStatus());
   CreateStatusIndicator(baseX + 220, baseY + 80, "SqueezeMomentum", GetSqueezeMomentumStatus());

   // 4. پنل اطلاعات زنده
   DisplayLiveInfoPanel(baseX, baseY);

   // 5. جدول اطلاعات
   DisplayInfoTable(baseX, baseY + 200);
}

//+------------------------------------------------------------------+
//| ایجاد سرعت‌سنج گرافیکی                                          |
//+------------------------------------------------------------------+
void CreateGauge(int x, int y, int radius, string name, double value, double minVal, double maxVal)
{
   // حلقه بیرونی
   ObjectCreate(0, "GUI_" + name + "_Outer", OBJ_TREND, 0, 0, 0);
   ObjectSetInteger(0, "GUI_" + name + "_Outer", OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, "GUI_" + name + "_Outer", OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, "GUI_" + name + "_Outer", OBJPROP_RAY, false);
   
   // نشانگر
   double angle = 135 + (270 * (value - minVal) / (maxVal - minVal));
   int needleX = x + (int)(radius * MathCos(angle * M_PI / 180));
   int needleY = y + (int)(radius * MathSin(angle * M_PI / 180));
   
   ObjectCreate(0, "GUI_" + name + "_Needle", OBJ_TREND, 0, 0, 0);
   ObjectSetInteger(0, "GUI_" + name + "_Needle", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "GUI_" + name + "_Needle", OBJPROP_WIDTH, 2);
   ObjectMove(0, "GUI_" + name + "_Needle", 0, x, y);
   ObjectMove(0, "GUI_" + name + "_Needle", 1, needleX, needleY);
}

//+------------------------------------------------------------------+
//| ایجاد نوار پیشرفت                                               |
//+------------------------------------------------------------------+
void CreateProgressBar(int x, int y, int width, int height, string name, double value, double minVal, double maxVal, color clr)
{
   // پس‌زمینه
   ObjectCreate(0, "GUI_" + name + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "GUI_" + name + "_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "GUI_" + name + "_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "GUI_" + name + "_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, "GUI_" + name + "_BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, "GUI_" + name + "_BG", OBJPROP_BGCOLOR, clrDarkGray);
   
   // پیشرفت
   double fillWidth = width * (value - minVal) / (maxVal - minVal);
   ObjectCreate(0, "GUI_" + name + "_Fill", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "GUI_" + name + "_Fill", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "GUI_" + name + "_Fill", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "GUI_" + name + "_Fill", OBJPROP_XSIZE, (int)fillWidth);
   ObjectSetInteger(0, "GUI_" + name + "_Fill", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, "GUI_" + name + "_Fill", OBJPROP_BGCOLOR, clr);
}

//+------------------------------------------------------------------+
//| ایجاد شاخص وضعیت                                                |
//+------------------------------------------------------------------+
void CreateStatusIndicator(int x, int y, string name, string status)
{
   color indicatorColor = clrGray;
   string symbol = "◌";
   
   if(status == "Bullish") { indicatorColor = clrLimeGreen; symbol = "▲"; }
   else if(status == "Bearish") { indicatorColor = clrCrimson; symbol = "▼"; }
   else if(status == "Active") { indicatorColor = clrDodgerBlue; symbol = "⚡"; }

   ObjectCreate(0, "GUI_" + name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "GUI_" + name, OBJPROP_TEXT, symbol);
   ObjectSetInteger(0, "GUI_" + name, OBJPROP_COLOR, indicatorColor);
   ObjectSetInteger(0, "GUI_" + name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "GUI_" + name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "GUI_" + name, OBJPROP_FONTSIZE, 20);
}

//+------------------------------------------------------------------+
//| نمایش پنل اطلاعات زنده                                          |
//+------------------------------------------------------------------+
void DisplayLiveInfoPanel(int x, int y)
{
   string infoText = StringFormat(
      "⚡ Live Trading Dashboard ⚡\n"
      "➤ Equity: $%.2f\n"
      "➤ Free Margin: $%.2f\n"
      "➤ Spread: %d pts\n"
      "➤ Active Trades: %d\n"
      "➤ Daily Profit: $%.2f\n"
      "➤ Risk Exposure: %.1f%%\n"
      "➤ Trend Strength: %s",
      AccountInfoDouble(ACCOUNT_EQUITY),
      AccountInfoDouble(ACCOUNT_MARGIN_FREE),
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      PositionsTotal(),
      CalculateDailyProfit(),
      CalculateRiskPercentage(),
      GetTrendStrength()
   );

   ObjectCreate(0, "GUI_InfoPanel", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "GUI_InfoPanel", OBJPROP_TEXT, infoText);
   ObjectSetInteger(0, "GUI_InfoPanel", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "GUI_InfoPanel", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "GUI_InfoPanel", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "GUI_InfoPanel", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "GUI_InfoPanel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| نمایش جدول اطلاعات                                               |
//+------------------------------------------------------------------+
void DisplayInfoTable(int x, int y)
{
   string tableText = StringFormat(
      "┌──────────────────────────────┐\n"
      "│          Trade Stats         │\n"
      "├──────────────────────────────┤\n"
      "│ Equity:         $%.2f       │\n"
      "│ Free Margin:    $%.2f       │\n"
      "│ Spread:         %d pts      │\n"
      "│ Active Trades:  %d          │\n"
      "│ Daily Profit:   $%.2f       │\n"
      "│ Risk Exposure:  %.1f%%      │\n"
      "│ Trend Strength: %s          │\n"
      "└──────────────────────────────┘",
      AccountInfoDouble(ACCOUNT_EQUITY),
      AccountInfoDouble(ACCOUNT_MARGIN_FREE),
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      PositionsTotal(),
      CalculateDailyProfit(),
      CalculateRiskPercentage(),
      GetTrendStrength()
   );

   ObjectCreate(0, "GUI_InfoTable", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "GUI_InfoTable", OBJPROP_TEXT, tableText);
   ObjectSetInteger(0, "GUI_InfoTable", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "GUI_InfoTable", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "GUI_InfoTable", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "GUI_InfoTable", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "GUI_InfoTable", OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| محاسبه درصد ریسک حساب                                           |
//+------------------------------------------------------------------+
double CalculateRiskPercentage()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity - balance) / balance * 100;
}

//+------------------------------------------------------------------+
//| محاسبه سود روزانه                                               |
//+------------------------------------------------------------------+
double CalculateDailyProfit()
{
   // این تابع می‌تواند با توجه به نیاز شما پیاده‌سازی شود
   return 0.0;
}

//+------------------------------------------------------------------+
//| تشخیص قدرت روند                                                 |
//+------------------------------------------------------------------+
string GetTrendStrength()
{
   // این تابع می‌تواند با توجه به نیاز شما پیاده‌سازی شود
   return "Strong";
}

//+------------------------------------------------------------------+
//| تشخیص وضعیت سیگنال معاملاتی                                     |
//+------------------------------------------------------------------+
string GetTradeSignalStatus()
{
   // این تابع می‌تواند با توجه به نیاز شما پیاده‌سازی شود
   return "Bullish";
}

//+------------------------------------------------------------------+
//| تشخیص وضعیت اسکوییز                                             |
//+------------------------------------------------------------------+
string GetSqueezeMomentumStatus()
{
   // این تابع می‌تواند با توجه به نیاز شما پیاده‌سازی شود
   return "Active";
}

#endif
