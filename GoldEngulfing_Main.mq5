//+------------------------------------------------------------------+
//|                                           GoldEngulfing_Main.mq5 |
//|                                  Gold Engulfing Scalping EA      |
//|                                                    Version 2.0    |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      ""
#property version   "2.00"
#property description "Gold Engulfing Pattern Scalper"
#property description "H1 Timeframe | XAUUSD Only"
#property description "10 Limit Orders per Setup | 1:2 RR"

//--- Include all modules (ORDER MATTERS!)
#include "Include/Config.mqh"
#include "Include/Utils.mqh"
#include "Include/EngulfingDetector.mqh"
#include "Include/VisualManager.mqh"
#include "Include/OrderManager.mqh"
#include "Include/SetupManager.mqh"
#include "Include/StorageSystem.mqh"
#include "Include/TableLogger.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("========================================================================");
   Print("          GOLD ENGULFING EA v2.0 - INITIALIZATION STARTED");
   Print("========================================================================");
   
   //--- Validate inputs
   if(!ValidateInputs()) {
      Print("❌ Input validation failed!");
      return INIT_PARAMETERS_INCORRECT;
   }
   Print("✅ Input parameters validated");
   
   //--- Check symbol and timeframe
   if(_Symbol != "XAUUSD" && _Symbol != "XAUUSD.") {
      Print("⚠️  WARNING: EA designed for XAUUSD, currently on: ", _Symbol);
   }
   
   if(_Period != PERIOD_H1) {
      Print("⚠️  WARNING: EA designed for H1, currently on: ", EnumToString(_Period));
   }
   
   //--- Initialize storage system
   if(!InitializeStorage()) {
      Print("❌ Storage system initialization failed!");
      return INIT_FAILED;
   }
   Print("✅ Storage system initialized");
   
   //--- Load setups from file (restore state)
   if(!LoadSetupsFromFile()) {
      Print("⚠️  Failed to load setups from file - continuing with fresh state");
   } else {
      if(g_setupCount > 0) {
         Print("✅ Loaded ", g_setupCount, " setups from storage");
         
         // Restore visual lines for loaded setups
         RestoreVisualLines();
         Print("✅ Visual lines restored");
      } else {
         Print("📝 No previous setups found - starting fresh");
      }
   }
   
   //--- Detect new engulfing pattern
   string setupID = DetectNewEngulfing();
   
   if(setupID != "") {
      //--- New engulfing pattern found!
      ProcessNewSetup(setupID);
      
      //--- Save state immediately
      SaveSetupsToFile();
      
      //--- Display updated summary
      DisplayCompactSummary();
      DisplayActiveSetups();
   }
   
   //--- Optional: Display full candle table (can be heavy, use sparingly)
   // Uncomment if you want full 336-candle analysis on each bar
      DisplayCandleTable();
   //--- Initialize last bar time
   g_lastBarTime = iTime(_Symbol, PERIOD_H1, 0);
   
   //--- Set timer (every 5 seconds for quick checks)
   EventSetTimer(5);
   Print("✅ Timer initialized (5 seconds)");
   
   //--- Display initial summary
   PrintSetupSummary();
   DisplayCompactSummary();
   
   //--- Print storage info
   PrintStorageInfo();
   
   Print("========================================================================");
   Print("          ✅ GOLD ENGULFING EA INITIALIZED SUCCESSFULLY");
   Print("========================================================================");
   Print("⏰ Waiting for next H1 bar to scan for engulfing patterns...");
   Print("📊 Current Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("========================================================================");
   Print("          GOLD ENGULFING EA - SHUTDOWN INITIATED");
   Print("========================================================================");
   Print("Shutdown Reason: ", reason);
   
   //--- Save all setups to file
   if(!SaveSetupsToFile()) {
      Print("⚠️  WARNING: Failed to save setups to file!");
   } else {
      Print("✅ Setups saved to file successfully");
   }
   
   //--- Display final statistics
   DisplayTradingStatistics();
   PrintSetupSummary();
   
   //--- Kill timer
   EventKillTimer();
   
   //--- Log shutdown
   WriteLog("EA shutdown - Reason: " + IntegerToString(reason));
   
   Print("========================================================================");
   Print("          GOLD ENGULFING EA SHUTDOWN COMPLETE");
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Check for new bar (H1)
   if(IsNewBar()) {
      OnNewBar();
   }
   
   //--- Monitor UNTAPPED setups (check if price tapped range)
   CheckUntappedSetups();
   
   //--- Check for manual closes (quick detection)
   CheckManualCloses();
}

//+------------------------------------------------------------------+
//| Timer function (every 5 seconds)                                  |
//+------------------------------------------------------------------+
void OnTimer() {
   //--- Update all untapped lines (extend to current time)
   UpdateAllUntappedLines();
   
   //--- Check TAPPED setups (monitor for TP hits, order status)
   CheckTappedSetups();
   
   //--- Check for expired setups (14+ days old)
   CheckExpiredSetups();
   
   //--- Cleanup completed/expired setups from memory
   CleanupCompletedSetups();
   
   //--- Validate data integrity (every timer tick)
   if(!ValidateSetupIntegrity()) {
      Print("⚠️  WARNING: Setup data integrity check failed!");
   }
   
   //--- Periodic save (every 12 timer ticks = 1 minute)
   static int timerCount = 0;
   timerCount++;
   if(timerCount >= 12) {
      SaveSetupsToFile();
      timerCount = 0;
   }
}

//+------------------------------------------------------------------+
//| New Bar Event Handler                                             |
//+------------------------------------------------------------------+
void OnNewBar() {
   //--- Log new bar
   LogNewBarAlert();
   
   //--- Send alert if enabled
   if(InpEnableAlerts) {
      SendAlert("⏰ New H1 Bar: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   }
   
   //--- Detect new engulfing pattern
   string setupID = DetectNewEngulfing();
   
   if(setupID != "") {
      //--- New engulfing pattern found!
      ProcessNewSetup(setupID);
      
      //--- Save state immediately
      SaveSetupsToFile();
      
      //--- Display updated summary
      DisplayCompactSummary();
      DisplayActiveSetups();
   }
   
   //--- Optional: Display full candle table (can be heavy, use sparingly)
   // Uncomment if you want full 336-candle analysis on each bar
      DisplayCandleTable();
}

//+------------------------------------------------------------------+
//| Chart Event Handler (for manual interaction)                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
   //--- Handle keyboard shortcuts
   if(id == CHARTEVENT_KEYDOWN) {
      switch((int)lparam) {
         case 'S': // Press 'S' to display summary
            PrintSetupSummary();
            DisplayCompactSummary();
            break;
            
         case 'A': // Press 'A' to display active setups
            DisplayActiveSetups();
            break;
            
         case 'T': // Press 'T' to display full table
            DisplayCandleTable();
            break;
            
         case 'R': // Press 'R' to display recent engulfing
            DisplayRecentEngulfing();
            break;
            
         case 'P': // Press 'P' to display statistics
            DisplayTradingStatistics();
            break;
            
         case 'I': // Press 'I' to display storage info
            PrintStorageInfo();
            break;
            
         case 'L': // Press 'L' to save to file immediately
            if(SaveSetupsToFile()) {
               Print("💾 Manual save completed successfully");
            }
            break;
            
         case 'C': // Press 'C' to cleanup completed setups
            CleanupCompletedSetups();
            Print("🧹 Cleanup completed");
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Print Keyboard Shortcuts (Call manually if needed)       |
//+------------------------------------------------------------------+
void PrintKeyboardShortcuts() {
   Print("========================================================================");
   Print("                    KEYBOARD SHORTCUTS");
   Print("========================================================================");
   Print("S - Display Summary");
   Print("A - Display Active Setups");
   Print("T - Display Full Table (336 candles)");
   Print("R - Display Recent Engulfing");
   Print("P - Display Trading Statistics");
   Print("I - Display Storage Info");
   Print("L - Manual Save to File");
   Print("C - Cleanup Completed Setups");
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler (for immediate TP detection)           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
   //--- Check if it's a position close
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      // A deal was added to history
      ulong dealTicket = trans.deal;
      
      if(HistoryDealSelect(dealTicket)) {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         
         // Find which setup this belongs to
         for(int i = 0; i < g_setupCount; i++) {
            if(g_setups[i].magicNumber == (int)dealMagic) {
               // Check if this is a TP hit (positive profit)
               if(dealProfit > 0 && !g_setups[i].firstTPHit) {
                  Print("🎯 FIRST TP HIT DETECTED for ", g_setups[i].setupID);
                  
                  g_setups[i].firstTPHit = true;
                  
                  // Cancel remaining pending orders
                  int cancelled = CancelPendingOrders(g_setups[i].setupID);
                  Print("🚫 Cancelled ", cancelled, " remaining pending orders");
                  
                  // Save state
                  SaveSetupsToFile();
                  
                  // Alert
                  SendAlert("🎯 First TP Hit: " + g_setups[i].setupID);
               }
               
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Comment Display (Optional - shows info on chart)                 |
//+------------------------------------------------------------------+
void UpdateChartComment() {
   string comment = "";
   comment += "========================================\n";
   comment += "   GOLD ENGULFING EA v2.0\n";
   comment += "========================================\n";
   comment += "Active Setups: " + IntegerToString(g_setupCount) + "\n";
   
   int untapped = 0, tapped = 0, complete = 0, expired = 0;
   for(int i = 0; i < g_setupCount; i++) {
      switch(g_setups[i].state) {
         case SETUP_UNTAPPED: untapped++; break;
         case SETUP_TAPPED: tapped++; break;
         case SETUP_COMPLETE: complete++; break;
         case SETUP_EXPIRED: expired++; break;
      }
   }
   
   comment += "UNTAPPED: " + IntegerToString(untapped) + " 🟡\n";
   comment += "TAPPED: " + IntegerToString(tapped) + " 🔴\n";
   comment += "COMPLETE: " + IntegerToString(complete) + " ✅\n";
   comment += "EXPIRED: " + IntegerToString(expired) + " ⏰\n";
   comment += "========================================\n";
   comment += "Lifetime Created: " + IntegerToString(g_totalSetupsCreated) + "\n";
   comment += "Lifetime Completed: " + IntegerToString(g_totalSetupsCompleted) + "\n";
   comment += "========================================\n";
   comment += "Press 'S' for Summary\n";
   comment += "Press 'T' for Table\n";
   comment += "========================================\n";
   
   Comment(comment);
}

//+------------------------------------------------------------------+