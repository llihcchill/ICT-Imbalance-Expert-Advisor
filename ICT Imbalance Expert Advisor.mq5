#property version   "1.00"

#define HR0800 28800
#define HR0805 29100
#define HR1300 5880
#define HR1305 6180
#define HR2400 86400
#define SECONDS uint

// settings
input string      RISK_MANAGEMENT_SETTINGS;
input double      lot_size;
input int         bars_look_back;

// global variables
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

void stopOrderAction(int x, double tbl, double fbl, double tbh, double fbh)
{
   printf("at stop order action");
   // place a limit order at the first bar's low
   MqlTradeRequest stopOrderRequest;
   MqlTradeResult  stopOrderResult;

   ulong OrderTicket             = OrderGetTicket(1);
   stopOrderRequest.symbol       = Symbol();
   stopOrderRequest.order        = OrderTicket;
   stopOrderRequest.volume       = lot_size;
   stopOrderRequest.deviation    = 2;
   stopOrderRequest.action       = TRADE_ACTION_PENDING;
   stopOrderRequest.type_filling = ENUM_ORDER_TYPE_FILLING::ORDER_FILLING_FOK;

   if(x == 1) {
      printf("long");
      stopOrderRequest.price  = tbl;
      stopOrderRequest.type   = ORDER_TYPE_BUY_STOP;
      stopOrderRequest.sl     = fbl + 5 * Point();
   } else if(x == 2) {
      printf("short");
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
   ulong OrderTicket = OrderGetTicket(1);
   removeOrderRequest.action = TRADE_ACTION_REMOVE;
   removeOrderRequest.order = OrderTicket;

   OrderSend(removeOrderRequest, removeOrderResult);
}

void entry()
{
   // go through each candle and see if there is an imbalance
   for(int i = 12; i > 3; i--) {
      int k = i - 2;
      if(iHigh(NULL, 0, i) < iLow(NULL, 0, k)) {
         longImbalanceStorage = longImbalanceStorage + 1;
      } else if(iLow(NULL, 0, i) > iHigh(NULL, 0, k)) {
         shortImbalanceStorage = shortImbalanceStorage + 1;
      }
   }
   
   // check to make sure there are imbalances, and if not do a different calculation for the same bias thing
   if((longImbalanceStorage == shortImbalanceStorage) || (longImbalanceStorage == 0 && shortImbalanceStorage == 0)) {
      // do the check the first candle of the end of the last session to the one before the session now
      if(iClose(NULL, 0, 12) < iClose(NULL, 0, 1)) {
          longImbalanceStorage = longImbalanceStorage + 1;
      } else if (iClose(NULL, 0, 12) > iClose(NULL, 0, 1)) {
         shortImbalanceStorage = shortImbalanceStorage + 1;
      }
   }
   
   // see if more short imbalances have been found and then find an entry in the opposite direction
   if(longImbalanceStorage < shortImbalanceStorage) {
      while(isValidTime(HR0800, HR0805) && isLongEntry == false) {
         if(isImbalanceLong() == true && isImbalanceLongEntered() == true) {
            longOrShort = 1;
            stopOrderAction(longOrShort, longThirdBarLow, longFirstBarLow, longThirdBarHigh, longFirstBarHigh);
            isLongEntry = true;
         }
      }
   } else if(longImbalanceStorage > shortImbalanceStorage) {
      // see if more long imbalances have been found and then find an entry in the opposite direction
      while(isValidTime(HR0800, HR0805) && isShortEntry == false) {
         if(isImbalanceShort() == true && isImbalanaceShortEntered() == true) {
            longOrShort = 2;
            stopOrderAction(longOrShort, shortThirdBarLow, shortFirstBarLow, shortThirdBarHigh, shortFirstBarHigh);
            isShortEntry = true;
         }
      }
   }
   // reset these variables
   shortImbalanceStorage = 0;
   longImbalanceStorage = 0;
   londonReset = true;
   newYorkReset = true;
}

void OnInit()
{
   // sets the timeframe to the 5 minute
   ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
}

void OnTick()
{
   // when it approcahes london session, it can start to find an entry
   if(isValidTime(HR0800, HR0805)) {
      if(londonReset == false) {
         entry();
         newYorkReset = false;
      }
   }
   
   // when it approaches new york session, it can start to find an entry
   if(isValidTime(HR1300, HR1305)) {
      if(newYorkReset == false) {
         entry();
         londonReset = false;
      }
   }
   
   // finds when a long trade has been opened and it manages stop loss and what to do if prices reverse
   if(isLongEntry == true) {
      // remove entry if price doesn't enter it within 6 bars
      if(iBarShift(Symbol(), 0, shortBeginningCandleTime, true) == 6) {
         removeStopOrder();
         isLongEntry = false;
      }
      if(iLow(NULL, 0, 1) > iHigh(NULL, 0, 3)) {
         printf("went opposite imbalance :(");
         isLongEntry = false;
      }
   }
   
   // finds when a short trade has been opened and it manages stop loss and what to do if prices reverse
   if(isShortEntry == true) {
      if(iBarShift(Symbol(), 0, shortBeginningCandleTime, true) == 6) {
         removeStopOrder();
         isShortEntry = false;
      }
      if(iHigh(NULL, 0, 1) < iLow(NULL, 0, 3)) {
         isShortEntry = false;
      }
   }
}

// remove stop order just in case, should probably also close the position as well
void OnDeinit(const int reason)
{
   removeStopOrder();
}
