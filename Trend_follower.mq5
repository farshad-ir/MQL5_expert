//+------------------------------------------------------------------+
//|                                               Trend_follower.mq5 |
//|                       Copyright 2015 - 2025, Farshad Rezvan, PhD |
//|                                               farezvan@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015 - 2025, Farshad Rezvan, PhD"
#property link      "farezvan@gmail.com"
#property version   "2.50"
#property strict

//-------------------- inputs
input int Lookback = 3;
input int MaxRank  = 10;
input int MinTrendRank = 2;

//-------------------- globals
datetime last_bar_time = 0;

#define MAX_HIGHS 500
datetime HighTime[MAX_HIGHS];
double   HighPrice[MAX_HIGHS];
int      HighRank[MAX_HIGHS];
int      HighCount = 0;

//+------------------------------------------------------------------+
void OnTick()
{
   datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(last_bar_time == current_bar)
      return;
   last_bar_time = current_bar;

   int i = Lookback;

   if(Bars(_Symbol, PERIOD_CURRENT) < Lookback*2 + 10)
      return;

   if(IsSwingHigh(i))
   {
      int rank = CalculateHighRank(i);
      DrawHighStar(i, rank);
      StoreHigh(i, rank);
      DrawTrendFromHighs();
   }
}

//+------------------------------------------------------------------+
//| Check Swing High
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
//| Calculate Rank
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
//| Draw Star
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
//| Draw Trend Lines
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
            }
         }
         last = i;
      }
   }
}
//+------------------------------------------------------------------+
