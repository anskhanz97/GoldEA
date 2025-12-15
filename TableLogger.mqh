//+------------------------------------------------------------------+
//|                                            TableLogger.mqh        |
//|                    Gold Engulfing EA - Professional Table Logger  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Display Complete Candle Analysis Table (336 bars = 14 days)      |
//+------------------------------------------------------------------+
void DisplayCandleTable() {
   if(!InpEnableTableLogs) return;
   
   Print("========================================================================");
   Print("                    CANDLE ANALYSIS TABLE (14 DAYS)");
   Print("========================================================================");
   Print(StringFormat("%-5s | %-19s | %-4s | %-9s | %-8s | %-8s | %-40s",
                     "Bar", "Date/Time", "Dir", "Body(pips)", "Open", "Close", "Status"));
   Print("------------------------------------------------------------------------");
   
   int engulfingCount = 0;
   int bullishEngulfingCount = 0;
   int bearishEngulfingCount = 0;
   int tappedCount = 0;
   int untappedCount = 0;
   
   // Scan last 336 bars (14 days on H1)
   for(int bar = MAX_LOOKBACK_BARS - 1; bar >= 0; bar--) {
      datetime barTime = iTime(_Symbol, PERIOD_H1, bar);
      if(barTime == 0) continue; // Skip if bar doesn't exist
      
      string dateTime = TimeToString(barTime, TIME_DATE|TIME_MINUTES);
      string direction = GetCandleDirection(bar);
      double bodySize = GetBodySizePips(bar);
      double open = iOpen(_Symbol, PERIOD_H1, bar);
      double close = iClose(_Symbol, PERIOD_H1, bar);
      string status = GetCandleStatus(bar);
      
      // Count statistics
      if(StringFind(status, "Engulfing") >= 0) {
         engulfingCount++;
         if(StringFind(status, "-B]") >= 0) bullishEngulfingCount++;
         if(StringFind(status, "-S]") >= 0) bearishEngulfingCount++;
         
         if(StringFind(status, "TAPPED") >= 0) {
            tappedCount++;
         } else {
            untappedCount++;
         }
      }
      
      // Print row
      Print(StringFormat("%-5d | %-19s | %-4s | %8.2f | %8.3f | %8.3f | %-40s",
                        bar, dateTime, direction, bodySize, open, close, status));
   }
   
   Print("========================================================================");
   Print("                            SUMMARY");
   Print("========================================================================");
   Print(StringFormat("Total Candles Analyzed: %d (14 days)", MAX_LOOKBACK_BARS));
   Print(StringFormat("Engulfing Patterns Found: %d", engulfingCount));
   Print(StringFormat("  - Bullish: %d", bullishEngulfingCount));
   Print(StringFormat("  - Bearish: %d", bearishEngulfingCount));
   Print(StringFormat("  - Untapped: %d", untappedCount));
   Print(StringFormat("  - Tapped: %d", tappedCount));
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Get Candle Direction String                                      |
//+------------------------------------------------------------------+
string GetCandleDirection(int bar) {
   if(IsBullishCandle(bar)) return "UP";
   if(IsBearishCandle(bar)) return "DOWN";
   return "DOJI";
}

//+------------------------------------------------------------------+
//| Get Candle Status (Main Logic)                                   |
//| Returns: "Not Engulfing" / "Same Direction" / "Engulfing [ID]" / "TAPPED [ID]" |
//+------------------------------------------------------------------+
string GetCandleStatus(int bar) {
   // Check if this bar is the engulfed candle in any setup
   datetime barTime = iTime(_Symbol, PERIOD_H1, bar);
   
   // Check against all active setups
   for(int i = 0; i < g_setupCount; i++) {
      if(g_setups[i].engulfedTime == barTime) {
         // This bar is the engulfed candle
         if(g_setups[i].state == SETUP_UNTAPPED) {
            return "Engulfing [" + g_setups[i].setupID + "]";
         } else if(g_setups[i].state == SETUP_TAPPED) {
            return "TAPPED [" + g_setups[i].setupID + "]";
         } else if(g_setups[i].state == SETUP_COMPLETE) {
            return "COMPLETE [" + g_setups[i].setupID + "]";
         } else if(g_setups[i].state == SETUP_EXPIRED) {
            return "EXPIRED [" + g_setups[i].setupID + "]";
         }
      }
   }
   
   // Not part of any setup - check if it's engulfing pattern (not saved)
   if(bar > 0) {
      bool isBullish = IsBullishCandle(bar);
      bool isBearish = IsBearishCandle(bar);
      bool prevBullish = IsBullishCandle(bar + 1);
      bool prevBearish = IsBearishCandle(bar + 1);
      
      // Check if it's potential engulfing (opposite colors)
      if((isBullish && prevBearish) || (isBearish && prevBullish)) {
         // Check if it actually engulfs
         double engulfing_high = GetBodyHigh(bar);
         double engulfing_low = GetBodyLow(bar);
         double engulfed_high = GetBodyHigh(bar + 1);
         double engulfed_low = GetBodyLow(bar + 1);
         
         if(IsEngulfingWithTolerance(engulfing_high, engulfing_low, engulfed_high, engulfed_low)) {
            double engulfedBodySize = GetBodySizePips(bar + 1);
            if(engulfedBodySize >= InpMinBodySize) {
               return "Potential Engulfing (not saved)";
            }
         }
      }
      
      // Same direction as previous
      if((isBullish && prevBullish) || (isBearish && prevBearish)) {
         return "Same Direction";
      }
   }
   
   return "Not Engulfing";
}

//+------------------------------------------------------------------+
//| Display Compact Summary (for OnTick/Timer - less verbose)        |
//+------------------------------------------------------------------+
void DisplayCompactSummary() {
   if(!InpEnableTableLogs) return;
   
   int engulfingCount = 0;
   int untappedCount = 0;
   int tappedCount = 0;
   int completeCount = 0;
   int expiredCount = 0;
   
   for(int i = 0; i < g_setupCount; i++) {
      engulfingCount++;
      switch(g_setups[i].state) {
         case SETUP_UNTAPPED:  untappedCount++; break;
         case SETUP_TAPPED:    tappedCount++; break;
         case SETUP_COMPLETE:  completeCount++; break;
         case SETUP_EXPIRED:   expiredCount++; break;
      }
   }
   
   Print("┌─────────────────────────────────────────────────────────────┐");
   Print("│                    SETUP STATUS SUMMARY                     │");
   Print("├─────────────────────────────────────────────────────────────┤");
   Print(StringFormat("│ Active Setups:    %-4d                                     │", g_setupCount));
   Print(StringFormat("│ UNTAPPED (🟡):    %-4d  (Orders placed, waiting)          │", untappedCount));
   Print(StringFormat("│ TAPPED (🔴):      %-4d  (Orders executing)                │", tappedCount));
   Print(StringFormat("│ COMPLETE (✅):    %-4d  (All done)                        │", completeCount));
   Print(StringFormat("│ EXPIRED (⏰):     %-4d  (Never tapped)                    │", expiredCount));
   Print("├─────────────────────────────────────────────────────────────┤");
   Print(StringFormat("│ Lifetime Created: %-4d                                    │", g_totalSetupsCreated));
   Print(StringFormat("│ Lifetime Completed: %-4d                                  │", g_totalSetupsCompleted));
   Print(StringFormat("│ Lifetime Expired: %-4d                                    │", g_totalSetupsExpired));
   Print("└─────────────────────────────────────────────────────────────┘");
}

//+------------------------------------------------------------------+
//| Display Active Setups Details                                    |
//+------------------------------------------------------------------+
void DisplayActiveSetups() {
   if(!InpEnableTableLogs) return;
   if(g_setupCount == 0) {
      Print("No active setups");
      return;
   }
   
   Print("========================================================================");
   Print("                        ACTIVE SETUPS DETAIL");
   Print("========================================================================");
   Print(StringFormat("%-25s | %-8s | %-10s | %-6s | %-6s",
                     "Setup ID", "State", "Direction", "Orders", "Profit"));
   Print("------------------------------------------------------------------------");
   
   for(int i = 0; i < g_setupCount; i++) {
      string state = GetStateName(g_setups[i].state);
      string direction = g_setups[i].isBullish ? "BULLISH" : "BEARISH";
      string orders = StringFormat("%d/%d", g_setups[i].ordersExecuted, g_setups[i].ordersPlaced);
      string profit = StringFormat("$%.2f", g_setups[i].totalProfit);
      
      Print(StringFormat("%-25s | %-8s | %-10s | %-6s | %-6s",
                        g_setups[i].setupID, state, direction, orders, profit));
      
      // Show additional details for tapped setups
      if(g_setups[i].state == SETUP_TAPPED || g_setups[i].state == SETUP_COMPLETE) {
         Print(StringFormat("  └─> TP: %d | SL: %d | Manual: %d | First TP Hit: %s",
                           g_setups[i].tpCount,
                           g_setups[i].slCount,
                           g_setups[i].manualCloseCount,
                           g_setups[i].firstTPHit ? "YES" : "NO"));
      }
   }
   
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Display Single Setup Details                                     |
//+------------------------------------------------------------------+
void DisplaySetupDetails(string setupID) {
   int index = GetSetupIndexByID(setupID);
   if(!IsValidSetupIndex(index)) {
      Print("Setup not found: ", setupID);
      return;
   }
   
   Print("========================================================================");
   Print("                        SETUP DETAILS");
   Print("========================================================================");
   Print("Setup ID:          ", g_setups[index].setupID);
   Print("Magic Number:      ", g_setups[index].magicNumber);
   Print("Direction:         ", g_setups[index].isBullish ? "BULLISH" : "BEARISH");
   Print("State:             ", GetStateName(g_setups[index].state));
   Print("------------------------------------------------------------------------");
   Print("Engulfing Time:    ", TimeToString(g_setups[index].engulfingTime, TIME_DATE|TIME_MINUTES));
   Print("Engulfed Time:     ", TimeToString(g_setups[index].engulfedTime, TIME_DATE|TIME_MINUTES));
   Print("Created Time:      ", TimeToString(g_setups[index].createdTime, TIME_DATE|TIME_MINUTES));
   if(g_setups[index].tappedTime > 0) {
      Print("Tapped Time:       ", TimeToString(g_setups[index].tappedTime, TIME_DATE|TIME_MINUTES));
   }
   Print("------------------------------------------------------------------------");
   Print("Range High:        ", DoubleToString(g_setups[index].rangeHigh, _Digits));
   Print("Range Low:         ", DoubleToString(g_setups[index].rangeLow, _Digits));
   Print("Range Size:        ", DoubleToString(PointsToPips(g_setups[index].rangeHigh - g_setups[index].rangeLow), 2), " pips");
   Print("------------------------------------------------------------------------");
   Print("Orders Placed:     ", g_setups[index].ordersPlaced);
   Print("Orders Executed:   ", g_setups[index].ordersExecuted);
   Print("Orders Closed:     ", g_setups[index].ordersClosed);
   Print("First TP Hit:      ", g_setups[index].firstTPHit ? "YES" : "NO");
   Print("Setup Complete:    ", g_setups[index].setupComplete ? "YES" : "NO");
   Print("------------------------------------------------------------------------");
   Print("Total Profit:      $", DoubleToString(g_setups[index].totalProfit, 2));
   Print("TP Hits:           ", g_setups[index].tpCount);
   Print("SL Hits:           ", g_setups[index].slCount);
   Print("Manual Closes:     ", g_setups[index].manualCloseCount);
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Display Trading Statistics                                       |
//+------------------------------------------------------------------+
void DisplayTradingStatistics() {
   if(!InpEnableTableLogs) return;
   
   double totalProfit = 0;
   int totalTPHits = 0;
   int totalSLHits = 0;
   int totalManualCloses = 0;
   int totalExecuted = 0;
   
   for(int i = 0; i < g_setupCount; i++) {
      totalProfit += g_setups[i].totalProfit;
      totalTPHits += g_setups[i].tpCount;
      totalSLHits += g_setups[i].slCount;
      totalManualCloses += g_setups[i].manualCloseCount;
      totalExecuted += g_setups[i].ordersExecuted;
   }
   
   Print("========================================================================");
   Print("                        TRADING STATISTICS");
   Print("========================================================================");
   Print(StringFormat("Total Setups Created:      %d", g_totalSetupsCreated));
   Print(StringFormat("Active Setups:             %d", g_setupCount));
   Print(StringFormat("Completed Setups:          %d", g_totalSetupsCompleted));
   Print(StringFormat("Expired Setups:            %d", g_totalSetupsExpired));
   Print("------------------------------------------------------------------------");
   Print(StringFormat("Total Orders Executed:     %d", totalExecuted));
   Print(StringFormat("TP Hits:                   %d", totalTPHits));
   Print(StringFormat("SL Hits:                   %d", totalSLHits));
   Print(StringFormat("Manual Closes:             %d", totalManualCloses));
   Print("------------------------------------------------------------------------");
   Print(StringFormat("Total Profit:              $%.2f", totalProfit));
   if(totalExecuted > 0) {
      Print(StringFormat("Average per Trade:         $%.2f", totalProfit / totalExecuted));
   }
   if(totalTPHits + totalSLHits > 0) {
      double winRate = (double)totalTPHits / (totalTPHits + totalSLHits) * 100.0;
      Print(StringFormat("Win Rate:                  %.1f%%", winRate));
   }
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Display Recent Engulfing Patterns (Last 10)                      |
//+------------------------------------------------------------------+
void DisplayRecentEngulfing() {
   if(!InpEnableTableLogs) return;
   
   int count = MathMin(10, g_setupCount);
   if(count == 0) {
      Print("No engulfing patterns found yet");
      return;
   }
   
   Print("========================================================================");
   Print("                    RECENT ENGULFING PATTERNS");
   Print("========================================================================");
   
   // Show last 10 setups (most recent first)
   for(int i = g_setupCount - 1; i >= g_setupCount - count && i >= 0; i--) {
      string dir = g_setups[i].isBullish ? "🟢 BULLISH" : "🔴 BEARISH";
      string state = GetStateName(g_setups[i].state);
      string time = TimeToString(g_setups[i].engulfingTime, TIME_DATE|TIME_MINUTES);
      
      Print(StringFormat("%s | %s | %s | Profit: $%.2f",
                        g_setups[i].setupID, dir, state, g_setups[i].totalProfit));
   }
   
   Print("========================================================================");
}

//+------------------------------------------------------------------+
//| Log New Bar Alert                                                |
//+------------------------------------------------------------------+
void LogNewBarAlert() {
   if(!InpEnableTableLogs) return;
   
   datetime barTime = iTime(_Symbol, PERIOD_H1, 0);
   Print("⏰ New H1 Bar: ", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Log Trade Execution                                              |
//+------------------------------------------------------------------+
void LogTradeExecution(string setupID, int executedCount, int totalOrders) {
   if(!InpEnableTableLogs) return;
   
   Print(StringFormat("📈 Trade Executed | Setup: %s | %d/%d orders filled",
                     setupID, executedCount, totalOrders));
}

//+------------------------------------------------------------------+
//| Log Trade Completion                                             |
//+------------------------------------------------------------------+
void LogTradeCompletion(string setupID, double profit) {
   if(!InpEnableTableLogs) return;
   
   string profitIcon = (profit >= 0) ? "✅" : "❌";
   Print(StringFormat("%s Trade Complete | Setup: %s | Profit: $%.2f",
                     profitIcon, setupID, profit));
}

//+------------------------------------------------------------------+