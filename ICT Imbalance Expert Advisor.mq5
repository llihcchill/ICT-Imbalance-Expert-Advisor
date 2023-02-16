#property version   "1.00"

#define HR0800 28800
#define HR0805 29100
#define HR1300 5880
#define HR1305 6180
#define HR2400 86400
#define SECONDS uint

input string      RISK_MANAGEMENT_SETTINGS;
input double      lot_size;
input int         bars_look_back;
// do you want accumulating of positions on a trade or not
// multiple entries open at once

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

bool isImbalanceShort(bool sa = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   // Store a reference to the first bar
   shortBeginningCandleTime = TimeCurrent();
   
   // Store the high of the first bar
   shortFirstBarLow  = iLow(NULL, 0, 1);
   
   // Store the low of the third bar
   shortThirdBarHigh = iHigh(NULL, 0, 3);
   
   return shortFirstBarLow > shortThirdBarHigh ? sa = true : sa = false;
}

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

bool isImbalanaceShortEntered(bool sb = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   return iClose(NULL, 0, 1) > shortThirdBarLow && iClose(NULL, 0, 3) < shortFirstBarHigh ? sb = true : sb = false;
}

bool isImbalanceLongEntered(bool lb = false) {
   // set the chart to 1 min to get precise entries
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   return iClose(NULL, 0, 1) < longThirdBarLow && iClose(NULL, 0, 3) > longFirstBarHigh ? lb = true : lb = false;
}

void stopOrderAction(int x, double tbl, double fbl, double tbh, double fbh)
{
   printf("at stop order action");
// Place a limit order at the first bar's low
   MqlTradeRequest stopOrderRequest;
   MqlTradeResult  stopOrderResult;

// Make stop order
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
   printf(OrderSend(stopOrderRequest, stopOrderResult));
   OrderSend(stopOrderRequest, stopOrderResult);
}

// Make order ticket for use in cancelling the stop order if it doens't get triggered
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
   printf("out of for loop");
   // Check to make sure there are imbalances, and if not do a different calculation for the same bias thing
   if((longImbalanceStorage == shortImbalanceStorage) || (longImbalanceStorage == 0 && shortImbalanceStorage == 0)) {
      printf("no imbalances l");
      // do the check the first candle of the end of the last session to the one before the session now
      if(iClose(NULL, 0, 12) < iClose(NULL, 0, 1)) {
          longImbalanceStorage = longImbalanceStorage + 1;
      } else if (iClose(NULL, 0, 12) > iClose(NULL, 0, 1)) {
         shortImbalanceStorage = shortImbalanceStorage + 1;
      }
   }
   printf("got past the check for the case of no imbalances or equal");
   if(longImbalanceStorage < shortImbalanceStorage) {
      //see if imbalance has been found and if there is an entry on it
      while(isValidTime(HR0800, HR0805) && isLongEntry == false) {
         printf("is in while loop");
         if(isImbalanceLong() == true && isImbalanceLongEntered() == true) {
            longOrShort = 1;
            stopOrderAction(longOrShort, longThirdBarLow, longFirstBarLow, longThirdBarHigh, longFirstBarHigh);
            isLongEntry = true;
         }
      }
      printf("just out of the while loop");
   } else if(longImbalanceStorage > shortImbalanceStorage) {
      //see if an imbalance has been found and if there is an entry on it
      while(isValidTime(HR0800, HR0805) && isShortEntry == false) {
         printf("is in while loop");
         if(isImbalanceShort() == true && isImbalanaceShortEntered() == true) {
            longOrShort = 2;
            stopOrderAction(longOrShort, shortThirdBarLow, shortFirstBarLow, shortThirdBarHigh, shortFirstBarHigh);
            isShortEntry = true;
         }
         // do stuff when there's an imbalance in the opposite direction
         if(isImbalanceLong(false) == true) {
         // put stop loss at 61% fibonacci level from the first imbalance bar low to the highest high
            //again could counter enter
            isShortEntry = true;
         }
      }
      printf("just out of the while loop");
   }
   // reset these variables
   shortImbalanceStorage = 0;
   longImbalanceStorage = 0;
   londonReset = true;
   newYorkReset = true;
}


// OVERALL STRATEGY //

// strategy number 1:
// at london and new york opening, check whether the first candle has closed upwards or downwards
// log the low of the candle if it closed upwards or the high if it closed downwards
// if (it goes beyond the low/high of the candle move the bias to the opposite direction) {and look for imbalance entry there};
// check if price sweeps the highs/lows of the fractals in the initial direction
// if (two of them get sweeped) {look for imbalance entry};

// strategy i'll use in this one:
// at london opening, get the close of the first candle out of asia and the candle before london open and compare them
// if the candle before london session closes under the close of the asia candle, make a bias for a long
// wait until there is either an imbalance to the downside when london opens, or to the upside, which is when you should look for an
// imbalance entry 

// ONE EXIT STRATEGY
// when it's the end of a trading session, find the low/high of the session and when a candle breaks below it, close the trade when the candle that 
// went past the high/low closes

// TREND CONTINUATION ENTRY
// first look for imbalances between sessions
// if there are lots of downside imbalances, bias is upside
// vice versa if there are lots of upside imbalances, bias is downside
//    if there are no imbalances, take the candle from the end of the previous session and the one before the start of the new session
// once the bias is established, you can just 

// TREND REVERSAL ENTRY

// also develop the other 1hr london session strategy as a varation on this one


void OnInit()
{
   ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
}

void OnTick()
{
   //######################################################################################
   //#### another thing to add is when there's an imbalance in the opposite direction, ####
   //#### if the next candle engulfs the entire imbalance, a trade should be exited    ####
   //######################################################################################
   if(isValidTime(HR0800, HR0805)) {
      if(londonReset == false) {
         printf("u o bri'i'sh people");
         entry();
      }
   }
   
   if(isValidTime(HR1300, HR1305)) {
      if(newYorkReset == false) {
         printf("o no not new york people");
         entry();
      }
   }
   
   if(isLongEntry == true) {
      // remove entry if price doesn't enter it within 6 bars
      if(iBarShift(Symbol(), 0, shortBeginningCandleTime, true) == 6) {
         removeStopOrder();
         isLongEntry = false;
      }
      if(iLow(NULL, 0, 1) > iHigh(NULL, 0, 3)) {
         //put stop loss at 61% fibonacci level from the first imbalance bar high and the lowest low
         printf("went opposite imbalance :(");
         isLongEntry = false;
         // possibly could counter entry? but idk
      }
   }
   
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

void OnDeinit(const int reason)
{
   removeStopOrder();
}
  
  
  
  
  
 /*
      // Check if the first and third bar's low and high don't touch each other
         if(iLow(NULL, 0, 1) > iHigh(NULL, 0, 3)) {
            // Place a buy stop order
            // Reference a bar to detect how long it's been
            datetime BeginningCandleTime = TimeCurrent();

            // Store the low of the first bar
            double LongFirstBarLow = iLow(NULL, 0, 1);
            double LongFirstBarHigh = iHigh(NULL, 0, 1);

            // Store the high and low of the third bar
            double LongThirdBarHigh = iHigh(NULL, 0, 3);
            double LongThirdBarLow = iLow(NULL, 0, 3);

            printf("did the lows and highs thingies chetk");

            // Check if the price goes back in between the first and third bar's low and high
            if(iClose(NULL, 0, 1) > LongFirstBarHigh && iClose(NULL, 0, 1) < LongThirdBarLow) {
               longOrShort = 1;
               //StopOrderAction(longOrShort);

               printf("should have placed order rn");

               // Do an if statement that checks whether price goes below the low or high of the imbalance,
               // and if so cancel the order and set imbalance found to 3
               if(iClose(NULL, 0, 1) <= LongFirstBarLow) {
                  removeStopOrder();
                  printf("should have removed order by now");
               }
                  //ObjectCreate(0, "Stop Order", OBJ_HLINE, 0, 0, LongThirdBarLow);

               // Cancel the order after a number of candles
               if(iBarShift(Symbol(), 0, BeginningCandleTime, true) == 6) {
                  removeStopOrder();
                  printf("should have also removed order by now");
               }
            }
         }
         */

/*
void HighsAndLows()
{
   for(int i = 0; i < bars_look_back; i++) {
      int j = i - 1;
      int h = i + 1;
      bool isBacklookingDone  = false;
      double fractalLeftHigh  = iHigh(NULL, 0, h);
      double fractalLeftLow   = iLow(NULL, 0, h);
      double fractalLeftClose = iClose(NULL, 0, h);
      double fractalLeftOpen  = iOpen(NULL, 0, h);
      
      double fractalMiddleHigh  = iHigh(NULL, 0, i);
      double fractalMiddleLow   = iLow(NULL, 0, i);
      
      double fractalRightHigh  = iHigh(NULL, 0, j);
      double fractalRightLow   = iLow(NULL, 0, j);
      double fractalRightClose = iClose(NULL, 0, j);
      double fractalRightOpen  = iOpen(NULL, 0, j);
      
      if(fractalLeftClose < fractalLeftOpen && fractalRightClose > fractalRightOpen && fractalMiddleLow > fractalLeftClose && fractalRightClose) {
         for(int b = 0; b < bars_look_back; b++) {
            if(iOpen(NULL, 0, b) == fractalMiddleLow) {
               i = i + 1;
            }
         }
         fractalShortStorage[i] = fractalMiddleLow;
      }
      
      if(fractalLeftClose > fractalLeftOpen && fractalRightClose < fractalRightOpen && fractalMiddleHigh > fractalLeftClose && fractalRightClose) {
         for(int a = 0; a < bars_look_back; a++) {
            if(iOpen(NULL, 0, a) == fractalMiddleLow) {
               i = i + 1;
            }
         }
         fractalShortStorage[i] = fractalMiddleLow;
      }
   }
}
*/

      /*
      // Check if the price goes back in between the first and third bar's low and high
      if(iClose(NULL, 0, 1) > ShortThirdBarHigh && iClose(NULL, 0, 1) < ShortFirstBarLow) {
         LongOrShort = 2;
         StopOrderAction(LongOrShort);
         // Do an if statement that checks whether price goes below the low or high of the imbalance,
         // and if so cancel the order and set imbalance found to 3
         
      }*/