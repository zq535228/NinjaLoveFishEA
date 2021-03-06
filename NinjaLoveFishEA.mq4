//+-----------------------------+
//|     NinjaLoveFishEA.mq4     |
//| Copyright @2018, renzhe.org |
//+-----------------------------+

/*
2019年7月9日09:41:35统计
EURUSD
TakeProfitPoint=1700   StepATRMultiplier=4.5   MiniGridDistance=600
EURJPY
TakeProfitPoint=950    StepATRMultiplier=4.5   MiniGridDistance=400
GBPUSD
TakeProfitPoint=1700   StepATRMultiplier=6.5   MiniGridDistance=550

2019年8月7日
放弃的直接入场的BB和SS按钮，因为在本月初，由于这个按钮没有按照规则入场，导致了严重的被套，货币兑包括：GBPJPY和GBPUSD。
降低风险，保证单独在场的货币兑只有一个存在，防止由于同一个货币兑判断失误造成的严重失误。

2019年8月8日
入场的RSI降低风险，如果是货币兑含GBP\JPY的话，那么RSI的值为12和14.

2019年8月9日
LOT降低风险，如果货币兑包含GBP，和JPY的话，那么perlot的值分别为2.0和3.0
可以设置双MT4,分别对应短线和中线单，中线单注意库存费的正负。长线单可以是手工单。
如果在一个货币兑中触发了10%的止损，那么不要切换到其他相关货币兑上进行操作，必须仍然操作该货币兑。

2019年8月10日
修改了止损20%
增加了RSI的周期参数，默认为8，如果遇到超级行情，可以增加这个数值，对于GBP=8+4和JPY=8+6。
优化了PerLot 在init中加载。
增加SLPrice参数，用于订单的设置止损，主要用于布局中长线的反转单。

2019年8月11日
增加了TF的止盈参数
增加了SIGNAL的2个参数，切换和执行挂单的周期。

2019年8月12日
修复了TF的挂单瞬间关闭的BUG。去掉了实盘入场RSI的限制。

2019年8月13日
SIGNAL的指标，增加了持仓货币兑，调试优化了很多细节。
EA调整为高风险，高收益模式，即1000对应0.01的模式。记住不做GBP和JPY这两个货币兑。

2019年8月14日
仓位：GBP是1.5倍，JPY是2倍。
RSI：GBP是+2，JPY是+4。

2019年8月15日
增加了SIGNAL的买卖持仓过夜费的显示。

2019年8月16日
去掉了SIGNAL中的MagicSell和MagicBuy的识别代码。进行全仓位识别。

2019年8月25日
修改了仓位下单手数的逻辑，去掉了按5000=0.01的比例下单。

2019年8月31日
重新计算预期盈利。（暂时未执行）填充为Null

2019年9月1日
修改signal的rsi为60-40
修改初始化下单手数为：re=10/earn-0.004;

2019年9月9日
启动了测试过滤时间的功能。

2019年9月14日
进行测试修复AUDUSD和EURGBP

2019年10月2日
修复相同货币出现的时候，另一个货币兑虚拟挂单线，不取消的问题。（尝试解决）

2019年10月7日
上架了demo的信号

2019年10月11日
修复了最大手数限制的问题。

2019年10月12日
测试和真实运作使用了同样的手数限制。新增了GBPCAD和GBPAUD货币兑，但要铭记历史，谨防乱跳。

2019年10月24日
重大的更新，不需要固定的TP和网格间距，采用ATR来衡量货币的波动率。

2019年10月30日
去掉挂单时间的限制，因为这个判断一直无法使用。

2019年12月7日
添加了comm中的空格。
RSI：GBP是+8，JPY是+8+8。


*/

//发布前,要修改3个地方,1个是版本号,一个是DEBUG模式关闭.


#define Version "2.81"
#define EAName "NinjaLoveFishEA"

#property strict
#property version Version
#property copyright "Copyright @2018, Qin Zhao"
#property link "https://www.mql5.com/en/users/zq535228"
#property icon "3232.ico"
#property description "This EA contains two modes, automatic and manual mode,welcome to download.\nIt's recommended to test the EA in the Strategy Tester before using the live account."
#include <stderror.mqh>
#include <stdlib.mqh>
#include "comm.mqh"
#include "Shields.mqh"
#include "comm_signals.mqh"


extern static string EA=EAName+" v"+Version;

extern string s2                                   = "--------General Setting -------------";
extern int    MagicNumberBuy                       = 123;
extern int    MagicNumberSell                      = 321;
input double  StopLossPercent                      = 15;
input double  SLPrice                              = 0;

extern string s4                                   = "--------First Order AutoMode Enable -------------";
extern bool   AutoMode                             = false;

extern string s10                                  = "--------First Order Indicators Setting -------------";
extern double BB_Width                             = 3000;
extern int RSIperiod                               = 8;
extern double RSIbuy                               = 20;
extern double RSIsell                              = 80;

extern string s12                                  = "--------Basic Orders Settings -------------";
extern int    BaseGridNum                          = 2;
extern double StepATRMultiplier                    = 3.5;
extern int    MaxTrades                            = 10;
extern int    MiniGridDistance                     = 250;


string s6                                          = "--------First Order Filters Setting -------------";
bool   ShowInfo                                    = true;
bool   ShowLine                                    = true;
double VirtualOrderATRMultiplier                   = 5;
int    PendingHours                                = 120;
int    MaxSymbolInPosition                         = 1;
double MaxSpreadPoint                              = 40;
bool   TimeFilter                                  = true;
string TimeStart                                   = "02:00";
string TimeEnd                                     = "22:00";
bool   NewsFilter                                  = true;
int    NewsOffset                                  = 2;
bool   NewsVhigh                                   = true;
bool   NewsVmedium                                 = true;
bool   NewsVlow                                    = false;
int    BeforeNewsStopMin                           = 7;
int    AfterNewsStopMin                            = 7;

extern string s8                                   = "--------Pips and Grids Settings -------------";
extern double LotMutiple                           = 1.8;
extern double MaxLot_001                           = 100;
extern int    SameLotsOrder                        = 6;
extern double PipStepExponent                      = 1.3;
extern double TPDecreasePercent                    = 20;
extern bool   IsOverlapping                        = false;
extern int    OverlappingNum                       = 5;
double GridSplitHour                               = 0.5;
double ProfitPersent                               = 30;
double SecondProfitPersent                         = 50;

int StepATRPeriod=14;
int vDigits;
int OrderSended=0;
int TotalBuyOrders=0,TotalSellOrders=0;
int Lpos,Lpos1,Cpos;

double StepPoint,GridSplitSec,MaxLot;
double vPoint;
double PriceTarget,AveragePrice,LastBuyPrice,LastSellPrice;
double BuySummLot,SellSummLot,TotalProfitBuy,TotalProfitSell;
double BLot,SLot;
double Cprofit,Lprofit,Lprofit1,PrcCL,Lprice,Cprice;
double FirstOrderOpenPrice,LastOrderOpenPrice;

string LastOrderComment="";
string BComment,SComment;

datetime LastOrderOpenTime,FirstOrderOpenTime;
//+-----------------------------+
//|                              |
//+-----------------------------+
int init()
  {
   if(!IsTradeAllowed())
      Alert("Trade Not Allowed!");

   EA=EAName+" v"+Version;

   vPoint=Point;
   vDigits=Digits;

   GridSplitSec=GridSplitHour*3600;
   MaxLot = AccountBalance()/MaxLot_001;

   if(IsTest())
     {
      AutoMode=true;
      NewsFilter=false;
      //MaxTrades=20;//测试的时候，最大订单数量为20.运行模式默认为10
      ShowLine=false;
     }

   if(ShowInfo)
      DrawInfo();

   long x_distance;
   long y_distance;
//--- set window size
   if(!ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0,x_distance))
     {
      Print("Failed to get the chart width! Error code = ",GetLastError());
     }
   if(!ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,y_distance))
     {
      Print("Failed to get the chart height! Error code = ",GetLastError());
     }

   ObjectCreate(0,"BUY",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"BUY",OBJPROP_XDISTANCE,x_distance/3);
   ObjectSetInteger(0,"BUY",OBJPROP_YDISTANCE,20);
   ObjectSetString(0,"BUY",OBJPROP_TEXT,"BUY");
   ObjectSetInteger(0,"BUY",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"BUY",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"BUY",OBJPROP_XSIZE,70);
//ObjectSetString(0,"BUY",OBJPROP_FONT,"Calibri");

   if(MarketInfo(Symbol(),MODE_SWAPLONG)>0)
     {
      ObjectSetInteger(0,"BUY",OBJPROP_BGCOLOR,clrChartreuse);
      ObjectSetString(0,"BUY",OBJPROP_TEXT,"BUY +"+DoubleToStr(MarketInfo(Symbol(),MODE_SWAPLONG),1));
     }
   else
     {
      ObjectSetInteger(0,"BUY",OBJPROP_BGCOLOR,clrLightSalmon);
      ObjectSetString(0,"BUY",OBJPROP_TEXT,"BUY "+DoubleToStr(MarketInfo(Symbol(),MODE_SWAPLONG),1));
     }

   ObjectCreate(0,"SELL",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"SELL",OBJPROP_XDISTANCE,x_distance/3+90);
   ObjectSetInteger(0,"SELL",OBJPROP_YDISTANCE,20);
   ObjectSetString(0,"SELL",OBJPROP_TEXT,"SELL");
   ObjectSetInteger(0,"SELL",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"SELL",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"SELL",OBJPROP_XSIZE,70);

   if(MarketInfo(Symbol(),MODE_SWAPSHORT)>0)
     {
      ObjectSetInteger(0,"SELL",OBJPROP_BGCOLOR,clrChartreuse);
      ObjectSetString(0,"SELL",OBJPROP_TEXT,"SELL +"+DoubleToStr(MarketInfo(Symbol(),MODE_SWAPSHORT),1));
     }
   else
     {
      ObjectSetInteger(0,"SELL",OBJPROP_BGCOLOR,clrLightSalmon);
      ObjectSetString(0,"SELL",OBJPROP_TEXT,"SELL "+DoubleToStr(MarketInfo(Symbol(),MODE_SWAPSHORT),1));
     }

   ObjectCreate(0,"CLOSE",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"CLOSE",OBJPROP_XDISTANCE,x_distance/3+250);
   ObjectSetInteger(0,"CLOSE",OBJPROP_YDISTANCE,20);
   ObjectSetString(0,"CLOSE",OBJPROP_TEXT,"CLOSE");
   ObjectSetInteger(0,"CLOSE",OBJPROP_BGCOLOR,clrTomato);
   ObjectSetInteger(0,"CLOSE",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"CLOSE",OBJPROP_FONTSIZE,8);

   ObjectCreate(0,"SHOOT",OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,"SHOOT",OBJPROP_XDISTANCE,x_distance/3+320);
   ObjectSetInteger(0,"SHOOT",OBJPROP_YDISTANCE,20);
   ObjectSetString(0,"SHOOT",OBJPROP_TEXT,"SHOOT");
   ObjectSetInteger(0,"SHOOT",OBJPROP_BGCOLOR,clrLightBlue);
   ObjectSetInteger(0,"SHOOT",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"SHOOT",OBJPROP_FONTSIZE,8);

   return(INIT_SUCCEEDED);

  }
//
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   double h=0;
//--- If you click on the object with the name buttonID
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="BUY" && ObjectGetInteger(0,"BUY",OBJPROP_STATE))
     {
      //--- State of the button - pressed or not
      bool selected1=ObjectGetInteger(0,"BUY",OBJPROP_STATE);
      //--- log a debug message
      Print("BUY Button pressed = ",selected1);
      double np=Bid-GetPointForFirstManualOrder();
      setLine("BuyLine",np,clrChartreuse,1,true,STYLE_SOLID);
      dump("I will open the buy order grids at the price of "+DoubleToStr(np,5));
      ObjectSetInteger(0,"BUY",OBJPROP_STATE,0);
     }
//
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="SELL" && ObjectGetInteger(0,"SELL",OBJPROP_STATE))
     {
      //--- State of the button - pressed or not
      bool selected2=ObjectGetInteger(0,"SELL",OBJPROP_STATE);
      //--- log a debug message
      Print("SELL Button pressed = ",selected2);
      double np=Ask+GetPointForFirstManualOrder();
      setLine("SellLine",np,clrChartreuse,1,true,STYLE_SOLID);
      dump("I will open the sell order grids at the price of "+DoubleToStr(np,5));
      ObjectSetInteger(0,"SELL",OBJPROP_STATE,0);
     }
//
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="CLOSE" && ObjectGetInteger(0,"CLOSE",OBJPROP_STATE))
     {
      //--- State of the button - pressed or not
      bool selected3=ObjectGetInteger(0,"CLOSE",OBJPROP_STATE);
      //--- log a debug message
      Print("CLOSE Button pressed = ",selected3);

      if(MessageBox("Are you sure to close this pair's all orders?","Please Confirm!",1)==1)
        {
         while(OrdersTotal()!=0)
           {
            closeAll(MagicNumberBuy);
            closeAll(MagicNumberSell);
           }
        }
      ObjectSetInteger(0,"CLOSE",OBJPROP_STATE,0);
     }
//
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="SHOOT" && ObjectGetInteger(0,"SHOOT",OBJPROP_STATE))
     {
      //--- State of the button - pressed or not
      bool selected4=ObjectGetInteger(0,"SHOOT",OBJPROP_STATE);
      //--- log a debug message
      Print("SHOOT Button pressed = ",selected4);
      screenshot();
      ObjectSetInteger(0,"SHOOT",OBJPROP_STATE,0);
     }

  }
//


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {

   if(!IsNewBar())
     {
      return 0;//如果上是新bar,那么直接返回.等待新bar
     }

   if(ShowInfo)
      DrawInfo();

   TotalBuyOrders = CountOfOrders(MagicNumberBuy);
   TotalSellOrders= CountOfOrders(MagicNumberSell);

   CheckSL();

//非测试环境下，才进行止损，挂单等判断。
   if(!IsTest())
     {
      //清理现有仓位的挂单。rsip
      if(TotalSellOrders>0)
         deleteObjects("SellLine");
      if(TotalBuyOrders>0)
         deleteObjects("BuyLine");
     }

   CheckTakeProfit();

   if(IsOverlapping)
      CheckOverlapping();

// Next buy orders
   if(TotalBuyOrders>0 && TotalBuyOrders<MaxTrades && CheckTimeForTrade(TimeStart,TimeEnd) && TimeFilterForTrade(GridSplitSec,MagicNumberBuy))
     {
      LastBuyPrice = FindLastOrderParameter(MagicNumberBuy, "price");
      double nextb = LastBuyPrice - GetPointForStep(TotalBuyOrders + 1);
      if(ShowLine)
         setLine("NextLine",nextb,clrCornflowerBlue);

      bool dnlevel=Bid<=nextb;
      if(dnlevel)
        {
         BLot=getLots(BaseGridNum,LotMutiple,MagicNumberBuy);
         if(BLot>MaxLot)
            BLot=MaxLot;
         BComment=StringSubstr(LastOrderComment,0,StringFind(LastOrderComment,"|",0))+"|"+IntegerToString(TotalBuyOrders);
         OrderSended=openBuy(BLot,MagicNumberBuy,BComment);
         deleteObjects("NextLine");
        }
     }

// Next sell orders
   if(TotalSellOrders>0 && TotalSellOrders<MaxTrades && CheckTimeForTrade(TimeStart,TimeEnd) && TimeFilterForTrade(GridSplitSec,MagicNumberSell))
     {
      LastSellPrice= FindLastOrderParameter(MagicNumberSell,"price");
      double nexts = LastSellPrice+GetPointForStep(TotalSellOrders+1);
      if(ShowLine)
         setLine("NextLine",nexts,clrCornflowerBlue);

      bool uplevel=Ask>=nexts;
      if(uplevel)
        {
         SLot=getLots(BaseGridNum,LotMutiple,MagicNumberSell);
         if(SLot>MaxLot)
            SLot=MaxLot;
         SComment=StringSubstr(LastOrderComment,0,StringFind(LastOrderComment,"|",0))+"|"+IntegerToString(TotalSellOrders);
         OrderSended=openSell(SLot,MagicNumberSell,SComment);
         deleteObjects("NextLine");
        }

     }

//时间判断
   if(!IsTest() && TimeFilter && !CheckTimeForTrade(TimeStart,TimeEnd))
     {
      return 0;
     }

//新闻判断
   if(!IsTest() && NewsFilter && CheckNews()>0)
     {
      return 0;
     }

//滑点过滤器
   if(!IsTest() && !CheckSpread(MaxSpreadPoint))
     {
      return 0;
     }

//最大相同单过滤器
   if(GetPositionExistNum(Symbol(),MagicNumberBuy)+GetPositionExistNum(Symbol(),MagicNumberSell)>=MaxSymbolInPosition)
     {
      //dump("MaxSymbolInPosition over the MaxNumber!");
      deletePending();
      return 0;
     }

//手工单判断（Buy）
   if(TotalBuyOrders==0 && getLineValue("BuyLine")>0 && Bid<getLineValue("BuyLine") && GetSignal_RSI(PERIOD_M5,RSIperiod)!=0 && GetSignal_RSI(PERIOD_M5,RSIperiod)<RSIbuy)
     {
      openBuy(GetStartLot(),MagicNumberBuy,"Ninja/"+Symbol()+"/"+DoubleToStr(MagicNumberBuy,0)+"|M");
      deletePending();
     }
//手工单判断（Sell）
   if(TotalSellOrders==0 && getLineValue("SellLine")>0 && Ask>getLineValue("SellLine") && GetSignal_RSI(PERIOD_M5,RSIperiod)!=0 && GetSignal_RSI(PERIOD_M5,RSIperiod)>RSIsell)
     {
      openSell(GetStartLot(),MagicNumberSell,"Ninja/"+Symbol()+"/"+DoubleToStr(MagicNumberBuy,0)+"|M");
      deletePending();
     }

//如果自动交易关闭,或者已经超过最大单量了,那么到此结束.
   if(AutoMode==false || CountOfOrders()>MaxTrades)
     {
      return(0);
     }

//进入自动化交易模式，买单的判断。
   if(TotalBuyOrders==0 && GetSignal_RSI(PERIOD_M5,RSIperiod)!=0 && GetSignal_RSI(PERIOD_M5,RSIperiod)<RSIbuy)
     {
      openBuy(GetStartLot(),MagicNumberBuy,"Ninja/"+Symbol()+"/"+DoubleToStr(MagicNumberBuy,0)+"|A");
      dump("========================================>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>openBuy:"+datetime());
      dump("========================================>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>rsi:"+GetSignal_RSI(PERIOD_M5,RSIperiod));
     }

//进入自动化交易模式，卖单的判断。
   if(TotalSellOrders==0 && GetSignal_RSI(PERIOD_M5,RSIperiod)!=0 && GetSignal_RSI(PERIOD_M5,RSIperiod)<RSIbuy)
     {
      openSell(GetStartLot(),MagicNumberSell,"Ninja/"+Symbol()+"/"+DoubleToStr(MagicNumberSell,0)+"|A");
      dump("========================================>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>openSell:"+datetime());
      dump("========================================>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>rsi:"+GetSignal_RSI(PERIOD_M5,RSIperiod));
     }

   return(0);
  }
//===================================================================================================================================================
//===================================================================================================================================================
void CheckTakeProfit()
  {
   double tp = GetTakeProfitPoint();
//BUY
   PriceTarget=0;
   AveragePrice=0;

   if(TotalBuyOrders>0)
     {
      AveragePrice= CalculateAveragePrice(MagicNumberBuy);
      PriceTarget = AveragePrice+tp;
      if(TotalBuyOrders>1)
        {
         PriceTarget=AveragePrice+tp*MathPow(1-TPDecreasePercent*0.01,TotalBuyOrders-1);
        }
      modifyTP(PriceTarget,MagicNumberBuy);
      if(ShowInfo)
        {
         setLine("AvgLine",AveragePrice,clrYellow);
        }
     }

   if(Ask>PriceTarget && !hasTPValue(MagicNumberBuy))
     {
      //如果已经获利，并且没有设置TP值，那么自动进入关闭。
      while(CountOfOrders(MagicNumberBuy)!=0)
        {
         closeAll(MagicNumberBuy);
        }
     }

//SELL
   PriceTarget=0;
   AveragePrice=0;

   if(TotalSellOrders>0)
     {
      AveragePrice=CalculateAveragePrice(MagicNumberSell);
      PriceTarget=AveragePrice-tp;
      if(TotalSellOrders>1)
        {
         PriceTarget=AveragePrice-tp*MathPow(1-TPDecreasePercent*0.01,TotalSellOrders-1);
        }
      modifyTP(PriceTarget,MagicNumberSell);
      if(ShowInfo)
         setLine("AvgLine",AveragePrice,clrYellow);
     }

   if(Bid<PriceTarget && !hasTPValue(MagicNumberSell))
     {
      //如果已经获利，并且没有设置TP值，那么自动进入关闭。

      while(CountOfOrders(MagicNumberSell)!=0)
        {
         closeAll(MagicNumberSell);
        }
     }

   if(ShowLine==true && (TotalBuyOrders+TotalSellOrders)==0)
     {
      clearLines();
     }

  }


bool IsCloseAllBuy=false;
bool IsCloseAllSell=false;
//+-----------------------------+
//|进行止损判断                                                       |
//+-----------------------------+
void CheckSL()
  {
//如果已存最大允许货币兑持仓数量，那么自动删除目前的挂单

   if(TotalBuyOrders+TotalSellOrders>=MaxTrades && !IsTest())
     {
      dump("Over the Max Orders. "+IntegerToString(TotalBuyOrders+TotalSellOrders)+">="+IntegerToString(MaxTrades));
      deletePending();
     }

//buy_SL
   if(TotalBuyOrders>0 && SLPrice!=0)
     {
      modifySL(SLPrice,MagicNumberBuy);
     }

   if(StopLossPercent!=0 && getProfit(MagicNumberBuy)/AccountBalance()<(-1)*StopLossPercent*0.01)
     {
      IsCloseAllBuy=true;
     }
//判断是否关闭买单,如果是,进入买单循环关闭
   while(IsCloseAllBuy)
     {
      closeAll(MagicNumberBuy);
      if(CountOfOrders(MagicNumberBuy)==0)
        {
         IsCloseAllBuy=false;
        }
     }

//sell_SL
   if(TotalSellOrders>0 && SLPrice!=0)
     {
      modifySL(SLPrice,MagicNumberSell);
     }

   if(StopLossPercent!=0 && getProfit(MagicNumberSell)/AccountBalance()<(-1)*StopLossPercent*0.01)
     {
      IsCloseAllSell=true;
     }
//判断是否关闭卖单,如果是,进入卖单循环关闭
   while(IsCloseAllSell)
     {
      closeAll(MagicNumberSell);
      if(CountOfOrders(MagicNumberSell)==0)
        {
         IsCloseAllSell=false;
        }
     }

  }
//计算订单平均价格.
double CalculateAveragePrice(int mNumber)
  {
   double Count=0;
   for(int i=0; i<OrdersTotal(); i++)
      //+-----------------------------+
      //|                                                                  |
      //+-----------------------------+
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==mNumber)
            if(OrderType()==OP_BUY || OrderType()==OP_SELL)
              {
               AveragePrice+=OrderOpenPrice()*OrderLots();
               Count+=OrderLots();
              }

   if(AveragePrice>0 && Count>0)
      return(NormalizeDouble(AveragePrice / Count, vDigits));
   else
      return(0);
  }
//计算下一个订单的距离Point
double GetPointForStep(int CurrStep)
  {
   double re= 0;
   StepPoint=GetSignal_ATR(StepATRPeriod)*StepATRMultiplier;
   double CurrPipstep=NormalizeDouble(StepPoint*MathPow(PipStepExponent,CurrStep),Digits);
   double mini=MiniGridDistance *vPoint;
   re=IIFd(CurrPipstep<mini,mini,CurrPipstep);//如果间距不足，那么取最小间距。

   return(re);
  }
//获取手动单的距离Point
double GetPointForFirstManualOrder()
  {
   double re=GetSignal_ATR(StepATRPeriod)*VirtualOrderATRMultiplier;
   return(re);
  }
//
double GetClosedProfit(int mNumber)
  {
   double ClosedProfit=0;

   for(int i=OrdersHistoryTotal(); i>0; i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==mNumber)
            if(StringSubstr(LastOrderComment,0,StringFind(LastOrderComment,"|",0))==StringSubstr(OrderComment(),0,StringFind(OrderComment(),"|",0)))
               ClosedProfit=ClosedProfit+OrderProfit();

   return(ClosedProfit);
  }
//+-----------------------------+
//| OverLapping                                                      |
//+-----------------------------+
void CheckOverlapping()
  {

//BUY--->
   TotalBuyOrders=CountOfOrders(MagicNumberBuy);

//
   if(TotalBuyOrders>=OverlappingNum)
     {
      Lpos=0;
      Cpos=0;
      Lprofit=0;
      Cprofit=0;
      Lpos=LidingProfitOrder(MagicNumberBuy);//获取最赚钱的单

      Cpos=LeastProfitOrder(MagicNumberBuy);//获取最赔钱的单

      if(Lprofit>0 && Lprofit1<=0)
        {
         if(Lprofit+Cprofit>0 && (Lprofit+Cprofit)*100/Lprofit>ProfitPersent) //1和N,
           {
            Lpos1=0;
            CloseSelectOrder(MagicNumberBuy);
           }
        }
      else
         if(Lprofit>0 && Lprofit1>0)
           {
            if(Lprofit+Lprofit1+Cprofit>0 && (Lprofit+Lprofit1+Cprofit)*100/(Lprofit+Lprofit1)>SecondProfitPersent)
               CloseSelectOrder(MagicNumberBuy);
           }
     }
//<---BUY

//SELL--->
   TotalSellOrders=CountOfOrders(MagicNumberSell);

//
   if(TotalSellOrders>=OverlappingNum)
     {
      Lpos = 0;
      Cpos = 0;
      Lprofit = 0;
      Cprofit = 0;
      Lpos = LidingProfitOrder(MagicNumberSell);
      Cpos = LeastProfitOrder(MagicNumberSell);

      if(Lprofit>0 && Lprofit1<=0)
        {
         if(Lprofit+Cprofit>0 && (Lprofit+Cprofit)*100/Lprofit>ProfitPersent)
           {
            Lpos1=0;
            CloseSelectOrder(MagicNumberSell);
           }
        }
      if(Lprofit>0 && Lprofit1>0)
        {
         if(Lprofit+Lprofit1+Cprofit>0 && (Lprofit+Lprofit1+Cprofit)*100/(Lprofit+Lprofit1)>SecondProfitPersent)
            CloseSelectOrder(MagicNumberSell);
        }
     }
//<---SELL
  }
//======================================== Most profitable order =======================================
int LidingProfitOrder(int mNumber)
  {
   Lprofit1=0;
   Lpos1=0;
   int TotalOrders= CountOfOrders(mNumber);
   double profit  = 0;
   int    Pos     = 0;
//
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if((OrderSymbol()==Symbol()) && (OrderMagicNumber()==mNumber))
           {
            if(OrderType()==OP_SELL || OrderType()==OP_BUY)
              {
               profit = OrderProfit();
               Pos    = OrderTicket();
               if(profit>0 && profit>Lprofit)
                 {
                  // Previous value
                  Lprofit1 = Lprofit;
                  Lpos1    = Lpos;
                  Lprice=OrderOpenPrice();
                  // Maximum value
                  Lprofit = profit;
                  Lpos    = Pos;
                 }
              }
           }
        }
     }
   return (Lpos);
  }
//========================================  Least Profitable Order =======================================
int LeastProfitOrder(int mNumber)
  {
   double profit  = 0;
   int    Pos     = 0;
//
   for(int trade=OrdersTotal()-1; trade>=0; trade--)
     {
      if(OrderSelect(trade,SELECT_BY_POS,MODE_TRADES))
        {
         if((OrderSymbol()==Symbol()) && (OrderMagicNumber()==mNumber))
           {
            if(OrderType()==OP_SELL || OrderType()==OP_BUY)
              {
               profit = OrderProfit();
               Pos    = OrderTicket();
               if(profit<0 && profit<Cprofit)
                 {
                  Cprofit = profit;
                  Cpos    = Pos;
                  Cprice=OrderOpenPrice();
                 }
              }
           }
        }
     }
   return (Cpos);
  }
//==========================================  Closing Orders ===============================================
int CloseSelectOrder(int mNumber)
  {
   int error=0;
   int error1 = 0;
   int error2 = 0;
   int Result = 0;

//
   while(error1==0)
     {
      RefreshRates();
      int i=OrderSelect(Lpos,SELECT_BY_TICKET,MODE_TRADES);
      if(i!=1)
        {
         Print("Error! Not possible to select most profitable order . Operation cancelled.");
         return (0);
        }
      if((OrderSymbol()==Symbol()) && (OrderMagicNumber()==mNumber))
        {
         if(OrderType()==OP_BUY)
           {
            error1=(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,Digits),3,clrNONE));
            if(error1==1)
              {
               Print("Leading Order closed successfully");
               Sleep(500);
              }
            else
              {
               Print("Error closing leading order, Repeat Operation. ");
              }
           }
         //----------------
         if(OrderType()==OP_SELL)
           {
            error1=(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,Digits),3,clrNONE));
            if(error1==1)
              {
               Print("Leading Order closed successfully");
               Sleep(500);
              }
            else
              {
               Print("Error closing leading order, Repeat Operation. ");
              }
           }
        }
     }
//---------------------- Previous Last  -----------------------
   if(Lpos1!=0)
     {
      while(error2==0)
        {
         RefreshRates();
         int i=OrderSelect(Lpos1,SELECT_BY_TICKET,MODE_TRADES);
         if(i!=1)
           {
            Print("Error! Not possible to select previous most profitable order . Operation cancelled.");
            return (0);
           }
         if((OrderSymbol()==Symbol()) && (OrderMagicNumber()==mNumber))
           {
            if(OrderType()==OP_BUY)
              {
               error2=(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,Digits),3,clrNONE));
               if(error2==1)
                 {
                  Print("Previous leading order closed successfully");
                  Sleep(500);
                 }
               else
                 {
                  Print("Error closing previous leading order, Repeat Operation. ");
                 }
              }
            //----------------
            if(OrderType()==OP_SELL)
              {
               error2=(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,Digits),3,clrNONE));
               if(error2==1)
                 {
                  Print("Previous leading order closed successfully");
                  Sleep(500);
                 }
               else
                 {
                  Print("Error closing previous leading order, Repeat Operation. ");
                 }
              }
           }
        }
     }
//----------- Selected (Least profitable order ) -----------
   while(error==0)
     {
      RefreshRates();
      int i=OrderSelect(Cpos,SELECT_BY_TICKET,MODE_TRADES);
      if(i!=1)
        {
         Print("Error! Not possible to select least profitable order. Operation cancelled");
         return (0);
        }
      if((OrderSymbol()==Symbol()) && (OrderMagicNumber()==mNumber))
        {
         if(OrderType()==OP_BUY)
           {
            error=(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,Digits),3,clrNONE));
            if(error==1)
              {
               Print("Order closed successfully.");
               Sleep(500);
              }
            else
              {
               Print("Error during Order Close. Repeat operation.");
              }
           }
         //-------------
         if(OrderType()==OP_SELL)
           {
            error=(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,Digits),3,clrNONE));
            if(error==1)
              {
               Print("Order closed successfully.");
               Sleep(500);
              }
            else
              {
               Print("Error during Order Close. Repeat operation.");
              }
           }
        }
     }

   Result=1;
   return (Result);
  }
//+-----------------------------+
//|                                                                  |
//+-----------------------------+
double FindLastOrderParameter(int mNumber,string ParamName)
  {
   int mOrderTicket=0;
   double mOrderPrice=0;
   double mOrderLot=0;
   double mOrderProfit=0;
   int PrevTicket = 0;
   int CurrTicket = 0;

   for(int k=OrdersTotal()-1; k>=0; k--)

      if(OrderSelect(k,SELECT_BY_POS,MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==mNumber)
           {
            CurrTicket=OrderTicket();
            if(CurrTicket>PrevTicket)
              {
               PrevTicket=CurrTicket;
               mOrderPrice=OrderOpenPrice();
               mOrderTicket=OrderTicket();
               mOrderLot=OrderLots();
               mOrderProfit=OrderProfit()+OrderSwap()+OrderCommission();
               LastOrderComment=OrderComment();
               LastOrderOpenTime=OrderOpenTime();
               LastOrderOpenPrice=OrderOpenPrice();
              }
           }

   if(ParamName == "price")
      return(mOrderPrice);
   else
      if(ParamName == "ticket")
         return(mOrderTicket);
      else
         if(ParamName == "lot")
            return(mOrderLot);
         else
            if(ParamName == "profit")
               return(mOrderProfit);

   return (0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPoint()
  {
   double re= 0;
   StepPoint=GetSignal_ATR(999)*StepATRMultiplier;
   double mini=MiniGridDistance *vPoint;
   re=IIFd(StepPoint<mini,mini,StepPoint);//如果间距不足，那么取最小间距。
   return re;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStartLot()
  {
   double earn=(GetTakeProfitPoint()/MarketInfo(Symbol(),MODE_TICKSIZE))*MarketInfo(Symbol(),MODE_TICKVALUE);
   double re=AccountBalance()/500/earn-0.002;
   re=AccountBalance()/500/earn-0.002;

   return(re);
  }
//+-----------------------------+
//|获取下一个订单的下单量
//+-----------------------------+
double getLots(double baseGridNum,double lotMutiple,int magicmunber)
  {
   double re = 0;
   double Lot = GetStartLot();

   int oc=CountOfOrders(magicmunber)+1;

   if(oc>baseGridNum)
     {
      re=Lot*MathPow(lotMutiple,oc-baseGridNum);
     }
   else
     {
      re=Lot;
     }

//第六单的单量和第5单相同
   if(oc>=SameLotsOrder)
     {
      re=Lot*MathPow(lotMutiple,oc-baseGridNum-1);
     }

   re=NormalizeDouble(re,2);
   return re;
  }


//+-----------------------------+
//|新闻用到的几个变量                               |
//+-----------------------------+
datetime LastUpd=0;          //上次更新
int NomNews;             //新闻个数
string NewsArr[4][1000];   //新闻表
//+-----------------------------+
//|                                                                  |
//+-----------------------------+
int CheckNews()
  {
//---
   if(IsTest())
      return 0;
   int re=0;

   if(TimeCurrent()-LastUpd>=6*60*60)//86400
     {
      dump("News Loading...");
      UpdateNews();
      LastUpd=TimeCurrent();
     }
   WindowRedraw();
//---Draw a line on the chart news--------------------------------------------
   for(int i=0; i<NomNews; i++)
      //+-----------------------------+
      //|                                                                  |
      //+-----------------------------+
     {
      string Name=StringSubstr(TimeToStr(TimeNewsFunck(i),TIME_MINUTES)+"_"+NewsArr[1][i]+"_"+NewsArr[3][i],0,63);
      if(NewsArr[3][i]!="")
         if(ObjectFind(Name)==0)
            continue;
      if(StringFind(Symbol(),NewsArr[1][i])<0)
         continue;

      color clrf=clrNONE;
      if(NewsVhigh && StringFind(NewsArr[2][i],"High")>=0)
         clrf=clrRed;
      if(NewsVmedium && StringFind(NewsArr[2][i],"Moderate")>=0)
         clrf=clrBlue;
      if(NewsVlow && StringFind(NewsArr[2][i],"Low")>=0)
         clrf=clrLime;

      if(clrf==clrNONE)
         continue;

      if(NewsArr[3][i]!="")
        {
         ObjectCreate(Name,0,OBJ_VLINE,TimeNewsFunck(i),0);
         ObjectSet(Name,OBJPROP_COLOR,clrf);
         ObjectSet(Name,OBJPROP_STYLE,2);
         ObjectSetInteger(0,Name,OBJPROP_BACK,true);
         ObjectSet(Name,OBJPROP_SELECTABLE,0);
        }
     }
//---------------event Processing------------------------------------
   re=0;
   for(int i=0; i<NomNews; i++)
      //+-----------------------------+
      //|                                                                  |
      //+-----------------------------+
     {
      int power=0;
      if(NewsVhigh && StringFind(NewsArr[2][i],"High")>=0)
         power=1;
      if(NewsVmedium && StringFind(NewsArr[2][i],"Moderate")>=0)
         power=2;
      if(NewsVlow && StringFind(NewsArr[2][i],"Low")>=0)
         power=3;
      if(power==0)
         continue;

      if(TimeCurrent()+BeforeNewsStopMin*60>TimeNewsFunck(i) && TimeCurrent()-AfterNewsStopMin*60<TimeNewsFunck(i) && StringFind(Symbol(),NewsArr[1][i])>=0)
        {
         re=1;
         break;
        }
      else
         re=0;

     }
   return re;
  }
//+-----------------------------+
//////////////////////////////////////////////////////////////////////////////////
// Download CBOE page source code in a text variable
// And returns the result
//////////////////////////////////////////////////////////////////////////////////
string ReadCBOE()
  {

   string cookie=NULL,headers;
   char post[],result[];
   string TXT="";
   int res;
//--- to work with the server, you must add the URL "https://www.google.com/finance"
//--- the list of allowed URL (Main menu-> Tools-> Settings tab "Advisors"):
   string google_url="http://www.renzhe.org/news.php";
//---
   ResetLastError();
//--- download html-pages
   int timeout=50000; //--- timeout less than 1,000 (1 sec.) is insufficient at a low speed of the Internet
   res=WebRequest("GET",google_url,cookie,NULL,timeout,post,0,result,headers);
//--- error checking
   if(res==-1)
     {
      Print("WebRequest error, err.code  =",GetLastError());
      MessageBox("You must add the address ' "+google_url+"' in the list of allowed URL tab 'Advisors' "," Error ",MB_ICONINFORMATION);
      //--- You must add the address ' "+ google url"' in the list of allowed URL tab 'Advisors' "," Error "
     }
   else
     {

      //--- successful download
      PrintFormat("File successfully downloaded, the file size in bytes  =%d.",ArraySize(result));
      //--- save the data in the file
      int filehandle=FileOpen("news-log.html",FILE_WRITE|FILE_BIN);

      if(filehandle!=INVALID_HANDLE)
        {
         //---save the contents of the array result [] in file
         FileWriteArray(filehandle,result,0,ArraySize(result));
         //--- close file
         FileClose(filehandle);

         int filehandle2=FileOpen("news-log.html",FILE_READ|FILE_BIN);
         TXT=FileReadString(filehandle2,ArraySize(result));
         FileClose(filehandle2);
        }
      else
        {
         Print("Error in FileOpen. Error code =",GetLastError());
        }
     }

   return(TXT);
  }
//+-----------------------------+
datetime TimeNewsFunck(int nomf)
  {
   string s=NewsArr[0][nomf];
   string time=StringConcatenate(StringSubstr(s,0,4),".",StringSubstr(s,5,2),".",StringSubstr(s,8,2)," ",StringSubstr(s,11,2),":",StringSubstr(s,14,4));
   return((datetime)(StringToTime(time) + NewsOffset*3600));
  }

////////////////////////////////////////////////////////////////////
//NewsArr[0][NomNews++]    这是时间
//NewsArr[1][NomNews++]    这是货币
//NewsArr[2][NomNews++]    这是级别
//NewsArr[3][NomNews++]    这是标题,或者讲话

////////////////////////////////////////////////////////////////////
void UpdateNews()
  {
   string TEXT=ReadCBOE();
   int sh = StringFind(TEXT,"pageStartAt>")+12;
   int sh2= StringFind(TEXT,"</tbody>");
   TEXT=StringSubstr(TEXT,sh,sh2-sh);

   sh=0;
//+-----------------------------+
//|                                                                  |
//+-----------------------------+
   while(!IsStopped())
     {
      sh = StringFind(TEXT,"event_timestamp",sh)+17;
      sh2= StringFind(TEXT,"onclick",sh)-2;
      if(sh<17 || sh2<0)
         break;
      NewsArr[0][NomNews]=StringSubstr(TEXT,sh,sh2-sh);

      sh = StringFind(TEXT,"flagCur",sh)+10;
      sh2= sh+3;
      if(sh<10 || sh2<3)
         break;
      NewsArr[1][NomNews]=StringSubstr(TEXT,sh,sh2-sh);
      if(StringFind(Symbol(),NewsArr[1][NomNews])<0)
         continue;

      sh = StringFind(TEXT,"title",sh)+7;
      sh2= StringFind(TEXT,"Volatility",sh)-1;
      if(sh<7 || sh2<0)
         break;
      NewsArr[2][NomNews]=StringSubstr(TEXT,sh,sh2-sh);
      if(StringFind(NewsArr[2][NomNews],"High")>=0 && !NewsVhigh)
         continue;
      if(StringFind(NewsArr[2][NomNews],"Moderate")>=0 && !NewsVmedium)
         continue;
      if(StringFind(NewsArr[2][NomNews],"Low")>=0 && !NewsVlow)
         continue;

      sh=StringFind(TEXT,"left event",sh)+12;
      int sh1=StringFind(TEXT,"Speaks",sh);
      sh2=StringFind(TEXT,"<",sh);
      if(sh<12 || sh2<0)
         break;
      if(sh1<0 || sh1>sh2)
         NewsArr[3][NomNews]=StringSubstr(TEXT,sh,sh2-sh);
      else
         NewsArr[3][NomNews]=StringSubstr(TEXT,sh,sh1-sh);

      NomNews++;
      if(NomNews==300)
         break;
     }

  }
//+-----------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Draw(string name,string label,int size,string font,color clr,int x,int y,string tooltip)
  {
//---
//name = INAME+": "+name;
   int windows=0;
//if(AllowSubwindow && WindowsTotal()>1) windows=1;
   ObjectDelete(name);
   ObjectCreate(name,OBJ_LABEL,windows,0,0);
   if(font=="")
      font="Calibri";
   ObjectSetText(name,label,size,font,clr);
   ObjectSet(name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   if(x==0)
      x=15;
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
//--- justify text
   ObjectSet(name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   if(tooltip==NULL)
      tooltip=name+label;
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
   ObjectSet(name,OBJPROP_SELECTABLE,0);
//---
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawInfo()
  {
   double Expectedprofit=0;
   BuySummLot=0;
   TotalProfitBuy=0;
   int tOrders=TotalBuyOrders+TotalSellOrders;

   for(int i=OrdersTotal(); i>=0; i--)
     {
      //
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && (OrderMagicNumber()==MagicNumberBuy))
        {
         BuySummLot+=OrderLots();
         TotalProfitBuy+=OrderProfit();
         //Expectedprofit+=((MathAbs(OrderTakeProfitPoint() - OrderOpenPrice()) / MarketInfo(Symbol(),MODE_TICKSIZE)) * MarketInfo(Symbol(),MODE_TICKVALUE)) * OrderLots();
        }
     }
   SellSummLot=0;
   TotalProfitSell=0;
   for(int i=OrdersTotal(); i>=0; i--)
     {
      //
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol() && (OrderMagicNumber()==MagicNumberSell))
        {
         SellSummLot+=OrderLots();
         TotalProfitSell+=OrderProfit();
         //Expectedprofit += ((MathAbs(OrderTakeProfitPoint() - OrderOpenPrice()) / MarketInfo(Symbol(), MODE_TICKSIZE)) * MarketInfo(Symbol(), MODE_TICKVALUE)) *OrderLots();
        }
     }
   SLot = getLots(BaseGridNum,LotMutiple,MagicNumberSell);
   BLot = getLots(BaseGridNum,LotMutiple,MagicNumberBuy);

   string tmp_offset="MT4 offset: "+Offset(TimeCurrent())+"     Local offset: "+Offset(TimeLocal());

   bool sp=(!CheckSpread(MaxSpreadPoint));
   bool news = (NewsFilter && CheckNews()>0);
   bool time = (TimeFilter && !CheckTimeForTrade(TimeStart,TimeEnd));
   bool boolMaxFilter=GetPositionExistNum(Symbol(),MagicNumberBuy)+GetPositionExistNum(Symbol(),MagicNumberSell)>=MaxSymbolInPosition;
   string MaxFilter=IIFs(boolMaxFilter,"ON","OFF");

   string status=IntegerToString(Bars)+" Bars "+IIFs(sp || news || time || tOrders>=MaxTrades || boolMaxFilter,"Filter","Working");
   string sl=DoubleToStr(AccountBalance()*(-1)*StopLossPercent*0.01,2)+" ("+DoubleToStr(StopLossPercent,0)+"%) ";

   int x1=20;

   Draw("BG","g",350,"Webdings",clrMidnightBlue,-240,-20,"NinjaLoveFishEA");
   Draw("Status","Status : "+status,10,"",IIFc(sp || news || time || tOrders>=MaxTrades || boolMaxFilter,clrOrangeRed,clrGreenYellow),0,10,"");
   Draw("Offset",tmp_offset,10,"",clrWhite,0,10+1*x1,"");
   Draw("=====1","-------Other-------------------------",10,"",clrDarkGray,0,10+2*x1,"");
   Draw("MaxSpread","MaxSpread Filter : "+IIFs(sp,"ON","OFF"),10,"",clrLightPink,0,10+3*x1,"");
   Draw("NewsFilter","NewsFilter : "+IIFs(news,"ON","OFF"),10,"",clrLightPink,0,10+4*x1,"");
   Draw("TimeFilter","TimeFilter : "+IIFs(time,"ON","OFF"),10,"",clrLightPink,0,10+5*x1,"");
   Draw("MaxTrades","MaxTrades : "+IIFs(tOrders>=MaxTrades,"ON ( > "+DoubleToStr(MaxTrades,0)+" )","OFF ( < "+DoubleToStr(MaxTrades,0)+" )"),10,"",clrLightPink,0,10+6*x1,"");
   Draw("MaxSymbolInPosition","MaxSymbolInPosition : "+MaxFilter,10,"",clrLightPink,0,10+7*x1,"");
   Draw("=====2","-------First Order Filters-----------",10,"",clrDarkGray,0,10+8*x1,"");
   Draw("GetStartLot","GetStartLot : "+DoubleToStr(GetStartLot(),2),10,"",clrWhite,0,10+9*x1,"");
   Draw("AutoMode","AutoMode : "+IIFs(AutoMode,"ON","OFF"),10,"",clrWhite,0,10+10*x1,"");
   Draw("=====3","-------Trade Mode--------------------",10,"",clrDarkGray,0,10+11*x1,"");
   Draw("SELL Orders","SELL Orders : "+IntegerToString(TotalSellOrders)+"     lots: "+DoubleToStr(SellSummLot,2),10,"",clrLinen,0,10+12*x1,"");
   Draw("BUY Orders","BUY Orders : "+IntegerToString(TotalBuyOrders)+"     lots : "+DoubleToStr(BuySummLot,2),10,"",clrLinen,0,10+13*x1,"");
//Draw("Expectedprofit","Expected Profit : "+DoubleToStr(Expectedprofit,2)+" ("+DoubleToStr((Expectedprofit)/AccountBalance()*100,3)+"%) ",10,"",clrLinen,0,10+14*x1,"");
   Draw("Expectedprofit","Expected Profit : Null",10,"",clrLinen,0,10+14*x1,"");
   Draw("SL","StopLoss: "+sl,10,"",clrCoral,0,10+15*x1,"");
   Draw("TotalProfit","CurrentProfit : "+DoubleToStr(TotalProfitSell+TotalProfitBuy,2)+" ("+DoubleToStr((TotalProfitSell+TotalProfitBuy)/AccountBalance()*100,3)+"%)",10,"",clrLinen,0,10+16*x1,"");
   Draw("MagicNumber","MagicNumber: "+DoubleToStr(MagicNumberBuy,0),10,"",clrLinen,0,10+17*x1,"");
   Draw("=====4","-------Orders Status-----------------",10,"",clrDarkGray,0,10+18*x1,"");
   Draw("BuildTime","Build "+TimeToStr(__DATETIME__,TIME_DATE)+" "+TimeToStr(__DATETIME__,TIME_MINUTES),10,"",clrGainsboro,0,10+19*x1,"");
   Draw("EAName",EA,14,"",clrWhite,0,10+20*x1,Version);

   double step=GetPointForStep(TotalSellOrders+TotalBuyOrders+1)/Point;
   double mm = IIFd(TotalBuyOrders+TotalSellOrders-1>0,TotalBuyOrders+TotalSellOrders-1,0);

   Comment(
      "\n",
      "GRID PARAMETERS : \n",
      "BaseGridNum : "+IntegerToString(BaseGridNum)+"   ",
      "TakeProfitPoint : "+DoubleToStr(GetTakeProfitPoint()/vPoint,0)+"   ",
      "StepATRMultiplier : "+DoubleToStr(StepATRMultiplier,1)+"   ",
      "StepPoint ≈ "+DoubleToStr(step,0)+"    \n",
      "EnbleTradeByGridSplitHour : "+(string)TimeFilterForTrade(GridSplitSec,MagicNumberSell)+" / "+(string)TimeFilterForTrade(GridSplitSec,MagicNumberBuy)+"    \n\n",
      "GetSignal_RSI : "+DoubleToStr(GetSignal_RSI(PERIOD_M5,RSIperiod),2) +"    \n\n"
      "GetSignal_BB_Width : "+DoubleToStr(GetSignal_BB_Width(PERIOD_H4),2) +"    \n\n"




   );
  }
//+-----------------------------+
