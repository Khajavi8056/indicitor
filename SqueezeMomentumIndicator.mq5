#property copyright "Copyright 2020,khajavi."
#property description "Translate from Pine: Squeeze Momentum Indicator (Modified Version)"
#property link      "hipoAlgoritm"
#property version   "1.10"

#property indicator_separate_window
#property indicator_buffers 9 // 5 بافر اصلی + 4 بافر جدید
#property indicator_plots   2  // فقط ۲ پلات اصلی (بدون افزودن پلات جدید)

//--- پیکربندی هیستوگرام رنگی اصلی
#property indicator_label1  "SqueezeMomentum"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen, clrGreen, clrRed, clrMaroon
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- پیکربندی خط فلش‌ها
#property indicator_label2  "SqueezeMomentumLine"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrDodgerBlue, clrBlack, clrGray
#property indicator_style2  STYLE_SOLID
#property indicator_width2  5

//--- پارامترهای ورودی
input int      lengthBB                 = 20;
input double   multBB                   = 2.0;
input int      lengthKC                 = 20;
input double   multKC                   = 1.5;
input ENUM_APPLIED_PRICE  applied_price = PRICE_CLOSE;

//--- بافرهای اصلی
double iB[], iC[], lB[], lC[], srce[];
//--- بافرهای جدید برای ذخیره مقادیر رنگ‌ها (بدون نمایش در چارت)
double bufferLimeGreen[], bufferGreen[], bufferRed[], bufferMaroon[];

int kc, bb;
static int MINBAR = MathMax(lengthBB, lengthKC) + 1;

//+------------------------------------------------------------------+
//| تابع اولیه                                                      |
//+------------------------------------------------------------------+
int OnInit() {
   //--- تنظیم بافرهای اصلی
   SetIndexBuffer(0, iB,    INDICATOR_DATA);
   SetIndexBuffer(1, iC,    INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, lB,    INDICATOR_DATA);
   SetIndexBuffer(3, lC,    INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, srce,  INDICATOR_CALCULATIONS);
   
   //--- تنظیم بافرهای جدید (بدون اتصال به پلات)
   SetIndexBuffer(5, bufferLimeGreen, INDICATOR_DATA);
   SetIndexBuffer(6, bufferGreen,     INDICATOR_DATA);
   SetIndexBuffer(7, bufferRed,       INDICATOR_DATA);
   SetIndexBuffer(8, bufferMaroon,    INDICATOR_DATA);

   ArraySetAsSeries(iB, true);
   ArraySetAsSeries(iC, true);
   ArraySetAsSeries(srce, true);
   ArraySetAsSeries(lB, true);
   ArraySetAsSeries(lC, true);

   IndicatorSetString(INDICATOR_SHORTNAME,"SQZMOM+");
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   kc = iCustom(NULL, 0, "KeltnerChannel", lengthKC, multKC, false, MODE_SMA, applied_price);
   bb = iBands(NULL, 0, lengthBB, 0, multBB, applied_price);
   
   return(kc != INVALID_HANDLE && bb != INVALID_HANDLE ? INIT_SUCCEEDED : INIT_FAILED);
}

//+------------------------------------------------------------------+
//| تابع محاسبات                                                    |
//+------------------------------------------------------------------+
void GetValue(const double& h[], const double& l[], const double& c[], int shift) {
   double bbt[1], bbb[1], kct[1], kcb[1];
   CopyBuffer(bb, 1, shift, 1, bbt);
   CopyBuffer(bb, 2, shift, 1, bbb);
   CopyBuffer(kc, 0, shift, 1, kct);
   CopyBuffer(kc, 2, shift, 1, kcb);

   bool sqzOn  = (bbb[0] > kcb[0]) && (bbt[0] < kct[0]);
   bool sqzOff = (bbb[0] < kcb[0]) && (bbt[0] > kct[0]);
   bool noSqz  = !sqzOn && !sqzOff;

   int indh = iHighest(NULL, 0, MODE_HIGH, lengthKC, shift);
   int indl = iLowest(NULL, 0, MODE_LOW, lengthKC, shift);
   double avg = (h[indh] + l[indl]) / 2;
   avg = (avg + (kct[0] + kcb[0]) / 2) / 2;
   srce[shift] = c[shift] - avg;

   double error;
   iB[shift] = LinearRegression(srce, lengthKC, shift, error);

   //--- تنظیم رنگ هیستوگرام اصلی (بدون تغییر)
   if (iB[shift] > 0) {
      iC[shift] = (iB[shift] < iB[shift + 1]) ? 1 : 0;
   } else {
      iC[shift] = (iB[shift] < iB[shift + 1]) ? 2 : 3;
   }

   //--- پرکردن بافرهای جدید بدون تأثیر روی رنگ‌بندی
   bufferLimeGreen[shift] = (iC[shift] == 0) ? iB[shift] : EMPTY_VALUE;
   bufferGreen[shift]     = (iC[shift] == 1) ? iB[shift] : EMPTY_VALUE;
   bufferRed[shift]       = (iC[shift] == 2) ? iB[shift] : EMPTY_VALUE;
   bufferMaroon[shift]    = (iC[shift] == 3) ? iB[shift] : EMPTY_VALUE;

   //--- تنظیم رنگ فلش‌ها (بدون تغییر)
   lC[shift] = (sqzOn) ? 1 : (sqzOff) ? 2 : 0;
}

//+------------------------------------------------------------------+
//| تابع رگرسیون خطی                                                |
//+------------------------------------------------------------------+
double LinearRegression(const double& array[], int period, int shift, double& error) {
   double sx = 0, sy = 0, sxy = 0, sxx = 0, syy = 0, y = 0;

   int param = (ArrayIsSeries(array)) ? -1 : 1;

   for (int x = 0; x < period; x++) {
      y    = array[shift + param * x];
      sx  += x;
      sy  += y;
      sxx += x * x;
      sxy += x * y;
      syy += y * y;
   }

   double slope = (period * sxy - sx * sy) / (sx * sx - period * sxx);
   double intercept = (sy - slope * sx) / period;
   error = MathSqrt((period * syy - sy * sy - slope * slope * (period * sxx - sx * sx)) /
                    (period * (period - 2)));

   return intercept + slope * period;
}

//+------------------------------------------------------------------+
//| تابع محاسبه اندیکاتور                                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
   if (rates_total <= 4) return 0;

   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   int limit = rates_total - prev_calculated;
   if (limit == 0) { // فقط یک تیک جدید
      GetValue(high, low, close, 1);
   } else if (limit == 1) { // یک کندل جدید
      GetValue(high, low, close, 1);
   } else if (limit > 1) { // اولین بار یا تغییر تایم‌فریم
      ArrayInitialize(iB, EMPTY_VALUE);
      ArrayInitialize(iC, 0);
      ArrayInitialize(lB, 0);
      ArrayInitialize(lC, 0);
      ArrayInitialize(srce, 0);
      ArrayInitialize(bufferLimeGreen, EMPTY_VALUE);
      ArrayInitialize(bufferGreen, EMPTY_VALUE);
      ArrayInitialize(bufferRed, EMPTY_VALUE);
      ArrayInitialize(bufferMaroon, EMPTY_VALUE);

      limit = rates_total - MINBAR;
      for (int i = limit; i >= 1 && !IsStopped(); i--) {
         GetValue(high, low, close, i);
      }
      return(rates_total);
   }
   return(rates_total);
}