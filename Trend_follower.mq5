//+------------------------------------------------------------------+
//|                                               Trend_follower.mq5 |
//|                       Copyright 2015 - 2025, Farshad Rezvan, PhD |
//|                                               farezvan@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015 - 2025, Farshad Rezvan, PhD"
#property link      "farezvan@gmail.com"
#property version   "2.60"
#property strict

//-------------------- inputs
input int Lookback      = 3;
input int MaxRank       = 10;
input int MinTrendRank  = 2;

//-------------------- globals
datetime last_bar_time = 0;

#define MAX_HIGHS 500
datetime HighTime[MAX_HIGHS];
double   HighPrice[MAX_HIGHS];
int      HighRank[MAX_HIGHS];
int      HighCount = 0;

#define MAX_LOWS 500
datetime LowTime[MAX_LOWS];
double   LowPrice[MAX_LOWS];
int      LowCount = 0;

//-------------------- Low Structure (Horizontal Supports)
#define MAX_STRUCT_LOWS 11

struct LowStructure
{
   double   price[MAX_STRUCT_LOWS];
   datetime time[MAX_STRUCT_LOWS];
   int      level[MAX_STRUCT_LOWS];  // درجه هر Low
   int      count;

   void Reset()
   {
      count = 0;
   }
};

LowStructure LS;


int OnInit()
{
   LS.Reset();
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnTick()
{
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(last_bar_time == t0) return;
   last_bar_time = t0;

   if(Bars(_Symbol, PERIOD_CURRENT) < Lookback*2 + 20)
      return;

   int i = Lookback;

   if(IsSwingHigh(i)) { int rank = CalculateHighRank(i); DrawHighStar(i, rank); StoreHigh(i, rank); DrawTrendFromHighs();}
   
   
   UpdateLowTrends(1);
   
   
    // مثال: بررسی اولین Low در ساختار
    if(LS.count > 0 && LS.level[0] >= 1)
    {
        string msg = StringFormat("Low پایدار: قیمت = %.5f, level = %d", 
                                  LS.price[0], LS.level[0]);
        Alert(msg);   // نمایش آلارم
        Print(msg);   // چاپ در لاگ
    }
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   

}

//+------------------------------------------------------------------+
//| Swing High detection
//+------------------------------------------------------------------+
bool IsSwingHigh(int index)
{
   double h = iHigh(_Symbol, PERIOD_CURRENT, index);

   for(int j=1; j<=Lookback; j++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, index+j) >= h) return false;
      if(iHigh(_Symbol, PERIOD_CURRENT, index-j) >  h) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Rank calculation
//+------------------------------------------------------------------+
int CalculateHighRank(int index)
{
   double h = iHigh(_Symbol, PERIOD_CURRENT, index);
   int rank = 0;

   for(int r=1; r<=MaxRank; r++)
   {
      bool valid = true;
      for(int j=1; j<=r; j++)
      {
         if(iHigh(_Symbol, PERIOD_CURRENT, index+j) >= h ||
            iHigh(_Symbol, PERIOD_CURRENT, index-j) >  h)
         {
            valid = false;
            break;
         }
      }
      if(valid) rank = r;
      else break;
   }
   return rank;
}

//+------------------------------------------------------------------+
//| Draw High Star
//+------------------------------------------------------------------+
void DrawHighStar(int index, int rank)
{
   if(rank <= 0) return;

   datetime t = iTime(_Symbol, PERIOD_CURRENT, index);
   double   p = iHigh(_Symbol, PERIOD_CURRENT, index) + _Point*50;

   string name = "HighStar_" + (string)t;
   if(ObjectFind(0, name) != -1) return;

   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, "★");
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10 + rank*2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
}

//+------------------------------------------------------------------+
//| Store High
//+------------------------------------------------------------------+
void StoreHigh(int index, int rank)
{
   if(rank <= 0 || HighCount >= MAX_HIGHS)
      return;

   HighTime[HighCount]  = iTime(_Symbol, PERIOD_CURRENT, index);
   HighPrice[HighCount]= iHigh(_Symbol, PERIOD_CURRENT, index);
   HighRank[HighCount] = rank;
   HighCount++;
}

//+------------------------------------------------------------------+
//| Calculate slope
//+------------------------------------------------------------------+
double CalculateSlope(datetime t1, double p1,
                      datetime t2, double p2)
{
   double dt = (double)(t2 - t1);
   if(dt == 0.0) return 0.0;
   return (p2 - p1) / dt;
}

//+------------------------------------------------------------------+
//| Find lowest Low between two times
//+------------------------------------------------------------------+
int FindLowestLowIndex(datetime t1, datetime t2)
{
   int b1 = iBarShift(_Symbol, PERIOD_CURRENT, t1, true);
   int b2 = iBarShift(_Symbol, PERIOD_CURRENT, t2, true);

   if(b1 < 0 || b2 < 0) return -1;
   if(b1 > b2) { int tmp = b1; b1 = b2; b2 = tmp; }

   double minLow = DBL_MAX;
   int    minIdx = -1;

   for(int i=b1; i<=b2; i++)
   {
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(l < minLow)
      {
         minLow = l;
         minIdx = i;
      }
   }
   return minIdx;
}



//+------------------------------------------------------------------+
//| Draw Trend Lines and process slope
//+------------------------------------------------------------------+
void DrawTrendFromHighs()
{
   int last = -1;

   for(int i=0; i<HighCount; i++)
   {
      if(HighRank[i] >= MinTrendRank)
      {
         if(last != -1 && HighRank[i] >= HighRank[last])
         {
            string name = "Trend_" + (string)HighTime[last] + "_" + (string)HighTime[i];

            if(ObjectFind(0, name) == -1)
            {
               ObjectCreate(0, name, OBJ_TREND, 0,
                            HighTime[last], HighPrice[last],
                            HighTime[i],    HighPrice[i]);

               ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
               ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

               double slope = CalculateSlope(
                                 HighTime[last], HighPrice[last],
                                 HighTime[i],    HighPrice[i]);

               // اگر ترند نزولی است → کمترین Low بین دو High
               if(slope < 0)
               {
                  int lowIdx = FindLowestLowIndex(
                                   HighTime[last],
                                   HighTime[i]);

                  if(lowIdx != -1)
                     DrawLowStar(lowIdx);
               }
            }
         }
         last = i;
      }
   }
}
//+------------------------------------------------------------------+
//--------------------------low trends
//
struct LowTrend
{
    datetime tStart;        // زمان شروع ترند (Low قبلی)
    double   pStart;        // قیمت شروع ترند
    double   slope;         // شیب ترند
    bool     active;        // وضعیت فعال بودن ترند
    int      barsAfterBreak; // شمارنده بعد از شکست (۱۰ کندل)
    string   lineName;      // نام خط روی چارت
};

#define MAX_ACTIVE_TRENDS 100
LowTrend ActiveTrends[MAX_ACTIVE_TRENDS];
int ActiveTrendCount = 0;

//-------------------- تابع ذخیره Low و افزودن ترند --------------------
void DrawLowStar(int index)
{
    datetime t = iTime(_Symbol, PERIOD_CURRENT, index);
    double   p = iLow(_Symbol, PERIOD_CURRENT, index) - _Point*50;

    string name = "LowStar_" + (string)t;
    if(ObjectFind(0, name) == -1)
    {
        ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
        ObjectSetString(0, name, OBJPROP_TEXT, "★");
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrAqua);
    }

    // ذخیره در آرایه Lowها
    if(LowCount >= MAX_LOWS) return;

    LowTime[LowCount] = t;
    LowPrice[LowCount] = p;

    // رسم خط به Low قبلی
    if(LowCount > 0)
    {
        string lineName = "LowTrend_" + (string)LowTime[LowCount-1] + "_" + (string)t;
        if(ObjectFind(0, lineName) == -1)
        {
            ObjectCreate(0, lineName, OBJ_TREND, 0,
                         LowTime[LowCount-1], LowPrice[LowCount-1],
                         t, p);
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrAqua);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
        }
        
        // افزودن به آرایه و مرتب کردن اعضای آن
        AddStructureLow(p, t);
        // افزودن ترند جدید
        AddLowTrend(LowTime[LowCount-1], LowPrice[LowCount-1], t, p);
    }

    LowCount++;
}

//-------------------- افزودن ترند جدید --------------------
void AddLowTrend(datetime tPrev, double pPrev, datetime tNew, double pNew)
{
    if(ActiveTrendCount >= MAX_ACTIVE_TRENDS) return;

    double slope = CalculateSlope(tPrev, pPrev, tNew, pNew);
    //if(slope <= 0) return; // فقط شیب مثبت

    LowTrend tr;
    tr.tStart = tPrev;
    tr.pStart = pPrev;
    tr.slope  = slope;
    tr.active = true;
    tr.barsAfterBreak = 0;
    tr.lineName = "LowTrend_" + (string)tPrev + "_" + (string)tNew;

    // رسم خط اصلی
    if(ObjectFind(0, tr.lineName) == -1)
    {
        ObjectCreate(0, tr.lineName, OBJ_TREND, 0, tPrev, pPrev, tNew, pNew);
        ObjectSetInteger(0, tr.lineName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, tr.lineName, OBJPROP_WIDTH, 2);
    }

    ActiveTrends[ActiveTrendCount++] = tr;
}

//-------------------- بروزرسانی ترندهای فعال --------------------
void UpdateLowTrends(int currentBar)
{
    // غیرفعال‌سازی ترندهای با شیب کمتر
    if(LowCount >= 2)
    {
        double lastSlope = CalculateSlope(
            LowTime[LowCount-2], LowPrice[LowCount-2],
            LowTime[LowCount-1], LowPrice[LowCount-1]
        );

        for(int i=0; i<ActiveTrendCount; i++)
        {
            if(ActiveTrends[i].active && lastSlope > ActiveTrends[i].slope)
                ActiveTrends[i].active = false;
        }
    }

    // بروزرسانی ترندهای فعال
    for(int i=0; i<ActiveTrendCount; i++)
    {
        if(!ActiveTrends[i].active) continue;

        datetime t1  = ActiveTrends[i].tStart;
        double   p1  = ActiveTrends[i].pStart;
        double   slope = ActiveTrends[i].slope;

        datetime tCurrent = iTime(_Symbol, PERIOD_CURRENT, currentBar);
        double trendPrice = p1 + slope * (tCurrent - t1);
        double closePrice = iClose(_Symbol, PERIOD_CURRENT, currentBar);

        // --- تشخیص شکست ---
        if(ActiveTrends[i].barsAfterBreak == 0)
        {
            if(closePrice < trendPrice)
                ActiveTrends[i].barsAfterBreak = 1;
        }
        else
        {
            ActiveTrends[i].barsAfterBreak++;
            if(ActiveTrends[i].barsAfterBreak > 10)
            {
                ActiveTrends[i].active = false;
                continue;
            }
        }

        // رسم خط Extend
        string extLineName = "LowTrendExt_" + (string)t1;
        ObjectDelete(0, extLineName); // برای آپدیت صحیح
        ObjectCreate(0, extLineName, OBJ_TREND, 0,
                     t1, p1, tCurrent, trendPrice);
        ObjectSetInteger(0, extLineName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, extLineName, OBJPROP_WIDTH, 1);
    }
}




void AddStructureLow(double newPrice, datetime newTime)
{
    if(LS.count == 0)
    {
        LS.price[0] = newPrice;
        LS.time[0]  = newTime;
        LS.level[0] = 0;      
        LS.count = 1;
        return;
    }

    int insertPos = LS.count;  // به‌صورت پیش‌فرض انتها

    // پیدا کردن محل درج
    for(int i=0; i<LS.count; i++)
    {
        if(newPrice < LS.price[i])
        {
            insertPos = i;
            break;
        }
    }

    // --- ذخیره نسخه قبلی برای مقایسه ---
    double oldPrices[MAX_STRUCT_LOWS];
    datetime oldTimes[MAX_STRUCT_LOWS];
    int oldCount = LS.count;
    for(int i=0; i<oldCount; i++)
    {
        oldPrices[i] = LS.price[i];
        oldTimes[i]  = LS.time[i];
    }

    // --- شیفت دادن عناصر برای ایجاد جایگاه ---
    int maxShift = MathMin(LS.count, MAX_STRUCT_LOWS-1);
    for(int j=maxShift; j>insertPos; j--)
    {
        LS.price[j] = LS.price[j-1];
        LS.time[j]  = LS.time[j-1];
        LS.level[j] = LS.level[j-1];
    }

    // درج Low جدید
    LS.price[insertPos] = newPrice;
    LS.time[insertPos]  = newTime;
    LS.level[insertPos] = 0;  // درجه Low جدید = 0

    if(LS.count < MAX_STRUCT_LOWS)
        LS.count++;

    // --- بروزرسانی سطح (level) سایر Lowها ---
    for(int i=0; i<oldCount; i++)
    {
        bool found = false;
        for(int j=0; j<LS.count; j++)
        {
            if(LS.price[j] == oldPrices[i] && LS.time[j] == oldTimes[i])
            {
                found = true;
                LS.level[j]++;   // جای ثابت → +1
                break;
            }
        }
        if(!found)
        {
            // Low قبلی حذف یا جابجا شده → level = 0
            for(int j=0; j<LS.count; j++)
            {
                if(LS.price[j] == oldPrices[i] && LS.time[j] != oldTimes[i])
                    LS.level[j] = 0;
            }
        }
    }
}
