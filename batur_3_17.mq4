//+------------------------------------------------------------------+
//|                                                   batur_3_17.mq4 |
//|                                Copyright 2019, Joanes B Prasatya |
//|                                                    17-April-2020 |
//+------------------------------------------------------------------+
#property copyright   "2019, Bernardi Prasatya."
#property link        "http://www.jbp.com"
#property description "Robot Trading Production 3.0"
#property version     "3.17"

#define MAGICNUM  20200417

//
// Version : 2.0   09-May-2019
//         : 2.1   06-Jun-2019
//         : 2.2   15-Jun-2019
//         : 2.3   15-Aug-2019
//         : 2.4   03-Oct-2019 renamed from robot1_cum to batur.
//         : 2.5   20-Oct-2019
//         : 2.6   25-Oct-2019 Added a security feature "safety_on" to prevent margin call.
//         : 2.7   31-Oct-2019 Change the trigger of safety_on. 
//                             if (AccountEquity() - AccountMargin() < 0) safety_on=TRUE;
//         : 2.8   01-Nov-2019 Fixed a few bugs.
//         : 2.81  08-Nov-2019 Fixed a few bugs.
//         : 3.00  28-Nov-2019 Changed the trading logic.
//         : 3.10  24-Dec-2019 Added 1hr and 4hrs RSI.
//         : 3.11  05-Feb-2020 Fixed a bug under "Checking the previous trades" section.
//         : 3.12  19-Feb-2020 Change the Lot calculation.
//                             Added SSD to change the RSI parameter.
//         : 3.13  21-Feb-2020 Modify the SSD ,removed 95% and 5% level.
//         : 3.14  07-Mar-2020 Trade direction is based on Daily SSD or SMA(200).
//         : 3.15  19-Mar-2020 Fixed a few bugs.
//         : 3.16  14-Apr-2020 Added BidAsk <= 70 to open a new trade
//         : 3.17  17-Apr-2020 Added Daily RSI for additional trade direction
//
 
// Define Parameters
    double Lots    = 0.01; 
    int TakeProfit = 100; 
    int distance   = 2000;

//---------------------------------------------------------------------------------------------------------
// Adjust Target Profit
//---------------------------------------------------------------------------------------------------------


void adjust_tp(int ord_count)
{
    double new_profit=0.0,take_new_profit=0.0;
    int count=0;
    string symbol;
  
    // Calculate the new target profit
    take_new_profit = TakeProfit+10+ord_count*3;
    symbol = Symbol();
 
    for (int i=0;i<ord_count;i++)
    {
      if ( (OrderSelect(i, SELECT_BY_POS )==true ) && (OrderSymbol() == symbol) ) {
         if (OrderType() == OP_BUY) new_profit=new_profit+OrderOpenPrice()+(take_new_profit)*Point;
         if (OrderType() == OP_SELL) new_profit=new_profit+OrderOpenPrice()-(take_new_profit)*Point;
         count=count+1;
      }
    }
   
    new_profit=new_profit/count;
    
    for (i=0;i<ord_count;i++)
    {
      if(OrderSelect(i, SELECT_BY_POS )==true )
        bool res=OrderModify(OrderTicket(),OrderOpenPrice(),NULL,NormalizeDouble(new_profit,Digits),0,Blue);
            if(!res)
               Print("Error in OrderModify. Error code=",GetLastError());
            else
               Print("Order modified successfully.");
    }
}
string getSSD(int TF)
{
   double M_1,S_1, diff,diff2,M_2,S_2;
   string SSD_Direction="N/A";
   
   //0 - Low/High or 1 - Close/Close.
   
   M_1 = iStochastic(NULL,TF,12,3,5,MODE_SMA,0,MODE_MAIN,0);
   S_1 = iStochastic(NULL,TF,12,3,5,MODE_SMA,0,MODE_SIGNAL,0);  
   
   M_2 = iStochastic(NULL,TF,12,3,5,MODE_SMA,0,MODE_MAIN,1);
   S_2 = iStochastic(NULL,TF,12,3,5,MODE_SMA,0,MODE_SIGNAL,1); 
   
   diff = MathAbs(M_1-S_1);
   diff2 = MathAbs(M_2-S_2);
   
   SSD_Direction="N/A";
   
   if ( (diff > 1) && (diff2 > 1) )
   {
     if ((M_1 > S_1) && (M_2 > S_2)  && (M_2 <= 80) ) SSD_Direction="BULLISH";
     if ((M_1 < S_1) && (M_2 < S_2)  && (M_2 >= 20)  ) SSD_Direction="BEARISH";   
   } 
          
   return(SSD_Direction);
}

//---------------------------------------------------------------------------------------------------------
// START
//---------------------------------------------------------------------------------------------------------

int start()
{
  int ticket,ord_count=0,ord_type=-10,rsi_param=18;
  string t_direction,d_direction,rsi_direction,daily_ssd,sma_200_dir;
  double rsi2,rsi1,open_price,rsi1_1hr,rsi2_1hr;
  double sma_200,close_daily,rsi1_4hr,rsi2_4hr;
  double rsi_daily_0,rsi_daily_1;
  double BidAsk=0.0;
  static int numBars = 0;

    //--------------------------------------------------------------------------------------------------------
    // Get the trade direction
    //--------------------------------------------------------------------------------------------------------
    t_direction="N/A";
    d_direction="N/A";
    rsi_direction="N/A";
    daily_ssd="N/A";
  
    close_daily = iClose(NULL,PERIOD_D1,1);
    sma_200 = iMA(NULL,PERIOD_D1,200,0,MODE_SMA,PRICE_CLOSE,1); 
    
    daily_ssd = getSSD(PERIOD_D1);
    
    if (close_daily > sma_200) sma_200_dir = "BULLISH";
    if (close_daily < sma_200) sma_200_dir = "BEARISH";
    
    rsi_param=18;  
    if (daily_ssd != "N/A") 
    {
     d_direction = daily_ssd;
     rsi_param=16; // Adjust the 5mnts RSI Parameter
    }
    else
    d_direction = sma_200_dir;
    
    rsi_daily_0=iRSI(NULL,PERIOD_D1,rsi_param,PRICE_CLOSE,0);
    rsi_daily_1=iRSI(NULL,PERIOD_D1,rsi_param,PRICE_CLOSE,1);
    
    if ((rsi_daily_1 <= 30) && (rsi_daily_0 > 30)) d_direction="BULLISH";
    if ((rsi_daily_1 >= 70) && (rsi_daily_0 < 70)) d_direction="BEARISH";

    rsi1=iRSI(NULL,PERIOD_M5,rsi_param,PRICE_CLOSE,1);
    rsi2=iRSI(NULL,PERIOD_M5,rsi_param,PRICE_CLOSE,2);
    
    rsi1_1hr=iRSI(NULL,PERIOD_H1,18,PRICE_CLOSE,1);
    rsi2_1hr=iRSI(NULL,PERIOD_H1,18,PRICE_CLOSE,2);
    
    rsi1_4hr=iRSI(NULL,PERIOD_H4,18,PRICE_CLOSE,1);
    rsi2_4hr=iRSI(NULL,PERIOD_H4,18,PRICE_CLOSE,2);
    
    
    // 5 mnts RSI
    distance   = 2000;
    if ((rsi2 <= 30) && (rsi1 > 30)) rsi_direction="BULLISH";
    if ((rsi2 >= 70) && (rsi1 < 70)) rsi_direction="BEARISH";
    
    // 1hr RSI
    if ((rsi2_1hr <= 30) && (rsi1_1hr > 30)) { rsi_direction="BULLISH"; distance   = 1500; }
    if ((rsi2_1hr >= 70) && (rsi1_1hr < 70)) { rsi_direction="BEARISH"; distance   = 1500; } 
    
    // 4hrs RSI    
    if ((rsi2_4hr <= 30) && (rsi1_4hr > 30)) { rsi_direction="BULLISH"; distance   = 1500; }
    if ((rsi2_4hr >= 70) && (rsi1_4hr < 70)) { rsi_direction="BEARISH"; distance   = 1500; } 
  
    if ( rsi_direction == d_direction && rsi_direction != "N/A" ) t_direction=rsi_direction;
  
  
    //--------------------------------------------------------------------------------------------------------
    // Checking the previous trades
    //--------------------------------------------------------------------------------------------------------
    ord_count= OrdersTotal();
    if(OrderSelect(0, SELECT_BY_POS )==true)
      {
       ord_type=OrderType();
       // Override DAILY SMA(200) if there're trades already open.
  
       if ( (ord_type == OP_BUY) && (t_direction=="BEARISH") )  t_direction="N/A";
       if ( (ord_type == OP_SELL) && (t_direction=="BULLISH") )  t_direction="N/A";
       
       if ( (ord_type == OP_BUY) && (rsi_direction=="BULLISH") )  t_direction="BULLISH";
       if ( (ord_type == OP_SELL) && (rsi_direction=="BEARISH") )  t_direction="BEARISH";
      }
       
    // Get the last opening price
    if(OrderSelect(ord_count-1, SELECT_BY_POS )==true) open_price=OrderOpenPrice();   
    
    BidAsk = MathAbs(Bid-Ask)*MathPow(10,Digits); 
    //--------------------------------------------------------------------------------------------------------
    // Prepare to Open a trade
    //--------------------------------------------------------------------------------------------------------
      Lots = MathFloor(AccountBalance()/120)*0.01; // Calculate the lot.
      if (Lots <=0.01) Lots=0.02;
      
      if (BidAsk <=70)
      {
      if ( ( t_direction == "BULLISH") && ( MathAbs(open_price-Bid) > distance*Point) ) { 
        if (numBars != Bars)
         {
           ticket = OrderSend(Symbol(), OP_BUY, Lots+(ord_count*0.01),Ask,10, NULL, Bid+TakeProfit*Point, 
                    "Robot EURCAD 5mnts BUY "+Symbol(),MAGICNUM,0,Blue);
           ord_count= OrdersTotal();
           if (ord_count > 1) adjust_tp(ord_count);
    
           if(ticket < 0) Alert("Error Sending BUY order !");
           numBars = Bars;
         }
      } 

      if ( (t_direction == "BEARISH") && ( MathAbs(Ask - open_price) > distance*Point) ) {
      if (numBars != Bars) {
           ticket = OrderSend(Symbol(), OP_SELL, Lots+(ord_count*0.01),Bid,10, NULL, Ask-TakeProfit*Point, 
                    "Robot EURCAD 5mnts SELL "+Symbol(),MAGICNUM,0,Red);
           ord_count= OrdersTotal();
           if (ord_count > 1) adjust_tp(ord_count);
    
           if(ticket < 0) Alert("Error Sending SELL order !");
           numBars = Bars;
         }
      } 
      }
      
      Comment("Period : "+Period()+" #Total Order : "+ord_count+" #rsi1 : "+rsi1+" #rsi2 : "+rsi2+
              " #Trade Direction : "+t_direction+" #Daily SSD : "+daily_ssd+" #Daily Dir : "+d_direction+
              " #Lots : "+Lots+" Bid Ask : "+BidAsk);    
   
    return(0);
}

