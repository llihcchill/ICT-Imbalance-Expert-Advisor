#property version   "1.20";
#include <Trade\PositionInfo.mqh>;
#include <Trade\Trade.mqh>;
CPositionInfo  position;
CTrade         ctrade;

#define HR0800 28800
#define HR0830 30600
#define HR1300 46800
#define HR1330 48600
#define HR1900 68400
#define HR2400 86400
#define SECONDS uint

// settings
input string      RISK_MANAGEMENT_SETTINGS;
input double      lot_size;
input int         bars_look_back;
input bool        one_trade_per_session;

// global variables
ulong orderTicket = OrderGetTicket(1);

double shortFirstBarLow;
double shortFirstBarHigh;
double shortThirdBarHigh;
double shortThirdBarLow;

double longFirstBarLow;
double longFirstBarHigh;
double longThirdBarHigh;
double longThirdBarLow;

bool isShortEntry    = false;
bool isLongEntry     = false;
bool londonReset     = false;
bool newYorkReset    = false;
bool longReEntry     = false;
bool shortReEntry    = false;
int longImbalanceStorage;
int shortImbalanceStorage;
int longOrShort = 3;

datetime shortBeginningCandleTime;
datetime longBeginningCandleTime;

// returns the time in GMT in seconds
SECONDS time(datetime when = 0) {
   return SECONDS(when == 0 ? TimeCurrent() : when) % HR2400;
}
datetime date(datetime when = 0) {
   return datetime((when == 0 ? TimeCurrent() : when) - time(when));
}
bool isValidTime(SECONDS start, SECONDS end, datetime when = 0) {
   SECONDS now = time(when);
   return start < end ? start <= now && now < end : !isValidTime(end, start, when);
}

// returns true if it finds a short imbalance
bool isImbalanceShort(bool sa = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   
   // store a reference to the first bar
   shortBeginningCandleTime = TimeCurrent();
   
   // store the high of the first bar
   shortFirstBarLow  = iLow(NULL, 0, 1);
   shortFirstBarHigh = iHigh(NULL, 0, 1);
   
   // store the low of the third bar
   shortThirdBarHigh = iHigh(NULL, 0, 3);
   
   return shortFirstBarLow > shortThirdBarHigh ? sa = true : sa = false;
}

// returns true if it finds a long imbalance
bool isImbalanceLong(bool la = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   
   // store a reference to the first candle
   longBeginningCandleTime = TimeCurrent();
   
   // store the high of the first bar
   longFirstBarHigh  = iHigh(NULL, 0, 1);
   
   // store the low of the third bar
   longThirdBarLow   = iLow(NULL, 0, 3);
   
   return longFirstBarHigh < longThirdBarLow ? la = true : la = false;
}

// returns true or false if the short imbalance has been entered
bool isImbalanaceShortEntered(bool sb = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   return iClose(NULL, 0, 1) > shortThirdBarLow && iClose(NULL, 0, 3) < shortFirstBarHigh ? sb = true : sb = false;
}

// returns true or false is the long imbalance has been entered
bool isImbalanceLongEntered(bool lb = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   return iClose(NULL, 0, 1) < longThirdBarLow && iClose(NULL, 0, 3) > longFirstBarHigh ? lb = true : lb = false;
}

// returns true if there is a long imbalance (for use in a for loop)
bool initialLongImbalance(bool ik = false, int firstInt = 1, int secondInt = 1) {
   return iHigh(NULL, 0, firstInt) < iLow(NULL, 0, secondInt) ? ik = true : ik = false;
}

// returns true if there is a short imbalance (for use in a for loop)
bool initialShortImbalance(bool on = false, int firstInt = 1, int secondInt = 1) {
   return iLow(NULL, 0, firstInt) > iHigh(NULL, 0, secondInt) ? on = true : on = false;
}

// as there are no imbalances, it checks the close of the first candle of the more recently closed session to the first of the new one
bool alternateStrategyShort(bool ass = false) {
   return iClose(NULL, 0, 12) > iClose(NULL, 0, 1) ? ass = true : ass = false;
}

// as there are no imbalances, it check the close of the first candle of the more recently closed session to the first of the new one
bool alternateStrategyLong(bool asl = false) {
   return iClose(NULL, 0, 12) < iClose(NULL, 0, 1) ? asl = true : asl = false;
}

// creates a stop order
void stopOrderAction(int x, double tbl, double fbl, double tbh, double fbh)
{
   // place a limit order at the first bar's low
   MqlTradeRequest stopOrderRequest;
   MqlTradeResult  stopOrderResult;

   stopOrderRequest.symbol       = Symbol();
   stopOrderRequest.order        = orderTicket;
   stopOrderRequest.volume       = lot_size;
   stopOrderRequest.deviation    = 2;
   stopOrderRequest.action       = TRADE_ACTION_PENDING;
   stopOrderRequest.type_filling = ENUM_ORDER_TYPE_FILLING::ORDER_FILLING_FOK;

   if(x == 1) {
      stopOrderRequest.price  = tbl;
      stopOrderRequest.type   = ORDER_TYPE_BUY_STOP;
      stopOrderRequest.sl     = fbl + 5 * Point();
   }
   if(x == 2) {
      stopOrderRequest.price  = tbh;
      stopOrderRequest.type   = ORDER_TYPE_SELL_STOP;
      stopOrderRequest.sl     = fbh + 5 * Point();
   }
   // send the order with the inputs above
   OrderSend(stopOrderRequest, stopOrderResult);
}

// makes order ticket for use in cancelling the stop order if it doesn't get triggered
void removeStopOrder()
{
   MqlTradeRequest removeOrderRequest;
   MqlTradeResult removeOrderResult;

   removeOrderRequest.action = TRADE_ACTION_REMOVE;
   removeOrderRequest.order = orderTicket;

   OrderSend(removeOrderRequest, removeOrderResult);
}

// this function closes the current position
void closePosition()
{
   if(position.Symbol()==Symbol()) {
      ctrade.PositionClose(position.Ticket());
   }
}

// this function finds the entry for both New York and London trades
void entry() 
{
   // go through each candle and see if there is an imbalance
   for(int i = 12; i > 3; i--) {
      int k = i - 2;
      if(initialLongImbalance(false, i, k) == true) {
         longImbalanceStorage = longImbalanceStorage + 1;
      } else if(initialShortImbalance(false, i, k) == true) {
         shortImbalanceStorage = shortImbalanceStorage + 1;
      }
   }
   
   // check to make sure there are imbalances, and if not do a different calculation for the same bias thing
   if((longImbalanceStorage == shortImbalanceStorage) || (longImbalanceStorage == 0 && shortImbalanceStorage == 0)) {
      // do the check the first candle of the end of the last session to the one before the session now
      if(alternateStrategyLong() == true) {
          longImbalanceStorage = longImbalanceStorage + 1;
      } else if (alternateStrategyShort() == true) {
         shortImbalanceStorage = shortImbalanceStorage + 1;
      }
   }
   
   // see if more short imbalances have been found and then find an entry in the opposite direction
   if(longImbalanceStorage < shortImbalanceStorage) {
      ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
      while(isValidTime(HR0800, HR0830) && isLongEntry == false) {
         if(isImbalanceLong() == true && isImbalanceLongEntered() == true) {
            printf("got an entry");
            longOrShort = 1;
            stopOrderAction(longOrShort, longThirdBarLow, longFirstBarLow, longThirdBarHigh, longFirstBarHigh);
            isLongEntry = true;
         }
      }
   } else if(longImbalanceStorage > shortImbalanceStorage) {
      ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
      // see if more long imbalances have been found and then find an entry in the opposite direction
      while(isValidTime(HR0800, HR0830) && isShortEntry == false) {
         if(isImbalanceShort() == true && isImbalanaceShortEntered() == true) {
            printf("got an entry");
            longOrShort = 2;
            stopOrderAction(longOrShort, shortThirdBarLow, shortFirstBarLow, shortThirdBarHigh, shortFirstBarHigh);
            isShortEntry = true;
         }
      }
   }
   printf("reset variables");
   // reset these variables
   shortImbalanceStorage = 0;
   longImbalanceStorage = 0;
   londonReset = true;
   newYorkReset = true;
}


void reEntryLong() 
{
   printf("if long entry");
   // remove entry if price doesn't enter it within 6 bars
   if(iBarShift(Symbol(), 0, longBeginningCandleTime, true) == 6) {
      printf("cancelled order after time");
      removeStopOrder();
      isLongEntry = false;
   }
   if(iLow(NULL, 0, 1) > iHigh(NULL, 0, 3)) {
      printf("went opposite direction");
      closePosition();
      if(one_trade_per_session == false) {
         if(isImbalanceShort() == true && isImbalanaceShortEntered() == true) {
            longBeginningCandleTime = TimeCurrent();
            longOrShort = 2;
            stopOrderAction(longOrShort, shortThirdBarLow, shortFirstBarLow, shortThirdBarHigh, shortFirstBarLow);
            longReEntry = true;
         }
      } else {
         isLongEntry = false;
      }
   }
}

void reEntryShort() 
{
   printf("if short entry");
   if(iBarShift(Symbol(), 0, shortBeginningCandleTime, true) == 6) {
      removeStopOrder();
      isShortEntry = false;
   }
   // finds an imbalance in the opposing direction
   if(iHigh(NULL, 0, 1) < iLow(NULL, 0, 3)) {
      closePosition();
      if(one_trade_per_session == false) {
         if(isImbalanceLong() == true && isImbalanceLongEntered() == true) {
            shortBeginningCandleTime = TimeCurrent();
            longOrShort = 1;
            stopOrderAction(longOrShort, shortThirdBarLow, shortFirstBarLow, shortThirdBarHigh, shortFirstBarLow);
            shortReEntry = true;
         }
      } else {
         isShortEntry = false;
      }
   }
}

void OnInit()
{
   // sets the timeframe to the 5 minute
   ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
}

void OnTick()
{
   // when it approcahes london session, it can start to find an entry
   if(isValidTime(HR0800, HR0830) && londonReset == false) {
      closePosition();
      entry();
      newYorkReset = false;
   }
   
   // when it approaches new york session, it can start to find an entry
   if(isValidTime(HR1300, HR1330) && newYorkReset == false) {
      printf("in new york session");
      closePosition();
      entry();
      londonReset = false;
   }
   
   // finds when a long trade has been opened in the London session and it manages stop loss and what to do if prices reverse
   if(isLongEntry == true && isValidTime(HR0800, HR1300)) {
      reEntryLong();
      if(longReEntry == true) {
         if(iBarShift(Symbol(), 0, longBeginningCandleTime, true) == 6) {
            removeStopOrder();
            isLongEntry = false;
         }
      }
      ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
      // finds an imbalance in the opposing direction
      if(iLow(NULL, 0, 1) > iHigh(NULL, 0, 3)) {
         closePosition();
         longReEntry = false;
      }
   }
   
   // finds when a long trade has been opened in the New York session and it manages stop loss and what to do if prices reverse
   if(isLongEntry == true && isValidTime(HR1300, HR1900)) {
      reEntryLong();
      if(longReEntry == true) {
         if(iBarShift(Symbol(), 0, longBeginningCandleTime, true) == 6) {
            removeStopOrder();
            isLongEntry = false;
         }
      }
      ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
      // finds an imbalance in the opposing direction
      if(iLow(NULL, 0, 1) > iHigh(NULL, 0, 3)) {
         closePosition();
         longReEntry = false;
      }
   }
   
   // finds when a short trade in London session has been opened and it manages stop loss and what to do if prices reverse
   if(isShortEntry == true && isValidTime(HR0800, HR1300)) {
      reEntryShort();
      if(shortReEntry == true) {
         if(iBarShift(Symbol(), 0, shortBeginningCandleTime, true) == 6) {
            removeStopOrder();
            isShortEntry = false;
         }
      }
      // finds an imbalance in the opposing direction
      if(iHigh(NULL, 0, 1) < iLow(NULL, 0, 3)) {
         closePosition();
         shortReEntry = false;
      }
   }
   // finds when a short trade in New York session has been opened and it manages stop loss and what to do if prices reverse
   if(isShortEntry == true && isValidTime(HR1300, HR1900)) {
      reEntryShort();
      if(shortReEntry == true) {
         if(iBarShift(Symbol(), 0, shortBeginningCandleTime, true) == 6) {
            removeStopOrder();
            isShortEntry = false;
         }
      }
      // finds an imbalance in the opposing direction
      if(iHigh(NULL, 0, 1) < iLow(NULL, 0, 3)) {
         closePosition();
         shortReEntry = false;
      }
   }
}

// remove stop order and any open postions just in case
void OnDeinit(const int reason)
{
   removeStopOrder();
   closePosition();
}
