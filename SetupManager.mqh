//+------------------------------------------------------------------+
//|                                            SetupManager.mqh       |
//|                    Gold Engulfing EA - Setup State Machine        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check All UNTAPPED Setups - Have They Been Tapped?               |
//+------------------------------------------------------------------+
void CheckUntappedSetups() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentPrice = (currentBid + currentAsk) / 2.0;
   
   for(int i = 0; i < g_setupCount; i++) {
      if(g_setups[i].state == SETUP_UNTAPPED) {
         // Check if price has entered the range
         if(IsPriceInRange(currentPrice, g_setups[i].rangeHigh, g_setups[i].rangeLow)) {
            MarkSetupAsTapped(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mark Setup as TAPPED                                             |
//+------------------------------------------------------------------+
void MarkSetupAsTapped(int index) {
   if(index < 0 || index >= g_setupCount) return;
   
   EngulfingSetup* setup = GetSetupByIndex(index);
   if(setup == NULL) return;
   
   // Update state
   setup.state = SETUP_TAPPED;
   setup.tappedTime = TimeCurrent();
   
   // Redraw lines as RED
   RedrawTappedLines(g_setups[index]);
   
   Print("🎯 Setup TAPPED: ", setup.setupID, " at ", TimeToString(setup.tappedTime, TIME_DATE|TIME_MINUTES));
   SendAlert("🎯 Setup Tapped: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Check TAPPED Setups - Monitor for TP Hit & Order Management      |
//+------------------------------------------------------------------+
void CheckTappedSetups() {
   for(int i = g_setupCount - 1; i >= 0; i--) {
      if(g_setups[i].state == SETUP_TAPPED) {
         // Update order status
         UpdateOrderStatus(g_setups[i]);
         
         // Check if first TP hit
         if(!g_setups[i].firstTPHit) {
            if(CheckFirstTPHit(g_setups[i])) {
               g_setups[i].firstTPHit = true;
               
               // Cancel remaining pending orders
               int cancelled = CancelPendingOrders(g_setups[i].setupID);
               
               Print("✅ First TP hit for ", g_setups[i].setupID, " | Cancelled ", cancelled, " pending orders");
               SendAlert("✅ First TP Hit: " + g_setups[i].setupID);
            }
         }
         
         // Calculate profits
         CalculateSetupProfit(g_setups[i]);
         
         // Check if setup is complete
         if(AreAllOrdersHandled(g_setups[i])) {
            MarkSetupAsComplete(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mark Setup as COMPLETE                                           |
//+------------------------------------------------------------------+
void MarkSetupAsComplete(int index) {
   if(index < 0 || index >= g_setupCount) return;
   
   EngulfingSetup* setup = GetSetupByIndex(index);
   if(setup == NULL) return;
   
   // Update state
   setup.state = SETUP_COMPLETE;
   setup.setupComplete = true;
   
   g_totalSetupsCompleted++;
   
   Print("🏁 Setup COMPLETE: ", setup.setupID);
   Print(StringFormat("   Total Profit: $%.2f | TP Hits: %d | SL Hits: %d | Orders Closed: %d",
                     setup.totalProfit, setup.tpCount, setup.slCount, setup.ordersClosed));
   
   SendAlert(StringFormat("🏁 Setup Complete: %s | Profit: $%.2f", setup.setupID, setup.totalProfit));
   
   // Delete visual lines (setup is done)
   DeleteSetupLines(g_setups[index]);
}

//+------------------------------------------------------------------+
//| Check for EXPIRED Setups (14+ days old, never tapped)            |
//+------------------------------------------------------------------+
void CheckExpiredSetups() {
   datetime cutoffTime = TimeCurrent() - (InpLookbackDays * 86400);
   
   for(int i = g_setupCount - 1; i >= 0; i--) {
      if(g_setups[i].state == SETUP_UNTAPPED) {
         // Check if setup is too old
         if(g_setups[i].createdTime < cutoffTime) {
            MarkSetupAsExpired(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mark Setup as EXPIRED                                            |
//+------------------------------------------------------------------+
void MarkSetupAsExpired(int index) {
   if(index < 0 || index >= g_setupCount) return;
   
   EngulfingSetup* setup = GetSetupByIndex(index);
   if(setup == NULL) return;
   
   // Cancel any pending orders (should be none, but safety check)
   int cancelled = CancelPendingOrders(setup.setupID);
   if(cancelled > 0) {
      Print("⚠️ Cancelled ", cancelled, " pending orders for expired setup: ", setup.setupID);
   }
   
   // Update state
   setup.state = SETUP_EXPIRED;
   setup.setupComplete = true;
   
   g_totalSetupsExpired++;
   
   Print("⏰ Setup EXPIRED: ", setup.setupID, " (never tapped after ", InpLookbackDays, " days)");
   
   // Delete visual lines
   DeleteSetupLines(g_setups[index]);
}

//+------------------------------------------------------------------+
//| Cleanup COMPLETE and EXPIRED Setups from Memory                  |
//+------------------------------------------------------------------+
void CleanupCompletedSetups() {
   for(int i = g_setupCount - 1; i >= 0; i--) {
      if(g_setups[i].state == SETUP_COMPLETE || g_setups[i].state == SETUP_EXPIRED) {
         // Additional safety: ensure no orders remain
         int pending = CountPendingOrders(g_setups[i].setupID);
         int positions = CountExecutedPositions(g_setups[i].setupID, g_setups[i].magicNumber);
         
         if(pending == 0 && positions == 0) {
            string setupID = g_setups[i].setupID;
            RemoveSetup(i);
            DebugPrint("Cleaned up setup from memory: " + setupID);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Handle Manual Position Close (Cancel Remaining Orders)           |
//+------------------------------------------------------------------+
void CheckManualCloses() {
   // Track which setups have open positions
   for(int i = 0; i < g_setupCount; i++) {
      if(g_setups[i].state == SETUP_TAPPED && !g_setups[i].firstTPHit) {
         int previousExecuted = g_setups[i].ordersExecuted;
         UpdateOrderStatus(g_setups[i]);
         int currentExecuted = g_setups[i].ordersExecuted;
         
         // Check if positions decreased (manual close detected)
         if(currentExecuted < previousExecuted) {
            Print("🔧 Manual close detected for setup: ", g_setups[i].setupID);
            
            // Cancel remaining pending orders
            int cancelled = CancelPendingOrders(g_setups[i].setupID);
            
            if(cancelled > 0) {
               Print("🚫 Cancelled ", cancelled, " pending orders due to manual close");
               SendAlert("Manual close: Cancelled " + IntegerToString(cancelled) + " orders");
            }
            
            // Mark as complete if no orders remain
            if(AreAllOrdersHandled(g_setups[i])) {
               MarkSetupAsComplete(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process New Setup (Create, Draw, Place Orders)                   |
//+------------------------------------------------------------------+
void ProcessNewSetup(string setupID) {
   if(setupID == "") return;
   
   // Create setup object
   EngulfingSetup setup = CreateSetup(setupID);
   
   // Add to array
   AddSetup(setup);
   
   // Get pointer to setup in array (for modification)
   EngulfingSetup* setupPtr = GetSetupByID(setupID);
   if(setupPtr == NULL) {
      Print("ERROR: Failed to get setup pointer after adding: ", setupID);
      return;
   }
   
   // Draw visual lines (yellow)
   DrawRangeLines(g_setups[g_setupCount - 1]);
   
   // Place orders
   PlaceOrders(g_setups[g_setupCount - 1]);
   
   Print("✅ New setup processed successfully: ", setupID);
}

//+------------------------------------------------------------------+
//| Get Setup Statistics                                             |
//+------------------------------------------------------------------+
string GetSetupStatistics() {
   int untappedCount = 0;
   int tappedCount = 0;
   int completeCount = 0;
   int expiredCount = 0;
   
   for(int i = 0; i < g_setupCount; i++) {
      switch(g_setups[i].state) {
         case SETUP_UNTAPPED:  untappedCount++; break;
         case SETUP_TAPPED:    tappedCount++; break;
         case SETUP_COMPLETE:  completeCount++; break;
         case SETUP_EXPIRED:   expiredCount++; break;
      }
   }
   
   string stats = StringFormat("Active Setups: %d | UNTAPPED: %d | TAPPED: %d | COMPLETE: %d | EXPIRED: %d",
                               g_setupCount, untappedCount, tappedCount, completeCount, expiredCount);
   
   return stats;
}

//+------------------------------------------------------------------+
//| Print Setup Summary                                              |
//+------------------------------------------------------------------+
void PrintSetupSummary() {
   Print("================== SETUP SUMMARY ==================");
   Print(GetSetupStatistics());
   Print("Lifetime Stats:");
   Print("  Total Created: ", g_totalSetupsCreated);
   Print("  Total Completed: ", g_totalSetupsCompleted);
   Print("  Total Expired: ", g_totalSetupsExpired);
   Print("===================================================");
}

//+------------------------------------------------------------------+
//| Validate Setup Data Integrity                                    |
//+------------------------------------------------------------------+
bool ValidateSetupIntegrity() {
   bool allValid = true;
   
   for(int i = 0; i < g_setupCount; i++) {
      // Check for valid setup ID
      if(g_setups[i].setupID == "") {
         Print("ERROR: Setup at index ", i, " has empty ID");
         allValid = false;
      }
      
      // Check for valid range
      if(g_setups[i].rangeHigh <= g_setups[i].rangeLow) {
         Print("ERROR: Setup ", g_setups[i].setupID, " has invalid range");
         allValid = false;
      }
      
      // Check for valid magic number
      if(g_setups[i].magicNumber <= 0) {
         Print("ERROR: Setup ", g_setups[i].setupID, " has invalid magic number");
         allValid = false;
      }
   }
   
   return allValid;
}

//+------------------------------------------------------------------+
//| Emergency: Cancel All Pending Orders for All Setups              |
//+------------------------------------------------------------------+
void EmergencyCancelAllOrders() {
   Print("🚨 EMERGENCY: Cancelling all pending orders...");
   
   int totalCancelled = 0;
   for(int i = 0; i < g_setupCount; i++) {
      int cancelled = CancelPendingOrders(g_setups[i].setupID);
      totalCancelled += cancelled;
   }
   
   Print("🚨 Emergency cancellation complete: ", totalCancelled, " orders cancelled");
}

//+------------------------------------------------------------------+