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


//LowStructure LS;
//int lowTrend_name = 0 ;
//هnt structure_low_name = 0;

int OnInit()
{
   LS.Reset();
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+

int lastLevel_0 = 0;

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
    //if(LS.count > 0 && LS.level[0] >= 1 && lastLevel_0 != LS.level[0] )
    //{
    //    string msg = StringFormat("Low پایدار: قیمت = %.5f, level = %d", 
    //                              LS.price[0], LS.level[0]);
    //    Alert(msg);   // نمایش آلارم
    //    Print(msg);   // چاپ در لاگ
    //    lastLevel_0 = LS.level[0];
    //}
   
   
    // 👇 اینجا منطق گزارش
    CheckLowTrendEvents(1);
    CheckStructureLowEvents(1);
    
    
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   

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
//--------------------------low trends
struct LowTrend
{
    datetime tStart;
    double   pStart;
    double   slope;
    bool     active;
    int      barsAfterBreak;
    string   lineName;  // LT_0, LT_1, ...
    int      ID;        // شماره یکتا ترند
};

#define MAX_ACTIVE_TRENDS 100
LowTrend ActiveTrends[MAX_ACTIVE_TRENDS];
int ActiveTrendCount = 0;

// شماره یکتا ستاره و ترند
int StarID = 0;
int LowTrendID = 0;

//-------------------- Structure Low با StarID --------------------
#define MAX_STRUCT_LOWS 1100


struct LowStructure
{
    double   price[MAX_STRUCT_LOWS];
    datetime time[MAX_STRUCT_LOWS];
    int      level[MAX_STRUCT_LOWS];
    int      StarID[MAX_STRUCT_LOWS];
    int      count;
    void Reset() { count = 0; }
};
LowStructure LS;

//-------------------- تابع ذخیره Low و افزودن ترند --------------------
void DrawLowStar(int index)
{
    datetime t = iTime(_Symbol, PERIOD_CURRENT, index);
    double   p = iLow(_Symbol, PERIOD_CURRENT, index) - _Point*50;

    // نام کوتاه ستاره
    string name = "Star_" + IntegerToString(StarID);
    if(ObjectFind(0, name) == -1)
    {
        ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
        ObjectSetString(0, name, OBJPROP_TEXT, "★" + IntegerToString(StarID));
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrAqua);
    }

    // ذخیره در آرایه Lowها
    if(LowCount >= MAX_LOWS) return;
    LowTime[LowCount] = t;
    LowPrice[LowCount] = p;

    // افزودن به Structure Low
    AddStructureLow(p, t, StarID);

    // رسم خط به Low قبلی و ایجاد ترند
    if(LowCount > 0)
    {
        AddLowTrend(LowTime[LowCount-1], LowPrice[LowCount-1], t, p);
    }

    LowCount++;
    StarID++;
}

//-------------------- افزودن ترند جدید --------------------
void AddLowTrend(datetime tPrev, double pPrev, datetime tNew, double pNew)
{
    if(ActiveTrendCount >= MAX_ACTIVE_TRENDS) return;

    double slope = CalculateSlope(tPrev, pPrev, tNew, pNew);

    LowTrend tr;
    tr.tStart = tPrev;
    tr.pStart = pPrev;
    tr.slope  = slope;
    tr.active = true;
    tr.barsAfterBreak = 0;
    tr.ID = LowTrendID;
    tr.lineName = "LT_" + IntegerToString(LowTrendID);

    // رسم خط اصلی با شماره ترند روی چارت
    if(ObjectFind(0, tr.lineName) == -1)
    {
        ObjectCreate(0, tr.lineName, OBJ_TREND, 0, tPrev, pPrev, tNew, pNew);
        ObjectSetInteger(0, tr.lineName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, tr.lineName, OBJPROP_WIDTH, 2);
    }

    ActiveTrends[ActiveTrendCount++] = tr;
    LowTrendID++;
}

//-------------------- افزودن Low به Structure --------------------
void AddStructureLow(double newPrice, datetime newTime, int starID)
{
    if(LS.count >= MAX_STRUCT_LOWS) return;

    LS.price[LS.count] = newPrice;
    LS.time[LS.count]  = newTime;
    LS.level[LS.count] = 0;     // درجه Low جدید
    LS.StarID[LS.count] = starID;
    LS.count++;
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

    // بروزرسانی ترندهای فعال و رسم Extend تا کندل جاری
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

        // رسم خط Extend با نام کوتاه ترند
        string extLineName = ActiveTrends[i].lineName + "_ext";
        ObjectDelete(0, extLineName); // آپدیت
        ObjectCreate(0, extLineName, OBJ_TREND, 0,
                     t1, p1, tCurrent, trendPrice);
        ObjectSetInteger(0, extLineName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, extLineName, OBJPROP_WIDTH, 1);
    }
}

//-------------------- بررسی نزدیک شدن و شکست ترند و Structure --------------------
#define NEAR_POINTS 30
double NEAR_DIST = NEAR_POINTS * _Point;

void CheckLowTrendEvents(int currentBar)
{
    datetime t0 = iTime(_Symbol, PERIOD_CURRENT, currentBar);
    datetime t1 = iTime(_Symbol, PERIOD_CURRENT, currentBar + 1);

    double close0 = iClose(_Symbol, PERIOD_CURRENT, currentBar);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, currentBar + 1);

    for(int i=0; i<ActiveTrendCount; i++)
    {
        if(!ActiveTrends[i].active) continue;

        LowTrend tr = ActiveTrends[i];

        double trend0 = tr.pStart + tr.slope * (t0 - tr.tStart);
        double trend1 = tr.pStart + tr.slope * (t1 - tr.tStart);

        // نزدیک شدن
        if(MathAbs(close0 - trend0) <= NEAR_DIST)
            Print("📐 Near LowTrend → ", tr.lineName, " | ID=", tr.ID);

        // شکست
        if(close1 > trend1 && close0 < trend0)
            Print("❌ Break LowTrend → ", tr.lineName, " | ID=", tr.ID);
    }
}

void CheckStructureLowEvents(int currentBar)
{
    double close0 = iClose(_Symbol, PERIOD_CURRENT, currentBar);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, currentBar + 1);

    for(int i=0; i<LS.count; i++)
    {
        double levelPrice = LS.price[i];

        // نزدیک شدن
        if(MathAbs(close0 - levelPrice) <= NEAR_DIST)
            Print("📌 Near Structure Low | StarID=", LS.StarID[i],
                  " Level=", LS.level[i],
                  " Price=", DoubleToString(levelPrice,_Digits));

        // شکست
        if(close1 > levelPrice && close0 < levelPrice)
            Print("❌ Break Structure Low | StarID=", LS.StarID[i],
                  " Level=", LS.level[i],
                  " Price=", DoubleToString(levelPrice,_Digits));
    }
}
