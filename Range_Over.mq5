//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                               Range_Over_GBP.mq5 |
//|                       Copyright 2015 - 2025, Farshad Rezvan, PhD |
//|                                               farezvan@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015 - 2025, Farshad Rezvan, PhD"
#property link      "farezvan@gmail.com"
#property version   "2.55"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

CTrade         m_trade;
CSymbolInfo    m_symbol;
CPositionInfo  m_position;
CAccountInfo   m_account;

int RiskReduceBy    = 2 ; 
int exaggeratedFactore = 2 ;
//--- user inputs
double minbalance         = 3000.00;
double TargetProfit       ; // = 10.0;
double SingleTradeProfit  ; // = 2.00;
double CommissionPerTrade ; // = 0.10;
double LotSize            = 0.01;
double lord_coef;

bool ShockActive = false;
bool wait_a_minute = false;


bool NOT_BUY_UNTIL = false;
double NotBuyUntilPrice = 0.0;

bool NOT_SELL_UNTIL = false;
double NotSellUntilPrice = 0.0;

double preventFactor = 0.01;

int globalShock = 0 ;
string qt = "";

//bool PrintTradingLogs = false;

string Starting           = "2025.10.13 03:05";
int    Cycles             = 3;

//--- state
datetime e = 0;
bool first = true;
double totalProfit = 0.0;

// آمار بسته‌ها
int closedBuyCount = 0;
int closedSellCount = 0;
int closedTotalCount = 0;
double closedBuyProfit = 0.0;
double closedSellProfit = 0.0;

double initialBalance = 0.0;
int numBuy = 0, numSell = 0;

bool NO_BUY_state  = false;
bool NO_SELL_state = false;

int cycle = 1;               // شماره‌ی دوره فعلی
bool adjustmentDone = false; // آیا معامله تعدیلی در این دوره زده شده؟
//+------------------------------------------------------------------+


//#include <Trade\Trade.mqh>
enum TrendState
{
   S_IDLE = 0,
   S_SEEN_BULL,
   S_SEEN_BEAR,
   S_BOX,
   S_TREND_UP,
   S_TREND_DOWN
};



TrendState  State = S_IDLE;
int LastState = 0;

// رکورد ref
double ref_open = 0 ;
double ref_close = 0 ;

bool   ref_is_bull = true;

// آخرین کندل دریافت‌شده
//datetime last_bar_time = 0;

// مقادیر باکس
double box_low  = 0;
double box_high = 0;


void reCalculate(){

   initialBalance = m_account.Balance();
      //--- user inputs
      //double minbalance         = 3000.00;
      //double TargetProfit       = 10.0;
      //double SingleTradeProfit  = 2.00;
      //double CommissionPerTrade = 0.10;
      //double LotSize            = 0.01;


   lord_coef = (initialBalance / minbalance) / RiskReduceBy;

   

   
   
   LotSize = 0.01 * lord_coef;
   LotSize = 0.01 * MathRound(LotSize / 0.01);
   
   
   Print("RiskReduceBy: ", RiskReduceBy, ", Lord Coef: ", DoubleToString(lord_coef,2) , ", LotSize: ", DoubleToString(LotSize,2) );
   
   
   CommissionPerTrade =    exaggeratedFactore * 10.0 * LotSize ;
   TargetProfit =          exaggeratedFactore * 100.0 * CommissionPerTrade ;
   SingleTradeProfit =     exaggeratedFactore * 0.20 * TargetProfit ;

}
int OnInit()
{

   string LogFileName = "State_of_trends.txt";
   int f = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(f == INVALID_HANDLE)
   {
      Print("❌ Cannot create log file: ", LogFileName);
      return(INIT_PARAMETERS_INCORRECT);
   }
   FileWriteString(f, ""); // پاک کردن محتویات
   FileFlush(f);
   FileClose(f);


   reCalculate();
   if(lord_coef < 1.0) {
      Print("Min Balance is 3000 for RiskReduceBy = 1, you have selected RiskReduceBy = ", RiskReduceBy ," then Your Balance should be ", RiskReduceBy * 3000);
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   
   PrintFormat("✅ Reversal EA initialized: Lot=%.2f TargetProfit=%.2f Balance=%.2f Cycle=%d",
               LotSize, TargetProfit, initialBalance, cycle);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Close all positions of given type (only for current symbol)      |
//+------------------------------------------------------------------+
void ClosePositionsByType(const int posType)
{
   bool closedAny = true;
   while(closedAny)
   {
      closedAny = false;
      int N = PositionsTotal();
      for(int i = N - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Symbol() != _Symbol) continue;
         int t = (int)m_position.PositionType();
         if(t != posType) continue;

         double prof = CalculatePureProfit(m_position);
         ulong  ticket = m_position.Ticket();

         if(m_trade.PositionClose(ticket))
         {
            closedAny = true;
            double net = prof - CommissionPerTrade;
            totalProfit += net;
            closedTotalCount++;

            if(posType == POSITION_TYPE_BUY)
            {
               closedBuyCount++;
               closedBuyProfit += net;
            }
            else
            {
               closedSellCount++;
               closedSellProfit += net;
            }
            PrintFormat("🔒 Closed Ticket=%I64u Type=%s Benefit=%.2f (net after comm)=%.2f | SUM=%.2f",
                        ticket,
                        (posType==POSITION_TYPE_BUY) ? "Buy" : "Sell",
                        prof, net, totalProfit);
            Sleep(100);
         }
         else
         {
            int err = GetLastError();
            PrintFormat("❌ خطا در بستن تیکت %I64u: Error=%d", ticket, err);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sum profits by side                                              |
//+------------------------------------------------------------------+
void SumOpenProfits(double &buySum, double &sellSum)
{
   buySum = 0.0; sellSum = 0.0;
   double buyLots = 0.0, sellLots = 0.0;

   int N = PositionsTotal();
   for(int i = 0; i < N; i++)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol) continue;
      int t = (int)m_position.PositionType();
      double p = CalculatePureProfit(m_position);
      double v = m_position.Volume();

      if(t == POSITION_TYPE_BUY) {
         buySum  += p;
         buyLots += v;
      }
      else if(t == POSITION_TYPE_SELL) {
         sellSum  += p;
         sellLots += v;
      }
   }

   numBuy  = (int)MathRound(buyLots  / LotSize);
   numSell = (int)MathRound(sellLots / LotSize);

   // اگر قبلاً تعدیل انجام شده ولی اختلاف دوباره کمتر از ۵ است => ریست پرچم
   if(adjustmentDone && MathAbs(numBuy - numSell) <= 5)
   {
      adjustmentDone = false;
      PrintFormat("⚖️ adjustmentDone reset automatically (numBuy=%d, numSell=%d)", numBuy, numSell);
   }
}
bool tranquil = true;
bool edge = true ;
//+------------------------------------------------------------------+


void UpdateShockLabel()
{
   // build the text exactly like your Comment()
   double buySum, sellSum;
   SumOpenProfits(buySum, sellSum);

   string wt = "";
   if(NO_BUY_state )  wt = "Close Buys";
   if(NO_SELL_state) wt = "Close Sells";

   string txt = StringFormat(
      "Shock: %d  | %s  |  Buy(%d): %.2f  |  Sell(%d): %.2f",
      globalShock, wt,
      numBuy, buySum,
      numSell, sellSum
   );

   if( StringLen( qt ) > 5 ){txt += "  |  " + qt ; qt = ""; }
   
   string name = "ShockLabel";

   // همیشه قبلش پاک کن
   if(ObjectFind(0, name) != -1)
      ObjectDelete(0, name);

   // از نو بساز
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
   

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 18);      // 👈 فونت بزرگ
   ObjectSetString (0, name, OBJPROP_FONT,  "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void OnTick()
{


   UpdateShockLabel();
   if( PositionsTotal() > 0 ) tranquil = false;
   
   
   
   
   MqlDateTime dt, st;
   TimeCurrent(dt);
   TimeToStruct(StringToTime(Starting),st);
   
   static int lastDay = -1;
   if(dt.hour == st.hour && edge && dt.day != lastDay){
      edge = false;
      lastDay = dt.day;
      if(tranquil) tranquil = false;
   }
   else if(dt.hour != st.hour && !edge)
      edge = true;
   
   if(tranquil) return;
   
   datetime current_candle_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (current_candle_time == e) return;
   e = current_candle_time;
   
   CheckNotBuyUntil ();
   CheckNotSellUntil();
   
 
   
   
   
   
   calculate_trend();   
   
   string log_txt;
   
   switch(State){
      case S_IDLE       : log_txt="IDLE";       break;
      case S_SEEN_BULL  : log_txt="SEEN_BULL";  break;
      case S_SEEN_BEAR  : log_txt="SEEN_BEAR";  break;
      case S_BOX        : log_txt="BOX";        break;
      case S_TREND_UP   : log_txt="TREND_UP";   break;
      case S_TREND_DOWN : log_txt="TREND_DOWN"; break;    
   }
   
    double cur_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double cur_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    //PrintFormat("State: %s, Price: %.5f",log_txt, (cur_ask+cur_bid) / 2.0);
    
    if(State == 5 && LastState == 3){
       Print("~~~~~~~~~~~~~~~~~~~~ DO Close BUYS ~~~~~~~~~~~~~~~~");
       Print("~~~~~~~~~~~~~~~~~~~~");
    }
 
    if(State == 4 && LastState == 3){
       Print("~~~~~~~~~~~~~~~~~~~~ DO Close SELLS ~~~~~~~~~~~~~~~");   
       Print("~~~~~~~~~~~~~~~~~~~~");   
    }
   
   
   

   double buySum, sellSum;
   SumOpenProfits(buySum, sellSum);
   

   

   
   
   ProcessShock();
   

   SumOpenProfits(buySum, sellSum);
   
   if(buySum > SingleTradeProfit + CommissionPerTrade * (numBuy-1)  ) //&& ! NO_SELL_state
   {
      if(State == 5 && LastState == 3){
         AppendLog("~~~~Closing Buys due to Top");
         Print("~~~~Closing Buys due to Top");
         ClosePositionsByType(POSITION_TYPE_BUY);
         SumOpenProfits(buySum, sellSum);
         NO_BUY_state = true;
         NotBuyUntilPrice = box_high * (1+preventFactor) ; //1.001
         NOT_BUY_UNTIL = true;
         Print("NotBuyUntilPrice: ", DoubleToString(NotBuyUntilPrice,5) );
         Print("~~~~~~~~~~~~~~~~~~~~~~~~");
         
         //AppendLog(StringFormat("numBuy: %d,   numSell: %d", numBuy, numSell));
         double fac =  0.2 * MathAbs(numBuy - numSell);
         double nLot = fac * LotSize;
         nLot = 0.01*MathRound(nLot/0.01);
         if(nLot < 0.01) nLot = 0.01;
         
         //AppendLog(StringFormat("BuyStop Lots:  %0.2f  @  %0.2f",nLot, box_high+5.0));
         //m_trade.BuyStop(nLot,box_high+5.0,_Symbol);
      }
   }

   if(sellSum > SingleTradeProfit + CommissionPerTrade * (numSell-1)  ) //&& ! NO_BUY_state
   {
      if(State == 4 && LastState == 3){
         AppendLog("~~~~Closing Sells due to Bottom");
         Print("~~~~Closing Sells due to Bottom");
         ClosePositionsByType(POSITION_TYPE_SELL);
         SumOpenProfits(buySum, sellSum);
         NO_SELL_state = true;
         NotSellUntilPrice = box_low * (1-preventFactor) ;
         NOT_SELL_UNTIL = true;
         Print("NotSellUntilPrice: ", DoubleToString(NotSellUntilPrice,5) );
         Print("~~~~~~~~~~~~~~~~~~~~~~~~");
         //AppendLog(StringFormat("numBuy: %d,   numSell: %d", numBuy, numSell));
         double fac =  0.2 * MathAbs(numBuy - numSell);
         double nLot = fac * LotSize;
         nLot = 0.01*MathRound(nLot/0.01);
         if(nLot < 0.01) nLot = 0.01;
         
         //AppendLog(StringFormat("SellStop Lots:  %0.2f  @  %0.2f",nLot, box_low-5.0));
         //m_trade.SellStop(nLot,box_low-5.0,_Symbol);
      }
      
   }

   if(totalProfit >= TargetProfit && PositionsTotal() == 0)
   {
      PrintFormat("🎯 هدف سود %.2f$ پس از کسر کمیسیون محقق شد. EA ریست می‌شود. آمار: total=%d buy=%d sell=%d profit=%.2f",
                  TargetProfit, closedTotalCount, closedBuyCount, closedSellCount, totalProfit);
      re_initialize();
      return;
   }

   if(m_account.Equity() >= TargetProfit + initialBalance + CommissionPerTrade * 1.5 * (numBuy + numSell - 1) )
   {
      Print("Equity reached!");
      AppendLog(StringFormat("~~Equity reached : Cycle = %d", cycle));
      CloseAll();
      re_initialize();
      return;
   }

   if(numBuy > numSell + 5 && ! NOT_SELL_UNTIL)
   {
      NO_BUY_state  = true;
      NO_SELL_state = false;
      Print("NO MORE BUY ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

      if(!adjustmentDone && !NO_SELL_state)
      {
         //double adjLot = LotSize * (numBuy - numSell);
         //if(m_trade.Sell(LotSize, _Symbol))
         //{
            adjustmentDone = true;
            PrintFormat("⚖️ معامله تعدیلی SELL %.2f باز شد برای تعادل حجم‌ها", LotSize);
            globalShock ++ ;
            ShockActive = true ;
            AppendLog(StringFormat("Shock %d: CloseBuys", globalShock));

         //}
         //else PrintFormat("❌ معامله تعدیلی SELL ناموفق. Err=%d", GetLastError());
      }
   }

   if(numSell > numBuy + 5 && ! NOT_BUY_UNTIL)
   {
      NO_SELL_state = true;
      NO_BUY_state  = false;
      Print("NO MORE SELL ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

      if(!adjustmentDone && !NO_BUY_state)
      {
         //double adjLot = LotSize * (numSell - numBuy);
         //if(m_trade.Buy(LotSize, _Symbol))
         //{
            adjustmentDone = true;
            PrintFormat("⚖️ معامله تعدیلی BUY %.2f باز شد برای تعادل حجم‌ها", LotSize);
            globalShock ++ ;
            ShockActive = true ;
            AppendLog(StringFormat("Shock %d: CloseSells", globalShock));

         //}
         //else PrintFormat("❌ معامله تعدیلی BUY ناموفق. Err=%d", GetLastError());
      }
   }

   double open1  = iOpen (_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool bull = (close1 > open1);

   bool opened = false;

   // --- شروع بلاک اصلاح شده ---
   //bool opened = false;
   string message = "";
   
   // پاک کردن خطای قبلی قبل از هر تلاش
   ResetLastError();
   
   if(bull && !NO_SELL_state)
   {
      // تلاش برای Sell فقط اگر موقعیت مشابه نزدیک نباشد
      if(!IsNearSameTypePosition(POSITION_TYPE_SELL))
      {
         opened = m_trade.Sell(LotSize, _Symbol);
   
         if(opened)
            message = StringFormat("🔻 Sell باز شد — کندل قبلی گاوی بود. Lot=%.2f", LotSize);
         else
         {
            // فقط وقتی تلاش باز کردن اجرا شده و نتیجه false بود، خطا را بخوان
            int err = GetLastError();
            if(err == 0)
               message = "❌ Sell باز نشد — دلیل نامشخص (خطای سیستم 0).";
            else
               message = StringFormat("❌ Sell باز نشد — خطا هنگام اجرا: Err=%d", err);
         }
      }
      else{
         double cur = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         message = StringFormat("NO SELL because it was near, last=%.5f, cur=%.5f, diff=%.5f", g_lastNearPrice, cur , MathAbs(cur-g_lastNearPrice) );
      }
   }
   else if(!bull && !NO_BUY_state)
   {
      // تلاش برای Buy فقط اگر موقعیت مشابه نزدیک نباشد
      if(!IsNearSameTypePosition(POSITION_TYPE_BUY))
      {
         opened = m_trade.Buy(LotSize, _Symbol);
   
         if(opened)
            message = StringFormat("🔺 Buy باز شد — کندل قبلی خرسی بود. Lot=%.2f", LotSize);
         else
         {
            int err = GetLastError();
            if(err == 0)
               message = "❌ Buy باز نشد — دلیل نامشخص (خطای سیستم 0).";
            else
               message = StringFormat("❌ Buy باز نشد — خطا هنگام اجرا: Err=%d", err);
         }
      }
      else{
         double cur = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         message = StringFormat("NO BUY because it was near, last=%.5f, cur=%.5f, diff=%.5f", g_lastNearPrice, cur, MathAbs(cur-g_lastNearPrice) );      
      }
   }
   else
   {
      // حالت‌هایی که معامله اساساً غیرمجاز است (NO_SELL_state / NO_BUY_state)
      if(bull && NO_SELL_state)
         message = "⚠ گاوی بود و فروش نزدیم چون حالت NO_SELL_state فعال است.";
      else if(!bull && NO_BUY_state)
         message = "⚠ خرسی بود و خرید نزدیم چون حالت NO_BUY_state فعال است.";
      else
         message = "XXXXمعامله اجرا نشد — شرایط ورود برقرار نبود.";
   }
   
   // در نهایت فقط یک پیام چاپ شود
   Print(message);
   // --- پایان بلاک اصلاح شده ---


   if(closedBuyCount > 0 || closedSellCount > 0)
      PrintFormat("📊 ClosedTotal=%d (Buy=%d Sell=%d) ProfitBuy=%.2f ProfitSell=%.2f Total=%.2f",
                  closedTotalCount, closedBuyCount, closedSellCount, closedBuyProfit, closedSellProfit, totalProfit);




   LastState = State;
}


double g_lastNearPrice = 0.0;   // قیمت موقعیت نزدیک (برای استفاده بیرون)

bool IsNearSameTypePosition(int type)
{
    g_lastNearPrice = 0.0;   // ریست برای هر بار فراخوانی
    
    double maxDist = 0.00075;   // یک دلار فاصله
    double price = 0.0;
    
    // قیمت ورودی بر اساس نوع معامله
    if(type == POSITION_TYPE_BUY)
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    else
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
    if(price == 0.0) return true ;    
    
    double buySum = 0.0, sellSum = 0.0;
    SumOpenProfits(buySum, sellSum);
    
    int total = (type == (int) POSITION_TYPE_BUY)? numBuy : numSell ;
    if(total == 0) total = 1 ;
    double profit = ( type == (int) POSITION_TYPE_BUY ) ? SingleTradeProfit + CommissionPerTrade * (numBuy-1) : SingleTradeProfit + CommissionPerTrade * (numSell-1);
    PrintFormat("Buy(%d): %.2f , Sell(%d): %.2f, type: %d, total: %d, needed-profit: %.2f", numBuy,buySum,numSell,sellSum, type, total,profit);
    
    
    for(int i=0; i<total; i++)
    {
        if(m_position.SelectByIndex(i))
        {
            int ptype  = (int) m_position.PositionType();
            double pprice = m_position.PriceOpen();

            if(ptype == type)
            {
                if(MathAbs(pprice - price) <= maxDist * total )
                {
                    g_lastNearPrice = pprice;   // ⭐ ذخیره قیمت موقعیت نزدیک
                    return true;                // نزدیک هست
                }
            }
        }
    }
    return false;  // نزدیک نیست
}



//+------------------------------------------------------------------+
double CalculatePureProfit(CPositionInfo &pos)
{
   double open_price = pos.PriceOpen();
   double lots       = pos.Volume();
   long   type       = pos.PositionType();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current_price = (type == POSITION_TYPE_BUY ? bid : ask);

   double point = _Point;
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double diff = (type == POSITION_TYPE_BUY)
                 ? (current_price - open_price)
                 : (open_price - current_price);

   double pips = diff / point * tick_value;
   double profit = pips * 0.90 * lots;

   profit -= pos.Commission();
   profit -= pos.Swap();
   return profit;
}

//+------------------------------------------------------------------+
void CloseAll()
{
   int N = PositionsTotal();
   if( N > 0 )
   do{
      for(int i = 0 ; i < N ; i++ ){
         if( m_position.SelectByIndex(i) ){
            m_trade.PositionClose(m_position.Ticket());
            Sleep(100);
         }
      }
      N = PositionsTotal();
   }while( N > 0 );
}

//+------------------------------------------------------------------+
void re_initialize()
{
   if(Cycles == 0)    
      tranquil = false;
   
   
   
   cycle++;
   
   if(cycle > Cycles){
      tranquil = true;
      reCalculate();
      cycle = 1 ; 
   }
   else 
      tranquil = false;
   
   
   adjustmentDone = false;
   globalShock = 0 ;
   
   DeleteAllStops();
   initialBalance   = m_account.Balance();
   AppendLog(StringFormat("Balance: %.2f", initialBalance));
   
   totalProfit      = 0.0;
   closedTotalCount = 0;
   closedBuyCount   = 0;
   closedSellCount  = 0;
   closedBuyProfit  = 0.0;
   closedSellProfit = 0.0;

   NO_BUY_state     = false;
   NO_SELL_state    = false;

   PrintFormat("🔄 دوره‌ی #%d آغاز شد. بالانس جدید = %.2f", cycle, initialBalance);
}
//+------------------------------------------------------------------+
void ProcessShock()
{
    if(!ShockActive) return;
      
      
    double buySum, sellSum;
    SumOpenProfits(buySum, sellSum);
    
    int buyCount = numBuy;
    int sellCount = numSell;
    int imbalance = MathAbs(sellCount - buyCount);

    // اگر اختلاف خیلی کم شد، خارج شو
    if(imbalance <= 1 )
    {
        ShockActive = false;
        Print("Shock resolved~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        return;
    }

    int posType = POSITION_TYPE_BUY ;
    if(sellCount > buyCount)
       posType = POSITION_TYPE_SELL ;


    // در هر کندل فقط 1 یا 2 معامله ببند
    int maxClosePerCandle = 2;
    int closed = 0;

    while(closed < maxClosePerCandle)
    {
        int j = 0;
        double max_prof = -1e9;
        ulong  ticket = 0;

        // جستجوی بهترین پوزیشن از نوع posType
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(!m_position.SelectByIndex(i)) continue;
            if(m_position.Symbol() != _Symbol) continue;
            int t = (int)m_position.PositionType();
            if(t != posType) continue;

            double prof = CalculatePureProfit(m_position);
            ulong tk = m_position.Ticket();
            j++;
            if(prof > max_prof)
            {
                max_prof = prof;
                ticket = tk;
            }
        }

        // اگر هیچ پوزیشنی از آن نوع نیست، خروج
        if(j == 0 || ticket == 0) break;

        // اگر بیشترین پروفیت کوچک‌تر از آستانه است => دیگر نبند
        if(max_prof - CommissionPerTrade < -1.0) break;

        // تلاش برای بستن
        ResetLastError();
        bool closedOk = m_trade.PositionClose(ticket);
        int err = 0;
        if(!closedOk) err = GetLastError();

        if(closedOk)
        {
            double net = max_prof - CommissionPerTrade;
            totalProfit += net;
            closedTotalCount++;
            if(posType == POSITION_TYPE_BUY) { closedBuyCount++; closedBuyProfit += net; }
            else { closedSellCount++; closedSellProfit += net; }

            PrintFormat("🔒 Closed Ticket=%I64u Type=%s Benefit=%.2f (net after comm)=%.2f | SUM=%.2f",
                        ticket,
                        (posType==POSITION_TYPE_BUY) ? "Buy" : "Sell",
                        max_prof, net, totalProfit);

            closed++;
            Sleep(100);
        }
        else
        {
            PrintFormat("❌ خطا در بستن تیکت %I64u: Error=%d", ticket, err);
            // اگر خطای ناشناخته یا مربوط به تستر بود، برای جلوگیری از حلقهٔ بی‌نهایت یکبار صبر کن و بیرون برو
            Sleep(200);
            break;
        }
    } // end while


}





struct TrendInfo
{
   bool is_up;       // true=UP, false=DOWN
   double start_price;
   double end_price;
   double diff;      // end_price - start_price (مثبت = صعود، منفی = نزول)
};

TrendInfo last_trend;  // خروجی آخرین ترند
double trend_start_price = 0.0; // ذخیره قیمت شروع ترند



// --- تابع اصلی محاسبه
void calculate_trend()
{
    double O1 = iOpen(_Symbol, PERIOD_M5, 1);
    double C1 = iClose(_Symbol, PERIOD_M5, 1);

    bool bull = (C1 > O1);
    bool bear = (C1 < O1);

    string log_txt;

    switch(State)
    {
        case S_IDLE:
            if(bull)
            {
                State = S_SEEN_BULL;
                ref_is_bull = true;
                ref_open  = O1;
                ref_close = C1;
            }
            else if(bear)
            {
                State = S_SEEN_BEAR;
                ref_is_bull = false;
                ref_open  = O1;
                ref_close = C1;
            }
            log_txt = "IDLE";
            break;

        case S_SEEN_BULL:
            log_txt = "SEEN_BULL";

            if(bull)
            {
                // ادامه گاوی‌ها → ref ثابت
                ref_open  = O1;
                ref_close = C1;
                ref_is_bull = true;
            }
            else if(bear)
            {


                // بررسی فوری: کندل خرسی کف آخرین کندل گاوی را شکسته؟
                if(C1 < ref_open)
                {
                    // تشکیل باکس نزولی
                    box_high = ref_close;
                    box_low  = C1;
                    State = S_BOX;

                    ref_open  = O1;
                    ref_close = C1;
                    ref_is_bull = false;

                    //AppendLog(StringFormat("%s | Box created immediately (bear) [%.2f,%.2f]", log_txt, box_low, box_high));
                }
            }
            break;

        case S_SEEN_BEAR:
            log_txt = "SEEN_BEAR";

            if(bear)
            {
                // ادامه خرسی‌ها → ref ثابت
                 ref_open  = O1;
                 ref_close = C1;
                 ref_is_bull = false;
            }
            else if(bull)
            {


                // بررسی فوری: کندل گاوی سقف آخرین کندل خرسی را شکسته؟
                if( C1 > ref_open)
                {
                    // تشکیل باکس صعودی
                    box_low  = ref_close;
                    box_high = C1;
                    State = S_BOX;

                    ref_open  = O1;
                    ref_close = C1;
                    ref_is_bull = true;

                    //AppendLog(StringFormat("%s | Box created immediately (bull) [%.2f,%.2f]", log_txt, box_low, box_high));
                }
            }
            break;

        case S_BOX:
            log_txt = "BOX";
            if(C1 > box_high)
            {
                State = S_TREND_UP;
                trend_start_price = box_high;
            }
            else if(C1 < box_low)
            {
                State = S_TREND_DOWN;
                trend_start_price = box_low;
            }
            break;

        case S_TREND_UP:
            log_txt = "TREND_UP";
            last_trend.end_price = C1;
            
            if(bull)
            {
                // ادامه گاوی‌ها → ref ثابت
                ref_open  = O1;
                ref_close = C1;
                ref_is_bull = true;
            }
            else if(bear)
            {


                // بررسی فوری: کندل خرسی کف آخرین کندل گاوی را شکسته؟
                if(C1 < ref_open)
                {
                
                last_trend.is_up = true;
                last_trend.start_price = trend_start_price;
                last_trend.end_price = C1;
                last_trend.diff = C1 - trend_start_price;

                //AppendLog(StringFormat("TREND_UP finished: start=%.5f end=%.5f diff=%.5f",
                //            last_trend.start_price, last_trend.end_price, last_trend.diff));
                            
                box_high = ref_close;
                box_low  = C1;
                State = S_BOX;
                ref_is_bull = false;
                ref_open  = O1;
                ref_close = C1;
               }
            }
            break;

        case S_TREND_DOWN:
            log_txt = "TREND_DOWN";
            last_trend.end_price = C1;

            if(bear)
            {
                // ادامه خرسی‌ها → ref ثابت
                 ref_open  = O1;
                 ref_close = C1;
                 ref_is_bull = false;
            }
            else if(bull)
            {


                // بررسی فوری: کندل گاوی سقف آخرین کندل خرسی را شکسته؟
                if( C1 > ref_open)
                {   

                   last_trend.is_up = false;
                   last_trend.start_price = trend_start_price;
                   last_trend.end_price = C1;
                   last_trend.diff = C1 - trend_start_price;
   
                   //AppendLog(StringFormat("TREND_DOWN finished: start=%.5f end=%.5f diff=%.5f",
                   //            last_trend.start_price, last_trend.end_price, last_trend.diff));
   
                   box_low  = ref_close;
                   box_high = C1;
                   State = S_BOX;
                   ref_is_bull = true;
                   ref_open  = O1;
                   ref_close = C1;
                
               }
            }
            break;
    }

    // Debug print برای همه حالت‌ها
    //AppendLog(StringFormat("%s | O=%.2f C=%.2f | refO=%.2f refC=%.2f | box=[%.2f,%.2f]",
    //                       log_txt, O1, C1, ref_open, ref_close, box_low, box_high));
}

void AppendLog(string txt)
{
   // زمان باز شدن آخرین کندل M5
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   MqlDateTime s;
   TimeToStruct(t, s);
   int wd = s.day_of_week;
   
   string wd_name;
   switch(wd)
   {
       case 0:  wd_name = "Sun"; break;
       case 1:  wd_name = "Mon"; break;
       case 2:  wd_name = "Tue"; break;
       case 3:  wd_name = "Wed"; break;
       case 4:  wd_name = "Thu"; break;
       case 5:  wd_name = "Fri"; break;
       case 6:  wd_name = "Sat"; break;
   }

   string hs = StringFormat("%s %d, %02d:%02d",wd_name,s.day, s.hour, s.min); 
   
   string line = hs + " | " + txt + "\r\n";
   string LogFileName = "State_of_trends.txt";

   int f = FileOpen(LogFileName, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(f == INVALID_HANDLE)
   {
      // try create
      f = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(f == INVALID_HANDLE) {
         Print("❌ Cannot open/create log file: ", LogFileName);
         return;
      }
   }

   // حرکت به انتهای فایل برای append
   FileSeek(f, 0, SEEK_END);
   FileWriteString(f, line);
   FileFlush(f);
   FileClose(f);
}

void DeleteAllStops()
{
    int total = OrdersTotal(); // تعداد سفارش‌های معلق (Pending)

    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0)
            continue;

        if(!OrderSelect(ticket))
            continue;

        long type = OrderGetInteger(ORDER_TYPE);

        // فقط BuyStop / SellStop
        if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
        {
            MqlTradeRequest req;
            MqlTradeResult  res;
            ZeroMemory(req);
            ZeroMemory(res);

            req.action = TRADE_ACTION_REMOVE;
            req.order  = ticket;

            if(OrderSend(req, res)){
                PrintFormat("Deleted stop order: %I64u", ticket);
                AppendLog(StringFormat("Deleted stop order: %I64u", ticket));
            }
            else
                PrintFormat("Error deleting %I64u : %d", ticket, GetLastError());
        }
    }
}

void CheckNotBuyUntil()
{
    double sb = 0 , sS = 0;
       
    if(!NOT_BUY_UNTIL)
        return;  // اگر کلید غیرفعال است، کاری لازم نیست

    double lastClose = iClose(_Symbol, PERIOD_M5, 1); // قیمت بسته شدن آخرین کندل کامل

    if(lastClose > NotBuyUntilPrice)
    {
        NOT_BUY_UNTIL = false;   // شرط برطرف شد → اجازه خرید آزاد
        Print("NOT_BUY_UNTIL غیر فعال شد؛ قیمت از حد تعیین شده عبور کرد.");
    }else
    if(lastClose < NotBuyUntilPrice - 5 * preventFactor){
        SumOpenProfits(sb,sS);
        if(numBuy > 0){
            NOT_BUY_UNTIL = false;   
            Print("NOT_BUY_UNTIL غیر فعال شد چون قیمت ۲۰۰ پیپ پایین رفت");
        }
    }
}

void CheckNotSellUntil()
{
    double sb = 0 , sS = 0;
    
    if(!NOT_SELL_UNTIL)
        return;  // اگر کلید غیرفعال است، کاری لازم نیست

    double lastClose = iClose(_Symbol, PERIOD_M5, 1); // قیمت بسته شدن آخرین کندل کامل

    if(lastClose < NotSellUntilPrice)
    {
        NOT_SELL_UNTIL = false;   // شرط برطرف شد → اجازه خرید آزاد
        Print("NOT_SELL_UNTIL غیر فعال شد؛ قیمت از حد تعیین شده عبور کرد.");
    }else
    if(lastClose > NotSellUntilPrice + 5 * preventFactor ){
        SumOpenProfits(sb,sS);
        if( numSell > 0 ){
            NOT_SELL_UNTIL = false;   
            Print("NOT_SELL_UNTIL غیر فعال شد چون قیمت ۲۰۰ پی بالا رفت");
        }
    }
}
