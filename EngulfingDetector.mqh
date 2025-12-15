//+------------------------------------------------------------------+
//|                                          EngulfingDetector.mqh    |
//|                    Gold Engulfing EA - Pattern Detection Logic    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect New Engulfing Pattern on Closed Bar                       |
//| Returns: Setup ID if found, empty string if not                  |
//+------------------------------------------------------------------+
string DetectNewEngulfing() {
   // We check bar 1 (just closed) engulfing bar 2 (previous)
   int engulfingBar = 1;
   int engulfedBar = 2;
   
   // Get times
   datetime engulfingTime = iTime(_Symbol, PERIOD_H1, engulfingBar);
   datetime engulfedTime = iTime(_Symbol, PERIOD_H1, engulfedBar);
   
   // Check if we already have this setup (duplicate prevention)
   bool isBullish = IsBullishCandle(engulfingBar);
   string potentialID = GenerateSetupID(engulfingTime, engulfedTime, isBullish);
   
   if(SetupExists(potentialID)) {
      DebugPrint("Setup already exists: " + potentialID);
      return ""; // Already processed
   }
   
   // Check for bullish engulfing
   if(IsBullishEngulfing(engulfingBar, engulfedBar)) {
      string setupID = GenerateSetupID(engulfingTime, engulfedTime, true);
      
      if(InpEnableTableLogs) {
         Print("========================================================================");
         Print("🟢 BULLISH ENGULFING DETECTED!");
         Print("Setup ID: ", setupID);
         Print("Engulfing Bar Time: ", TimeToString(engulfingTime, TIME_DATE|TIME_MINUTES));
         Print("Engulfed Bar Time: ", TimeToString(engulfedTime, TIME_DATE|TIME_MINUTES));
         Print("========================================================================");
      }
      
      SendAlert("🟢 Bullish Engulfing Detected: " + setupID);
      return setupID;
   }
   
   // Check for bearish engulfing
   if(IsBearishEngulfing(engulfingBar, engulfedBar)) {
      string setupID = GenerateSetupID(engulfingTime, engulfedTime, false);
      
      if(InpEnableTableLogs) {
         Print("========================================================================");
         Print("🔴 BEARISH ENGULFING DETECTED!");
         Print("Setup ID: ", setupID);
         Print("Engulfing Bar Time: ", TimeToString(engulfingTime, TIME_DATE|TIME_MINUTES));
         Print("Engulfed Bar Time: ", TimeToString(engulfedTime, TIME_DATE|TIME_MINUTES));
         Print("========================================================================");
      }
      
      SendAlert("🔴 Bearish Engulfing Detected: " + setupID);
      return setupID;
   }
   
   return ""; // No engulfing found
}

//+------------------------------------------------------------------+
//| Check if Bullish Engulfing Pattern                               |
//| Bar 1 (engulfing) must be bullish and engulf bar 2 (bearish)    |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int engulfingBar, int engulfedBar) {
   // 1. Check directions: engulfing must be bullish, engulfed must be bearish
   if(!IsBullishCandle(engulfingBar)) {
      return false; // Engulfing bar must be bullish
   }
   
   if(!IsBearishCandle(engulfedBar)) {
      return false; // Engulfed bar must be bearish (opposite color)
   }
   
   // 2. Get body boundaries
   double engulfing_high = GetBodyHigh(engulfingBar);
   double engulfing_low = GetBodyLow(engulfingBar);
   double engulfed_high = GetBodyHigh(engulfedBar);
   double engulfed_low = GetBodyLow(engulfedBar);
   
   // 3. Check minimum body size of ENGULFED candle
   double engulfedBodySize = GetBodySizePips(engulfedBar);
   if(engulfedBodySize < InpMinBodySize) {
      DebugPrint(StringFormat("Bullish pattern rejected: Engulfed body too small (%.2f pips < %.2f pips)", 
                              engulfedBodySize, InpMinBodySize));
      return false;
   }
   
   // 4. Check if engulfing body completely engulfs engulfed body (with tolerance)
   if(!IsEngulfingWithTolerance(engulfing_high, engulfing_low, engulfed_high, engulfed_low)) {
      return false;
   }
   
   // All checks passed - valid bullish engulfing!
   DebugPrint(StringFormat("✓ Bullish Engulfing: Bar %d engulfs Bar %d | Body: %.2f pips", 
                          engulfingBar, engulfedBar, engulfedBodySize));
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if Bearish Engulfing Pattern                               |
//| Bar 1 (engulfing) must be bearish and engulf bar 2 (bullish)    |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int engulfingBar, int engulfedBar) {
   // 1. Check directions: engulfing must be bearish, engulfed must be bullish
   if(!IsBearishCandle(engulfingBar)) {
      return false; // Engulfing bar must be bearish
   }
   
   if(!IsBullishCandle(engulfedBar)) {
      return false; // Engulfed bar must be bullish (opposite color)
   }
   
   // 2. Get body boundaries
   double engulfing_high = GetBodyHigh(engulfingBar);
   double engulfing_low = GetBodyLow(engulfingBar);
   double engulfed_high = GetBodyHigh(engulfedBar);
   double engulfed_low = GetBodyLow(engulfedBar);
   
   // 3. Check minimum body size of ENGULFED candle
   double engulfedBodySize = GetBodySizePips(engulfedBar);
   if(engulfedBodySize < InpMinBodySize) {
      DebugPrint(StringFormat("Bearish pattern rejected: Engulfed body too small (%.2f pips < %.2f pips)", 
                              engulfedBodySize, InpMinBodySize));
      return false;
   }
   
   // 4. Check if engulfing body completely engulfs engulfed body (with tolerance)
   if(!IsEngulfingWithTolerance(engulfing_high, engulfing_low, engulfed_high, engulfed_low)) {
      return false;
   }
   
   // All checks passed - valid bearish engulfing!
   DebugPrint(StringFormat("✓ Bearish Engulfing: Bar %d engulfs Bar %d | Body: %.2f pips", 
                          engulfingBar, engulfedBar, engulfedBodySize));
   
   return true;
}

//+------------------------------------------------------------------+
//| Create Setup Object from Detected Pattern                        |
//+------------------------------------------------------------------+
EngulfingSetup CreateSetup(string setupID) {
   EngulfingSetup setup;
   
   // Parse direction from ID (last character)
   int len = StringLen(setupID);
   string dirChar = StringSubstr(setupID, len - 1, 1);
   setup.isBullish = (dirChar == "B");
   
   // Set identity
   setup.setupID = setupID;
   setup.magicNumber = GenerateMagicNumber(setupID);
   
   // Set times
   setup.engulfingTime = iTime(_Symbol, PERIOD_H1, 1);
   setup.engulfedTime = iTime(_Symbol, PERIOD_H1, 2);
   setup.createdTime = TimeCurrent();
   
   // Set price levels (engulfed candle body)
   setup.rangeHigh = GetBodyHigh(2); // Engulfed bar
   setup.rangeLow = GetBodyLow(2);   // Engulfed bar
   
   // Set state
   setup.state = SETUP_UNTAPPED;
   setup.setupComplete = false;
   setup.firstTPHit = false;
   
   // Set line names
   setup.lineHighName = GenerateLineHighName(setupID);
   setup.lineLowName = GenerateLineLowName(setupID);
   
   // Initialize counters
   setup.ordersPlaced = 0;
   setup.ordersExecuted = 0;
   setup.ordersClosed = 0;
   setup.totalProfit = 0;
   setup.tpCount = 0;
   setup.slCount = 0;
   setup.manualCloseCount = 0;
   
   DebugPrint(StringFormat("Setup created: %s | Range: %s - %s | Direction: %s",
                          setupID,
                          FormatPrice(setup.rangeHigh),
                          FormatPrice(setup.rangeLow),
                          setup.isBullish ? "BULLISH" : "BEARISH"));
   
   return setup;
}

//+------------------------------------------------------------------+
//| Check if Setup Already Exists (Duplicate Prevention)             |
//+------------------------------------------------------------------+
bool SetupExists(string setupID) {
   for(int i = 0; i < g_setupCount; i++) {
      if(g_setups[i].setupID == setupID) {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Add Setup to Global Array                                        |
//+------------------------------------------------------------------+
void AddSetup(EngulfingSetup &setup) {
   // Resize array
   ArrayResize(g_setups, g_setupCount + 1);
   
   // Add setup
   g_setups[g_setupCount] = setup;
   g_setupCount++;
   g_totalSetupsCreated++;
   
   DebugPrint(StringFormat("Setup added to array: %s | Total active setups: %d", 
                          setup.setupID, g_setupCount));
}

//+------------------------------------------------------------------+
//| Get Setup Index by ID                                            |
//+------------------------------------------------------------------+
int GetSetupIndexByID(string setupID) {
   for(int i = 0; i < g_setupCount; i++) {
      if(g_setups[i].setupID == setupID) {
         return i;
      }
   }
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Check if Setup Index is Valid                                    |
//+------------------------------------------------------------------+
bool IsValidSetupIndex(int index) {
   return (index >= 0 && index < g_setupCount);
}

//+------------------------------------------------------------------+
//| Remove Setup from Array (for cleanup)                            |
//+------------------------------------------------------------------+
void RemoveSetup(int index) {
   if(index < 0 || index >= g_setupCount) return;
   
   string removedID = g_setups[index].setupID;
   
   // Shift array
   for(int i = index; i < g_setupCount - 1; i++) {
      g_setups[i] = g_setups[i + 1];
   }
   
   // Resize
   g_setupCount--;
   ArrayResize(g_setups, g_setupCount);
   
   DebugPrint("Setup removed from array: " + removedID + " | Remaining: " + IntegerToString(g_setupCount));
}

//+------------------------------------------------------------------+