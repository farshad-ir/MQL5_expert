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


//+------------------------------------------------------------------+
void OnTick()
{
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(last_bar_time == t0) return;
   last_bar_time = t0;

   if(Bars(_Symbol, PERIOD_CURRENT) < Lookback*2 + 20)
      return;

   int i = Lookback;

   if(IsSwingHigh(i))
   {
      int rank = CalculateHighRank(i);
      DrawHighStar(i, rank);
      StoreHigh(i, rank);
      DrawTrendFromHighs();
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
//| Draw Low Star
//+------------------------------------------------------------------+
void DrawLowStar(int index)
{
   datetime t = iTime(_Symbol, PERIOD_CURRENT, index);
   double   p = iLow(_Symbol, PERIOD_CURRENT, index) - _Point*50;

   string name = "LowStar_" + (string)t;
   if(ObjectFind(0, name) != -1) return;

   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, "★");
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrAqua);

   // ---------- ذخیره در آرایه ----------
   if(LowCount < MAX_LOWS)
   {
      LowTime[LowCount] = t;
      LowPrice[LowCount] = p;
      LowCount++;
   }
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

