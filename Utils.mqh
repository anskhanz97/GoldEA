//+------------------------------------------------------------------+
//|                                                        Utils.mqh  |
//|                              Gold Engulfing EA - Utility Functions|
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Pip Value for XAUUSD (0.10 points = 1 pip)                   |
//+------------------------------------------------------------------+
double GetPipValue() { 
   return 0.100; 
}

//+------------------------------------------------------------------+
//| Convert pips to points for XAUUSD                                 |
//+------------------------------------------------------------------+
double PipsToPoints(double pips) {
   return pips * GetPipValue();
}

//+------------------------------------------------------------------+
//| Convert points to pips for XAUUSD                                 |
//+------------------------------------------------------------------+
double PointsToPips(double points) {
   return points / GetPipValue();
}

//+------------------------------------------------------------------+
//| Generate Setup ID from Times                                      |
//| Format: "Engulf_DDMMYYYY-HHMM-D" (D = B/S)                       |
//+------------------------------------------------------------------+
string GenerateSetupID(datetime engulfingTime, datetime engulfedTime, bool isBullish) {
   // Use engulfing candle time as the anchor
   string datePart = TimeToString(engulfingTime, TIME_DATE);     // "2025.12.11"
   string timePart = TimeToString(engulfingTime, TIME_MINUTES);  // "11:00"

   // Reformat date to DDMMYYYY
   string day   = StringSubstr(datePart, 8, 2);
   string month = StringSubstr(datePart, 5, 2);
   string year  = StringSubstr(datePart, 0, 4);

   // Reformat time to HHMM
   string hour   = StringSubstr(timePart, 0, 2);
   string minute = StringSubstr(timePart, 3, 2);

   string dir = isBullish ? "B" : "S";

   return "Engulf_" + day + month + year + "-" + hour + minute + "-" + dir;
}

//+------------------------------------------------------------------+
//| Generate Magic Number from Setup ID                              |
//| Ensures each setup has unique magic number                        |
//+------------------------------------------------------------------+
int GenerateMagicNumber(string setupID) {
   // Extract numeric part from "Engulf_DDMMYYYY-HHMM-D"
   int startPos = 7;  // After "Engulf_"
   int length = 8;    // 8-digit date
   string numStr = StringSubstr(setupID, startPos, length);
   
   // Convert to integer hash
   int hash = 0;
   for(int i = 0; i < StringLen(numStr); i++) {
      hash = hash * 31 + StringGetCharacter(numStr, i);
   }
   
   // Ensure positive number and within valid range
   return MathAbs(hash % 1000000);
}

//+------------------------------------------------------------------+
//| Generate Line Object Names from Setup ID                         |
//+------------------------------------------------------------------+
string GenerateLineHighName(string setupID) {
   return setupID + "_High";
}

string GenerateLineLowName(string setupID) {
   return setupID + "_Low";
}

//+------------------------------------------------------------------+
//| Check if New Bar Formed                                           |
//+------------------------------------------------------------------+
bool IsNewBar() {
   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   
   if(currentBarTime != g_lastBarTime) {
      g_lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Candle Body Size in Pips                                      |
//+------------------------------------------------------------------+
double GetBodySizePips(int bar) {
   double open = iOpen(_Symbol, PERIOD_H1, bar);
   double close = iClose(_Symbol, PERIOD_H1, bar);
   double bodySizePoints = MathAbs(close - open);
   return PointsToPips(bodySizePoints);
}

//+------------------------------------------------------------------+
//| Get Candle Body High (max of open/close)                         |
//+------------------------------------------------------------------+
double GetBodyHigh(int bar) {
   double open = iOpen(_Symbol, PERIOD_H1, bar);
   double close = iClose(_Symbol, PERIOD_H1, bar);
   return MathMax(open, close);
}

//+------------------------------------------------------------------+
//| Get Candle Body Low (min of open/close)                          |
//+------------------------------------------------------------------+
double GetBodyLow(int bar) {
   double open = iOpen(_Symbol, PERIOD_H1, bar);
   double close = iClose(_Symbol, PERIOD_H1, bar);
   return MathMin(open, close);
}

//+------------------------------------------------------------------+
//| Check if Candle is Bullish                                        |
//+------------------------------------------------------------------+
bool IsBullishCandle(int bar) {
   return iClose(_Symbol, PERIOD_H1, bar) > iOpen(_Symbol, PERIOD_H1, bar);
}

//+------------------------------------------------------------------+
//| Check if Candle is Bearish                                        |
//+------------------------------------------------------------------+
bool IsBearishCandle(int bar) {
   return iClose(_Symbol, PERIOD_H1, bar) < iOpen(_Symbol, PERIOD_H1, bar);
}

//+------------------------------------------------------------------+
//| Check if Engulfing with Gap Tolerance                            |
//+------------------------------------------------------------------+
bool IsEngulfingWithTolerance(double engulfing_high, double engulfing_low,
                              double engulfed_high, double engulfed_low) {
   
   double pipValue = GetPipValue();
   double tolerance = InpGapTolerance * pipValue; // Convert pips to points
   
   bool highCheck = (engulfing_high >= engulfed_high - tolerance);
   bool lowCheck  = (engulfing_low  <= engulfed_low  + tolerance);
   
   return (highCheck && lowCheck);
}

//+------------------------------------------------------------------+
//| Check if Order Exists at Specific Price with Setup ID            |
//+------------------------------------------------------------------+
bool OrderExistsAtPrice(double price, string setupID) {
   price = NormalizeDouble(price, _Digits);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetString(ORDER_COMMENT) != setupID) continue;
      
      double orderPrice = NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN), _Digits);
      if(orderPrice == price) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Count Pending Orders for Setup                                   |
//+------------------------------------------------------------------+
int CountPendingOrders(string setupID) {
   int count = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
         OrderGetString(ORDER_COMMENT) == setupID) {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Count Executed Positions for Setup                               |
//+------------------------------------------------------------------+
int CountExecutedPositions(string setupID, int magicNumber) {
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magicNumber) {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Send Alert (if enabled)                                          |
//+------------------------------------------------------------------+
void SendAlert(string message) {
   if(!InpEnableAlerts) return;
   
   Alert(message);
}

//+------------------------------------------------------------------+
//| Debug Print (only if debug mode enabled)                         |
//+------------------------------------------------------------------+
void DebugPrint(string message) {
   if(!InpDebugMode) return;
   
   Print("[DEBUG] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " | ", message);
}

//+------------------------------------------------------------------+
//| Error Description Helper                                          |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode) {
   switch(errorCode) {
      case 0:     return "No error";
      case 1:     return "No error, but result is unknown";
      case 2:     return "Common error";
      case 3:     return "Invalid trade parameters";
      case 4:     return "Trade server is busy";
      case 5:     return "Old version of client terminal";
      case 6:     return "No connection with trade server";
      case 7:     return "Not enough rights";
      case 8:     return "Too frequent requests";
      case 9:     return "Malfunctional trade operation";
      case 64:    return "Account disabled";
      case 65:    return "Invalid account";
      case 128:   return "Trade timeout";
      case 129:   return "Invalid price";
      case 130:   return "Invalid stops";
      case 131:   return "Invalid trade volume";
      case 132:   return "Market is closed";
      case 133:   return "Trade is disabled";
      case 134:   return "Not enough money";
      case 135:   return "Price changed";
      case 136:   return "Off quotes";
      case 137:   return "Broker is busy";
      case 138:   return "Requote";
      case 139:   return "Order is locked";
      case 140:   return "Long positions only allowed";
      case 141:   return "Too many requests";
      case 145:   return "Modification denied because order too close to market";
      case 146:   return "Trade context is busy";
      case 147:   return "Expirations are denied by broker";
      case 148:   return "Amount of open and pending orders has reached the limit";
      default:    return "Unknown error: " + IntegerToString(errorCode);
   }
}

//+------------------------------------------------------------------+
//| Check if Price is Within Range                                   |
//+------------------------------------------------------------------+
bool IsPriceInRange(double price, double rangeHigh, double rangeLow) {
   return (price >= rangeLow && price <= rangeHigh);
}

//+------------------------------------------------------------------+
//| Calculate Days Between Two Times                                 |
//+------------------------------------------------------------------+
int DaysBetween(datetime time1, datetime time2) {
   return (int)((time2 - time1) / 86400); // 86400 seconds in a day
}

//+------------------------------------------------------------------+
//| Format Price for Display                                         |
//+------------------------------------------------------------------+
string FormatPrice(double price) {
   return DoubleToString(price, _Digits);
}

//+------------------------------------------------------------------+
//| Format Time for Display                                          |
//+------------------------------------------------------------------+
string FormatTime(datetime time) {
   return TimeToString(time, TIME_DATE|TIME_MINUTES);
}

//+------------------------------------------------------------------+