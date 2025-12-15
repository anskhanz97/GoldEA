//+------------------------------------------------------------------+
//|                                                       Config.mqh  |
//|                              Gold Engulfing EA - Configuration    |
//+------------------------------------------------------------------+

//=== EA INFORMATION ===
#define EA_NAME     "Gold Engulfing Scalper"
#define EA_VERSION  "2.0"

//=== TRADING PARAMETERS ===
input group "=== Basic Settings ==="
input double InpLotSize = 0.01;                    // Lot Size per Order
input int InpSLPips = 40;                          // Stop Loss (pips) [$4]
input int InpTPPips = 80;                          // Take Profit (pips) [$8]

input group "=== Engulfing Detection ==="
input double InpGapTolerance = 2.0;                // Gap Tolerance (pips)
input double InpMinBodySize = 2.0;                 // Minimum Engulfed Body (pips)

input group "=== Order Distribution ==="
input int InpTopZoneOrders = 3;                    // Top Zone Orders
input int InpMidZoneOrders = 3;                    // Mid Zone Orders
input int InpBottomZoneOrders = 4;                 // Bottom Zone Orders

input group "=== Visual Settings ==="
input color InpUntappedLineColor = clrYellow;      // Untapped Line Color
input color InpTappedLineColor = clrRed;           // Tapped Line Color

input group "=== System Settings ==="
input bool InpEnableTableLogs = true;              // Enable Table Logging
input bool InpEnableAlerts = true;                 // Enable Alerts
input bool InpDebugMode = false;                   // Debug Mode
input int InpLookbackDays = 14;                    // Cleanup Period (days)

//=== SETUP STATES ===
#define SETUP_UNTAPPED   0    // Fresh setup, yellow lines, orders placed
#define SETUP_TAPPED     1    // Price touched range, red lines
#define SETUP_COMPLETE   2    // All orders handled (TP/SL/cancelled)
#define SETUP_EXPIRED    3    // 14+ days old, never tapped

//=== FILE PATHS ===
#define FILE_SETUPS    "GoldEngulfing_setups.json"
#define FILE_BACKUPS   "GoldEngulfing_backups.json"
#define FILE_LOGS      "GoldEngulfing_logs.json"

//=== CONSTANTS ===
#define MAX_LOOKBACK_BARS  336    // 14 days * 24 hours = 336 H1 bars

//=== DATA STRUCTURE ===
struct EngulfingSetup {
   // Identity
   string setupID;               // "Engulf_13122025-1000-B"
   int magicNumber;              // Unique magic number from ID
   
   // Time tracking
   datetime engulfingTime;       // Time of engulfing candle (bar 1)
   datetime engulfedTime;        // Time of engulfed candle (bar 2)
   datetime tappedTime;          // When price tapped the range (0 if untapped)
   datetime createdTime;         // When setup was created
   
   // Price levels
   double rangeHigh;             // Engulfed candle body high
   double rangeLow;              // Engulfed candle body low
   
   // Direction
   bool isBullish;               // true = bullish, false = bearish
   
   // State tracking
   int state;                    // UNTAPPED/TAPPED/COMPLETE/EXPIRED
   bool setupComplete;           // Final state flag
   bool firstTPHit;              // First TP was hit, cancel rest
   
   // Order tracking
   int ordersPlaced;             // How many orders were placed (0-10)
   int ordersExecuted;           // How many got filled (0-10)
   int ordersClosed;             // How many closed (TP/SL/manual)
   
   // Visual elements
   string lineHighName;          // Name of high line object
   string lineLowName;           // Name of low line object
   
   // Performance tracking
   double totalProfit;           // Sum of all closed positions
   int tpCount;                  // Positions closed at TP
   int slCount;                  // Positions closed at SL
   int manualCloseCount;         // Manually closed positions
   
   // Constructor
   EngulfingSetup() {
      setupID = "";
      magicNumber = 0;
      engulfingTime = 0;
      engulfedTime = 0;
      tappedTime = 0;
      createdTime = TimeCurrent();
      rangeHigh = 0;
      rangeLow = 0;
      isBullish = false;
      state = SETUP_UNTAPPED;
      setupComplete = false;
      firstTPHit = false;
      ordersPlaced = 0;
      ordersExecuted = 0;
      ordersClosed = 0;
      lineHighName = "";
      lineLowName = "";
      totalProfit = 0;
      tpCount = 0;
      slCount = 0;
      manualCloseCount = 0;
   }
};

//=== GLOBAL ARRAYS ===
EngulfingSetup g_setups[];          // Active setups in memory
int g_setupCount = 0;               // Number of active setups

//=== TRACKING VARIABLES ===
datetime g_lastBarTime = 0;         // For new bar detection
int g_totalActiveTrades = 0;        // Current active positions count
int g_totalSetupsCreated = 0;       // Lifetime counter
int g_totalSetupsCompleted = 0;     // Completed setups counter
int g_totalSetupsExpired = 0;       // Expired setups counter

//=== ALERT FLAGS ===
bool g_lastEngulfingAlert = false;  // Prevent duplicate alerts

//+------------------------------------------------------------------+
//| Validate Input Parameters                                         |
//+------------------------------------------------------------------+
bool ValidateInputs() {
   if(InpLotSize <= 0) {
      Print("ERROR: Lot size must be positive");
      return false;
   }
   
   if(InpSLPips <= 0 || InpTPPips <= 0) {
      Print("ERROR: SL and TP must be positive");
      return false;
   }
   
   if(InpTPPips <= InpSLPips) {
      Print("WARNING: TP should be greater than SL for 1:2 RR");
      // Continue anyway
   }
   
   if(InpTopZoneOrders + InpMidZoneOrders + InpBottomZoneOrders != 10) {
      Print("ERROR: Total orders must equal 10 (currently: ", 
            InpTopZoneOrders + InpMidZoneOrders + InpBottomZoneOrders, ")");
      return false;
   }
   
   if(InpMinBodySize < 0) {
      Print("ERROR: Minimum body size cannot be negative");
      return false;
   }
   
   // Verify we're on XAUUSD H1
   if(_Symbol != "XAUUSD" && _Symbol != "XAUUSD.") {
      Print("WARNING: This EA is designed for XAUUSD, currently on: ", _Symbol);
   }
   
   if(_Period != PERIOD_H1) {
      Print("WARNING: This EA is designed for H1 timeframe, currently on: ", EnumToString(_Period));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get State Name (for logging)                                     |
//+------------------------------------------------------------------+
string GetStateName(int state) {
   switch(state) {
      case SETUP_UNTAPPED:  return "UNTAPPED";
      case SETUP_TAPPED:    return "TAPPED";
      case SETUP_COMPLETE:  return "COMPLETE";
      case SETUP_EXPIRED:   return "EXPIRED";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+