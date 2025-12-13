//+------------------------------------------------------------------+
//|                                            VisualManager.mqh      |
//|                    Gold Engulfing EA - Visual Line Management     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Range Lines for UNTAPPED Setup (YELLOW dotted lines)        |
//+------------------------------------------------------------------+
void DrawRangeLines(EngulfingSetup &setup) {
   datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);

   // Draw HIGH line
   ObjectCreate(0, setup.lineHighName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeHigh, 
                currentTime, setup.rangeHigh);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_COLOR, InpUntappedLineColor);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_SELECTABLE, false);

   // Draw LOW line
   ObjectCreate(0, setup.lineLowName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeLow, 
                currentTime, setup.rangeLow);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_COLOR, InpUntappedLineColor);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_SELECTABLE, false);

   DebugPrint("Yellow lines drawn for setup: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Redraw Lines as TAPPED (RED) - Stop Extending at Tap Time        |
//+------------------------------------------------------------------+
void RedrawTappedLines(EngulfingSetup &setup) {
   // Delete old yellow lines
   ObjectDelete(0, setup.lineHighName);
   ObjectDelete(0, setup.lineLowName);

   // Create RED lines that stop at tappedTime
   ObjectCreate(0, setup.lineHighName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeHigh, 
                setup.tappedTime, setup.rangeHigh);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_COLOR, InpTappedLineColor);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineHighName, OBJPROP_SELECTABLE, false);

   ObjectCreate(0, setup.lineLowName, OBJ_TREND, 0, 
                setup.engulfedTime, setup.rangeLow, 
                setup.tappedTime, setup.rangeLow);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_COLOR, InpTappedLineColor);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, setup.lineLowName, OBJPROP_SELECTABLE, false);

   DebugPrint("Lines redrawn as RED (tapped) for setup: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Update UNTAPPED Lines to Current Time (Extend Yellow Lines)      |
//+------------------------------------------------------------------+
void UpdateUntappedLines(EngulfingSetup &setup, datetime currentTime) {
   // Only update if lines exist and setup is still UNTAPPED
   if(setup.state != SETUP_UNTAPPED) return;
   
   if(ObjectFind(0, setup.lineHighName) >= 0) {
      ObjectSetInteger(0, setup.lineHighName, OBJPROP_TIME, 1, currentTime);
   }
   
   if(ObjectFind(0, setup.lineLowName) >= 0) {
      ObjectSetInteger(0, setup.lineLowName, OBJPROP_TIME, 1, currentTime);
   }
}

//+------------------------------------------------------------------+
//| Update All Untapped Lines to Current Time                        |
//+------------------------------------------------------------------+
void UpdateAllUntappedLines() {
   datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);
   
   for(int i = 0; i < g_setupCount; i++) {
      if(g_setups[i].state == SETUP_UNTAPPED) {
         UpdateUntappedLines(g_setups[i], currentTime);
      }
   }
}

//+------------------------------------------------------------------+
//| Delete Lines for Setup                                           |
//+------------------------------------------------------------------+
void DeleteSetupLines(EngulfingSetup &setup) {
   ObjectDelete(0, setup.lineHighName);
   ObjectDelete(0, setup.lineLowName);
   
   DebugPrint("Lines deleted for setup: " + setup.setupID);
}

//+------------------------------------------------------------------+
//| Cleanup Old Lines (14+ days)                                     |
//+------------------------------------------------------------------+
void CleanupOldLines() {
   datetime cutoffTime = TimeCurrent() - (InpLookbackDays * 86400); // Convert days to seconds
   int deletedCount = 0;
   
   // Check all objects on chart
   int totalObjects = ObjectsTotal(0);
   
   for(int i = totalObjects - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      
      // Check if it's one of our setup lines
      if(StringFind(objName, "Engulf_") == 0) {
         // Get line's start time
         datetime lineTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         
         if(lineTime < cutoffTime) {
            ObjectDelete(0, objName);
            deletedCount++;
         }
      }
   }
   
   if(deletedCount > 0) {
      Print("🧹 Cleaned up ", deletedCount, " old visual lines (older than ", InpLookbackDays, " days)");
   }
}

//+------------------------------------------------------------------+
//| Restore Lines on EA Restart (from active setups in memory)       |
//+------------------------------------------------------------------+
void RestoreVisualLines() {
   Print("Restoring visual lines for ", g_setupCount, " active setups...");
   
   for(int i = 0; i < g_setupCount; i++) {
      EngulfingSetup* setup = GetSetupByIndex(i);
      if(setup == NULL) continue;
      
      // Check if lines already exist
      if(ObjectFind(0, setup.lineHighName) >= 0) {
         DebugPrint("Lines already exist for: " + setup.setupID);
         continue;
      }
      
      // Redraw based on state
      if(setup.state == SETUP_UNTAPPED) {
         // Yellow lines extending to current time
         DrawRangeLines(g_setups[i]);
      } else if(setup.state == SETUP_TAPPED) {
         // Red lines stopped at tappedTime
         RedrawTappedLines(g_setups[i]);
      }
      // COMPLETE and EXPIRED setups don't need lines
   }
   
   Print("Visual lines restored successfully");
}

//+------------------------------------------------------------------+
//| Check if Lines Exist for Setup                                   |
//+------------------------------------------------------------------+
bool LinesExist(string setupID) {
   string lineHighName = GenerateLineHighName(setupID);
   string lineLowName = GenerateLineLowName(setupID);
   
   return (ObjectFind(0, lineHighName) >= 0 && ObjectFind(0, lineLowName) >= 0);
}

//+------------------------------------------------------------------+
//| Delete All EA Lines from Chart                                   |
//+------------------------------------------------------------------+
void DeleteAllEALines() {
   int totalObjects = ObjectsTotal(0);
   int deletedCount = 0;
   
   for(int i = totalObjects - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      
      // Check if it's one of our setup lines
      if(StringFind(objName, "Engulf_") == 0) {
         ObjectDelete(0, objName);
         deletedCount++;
      }
   }
   
   if(deletedCount > 0) {
      Print("Deleted ", deletedCount, " EA lines from chart");
   }
}

//+------------------------------------------------------------------+
//| Count Visual Lines on Chart                                      |
//+------------------------------------------------------------------+
int CountEALines() {
   int count = 0;
   int totalObjects = ObjectsTotal(0);
   
   for(int i = 0; i < totalObjects; i++) {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "Engulf_") == 0) {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+