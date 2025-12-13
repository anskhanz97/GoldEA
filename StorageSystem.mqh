//+------------------------------------------------------------------+
//|                                          StorageSystem.mqh        |
//|                    Gold Engulfing EA - File Storage System        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Storage System                                         |
//+------------------------------------------------------------------+
bool InitializeStorage() {
   // Create Files folder if it doesn't exist (MT5 does this automatically)
   
   // Check if files are accessible
   if(!FileIsExist(FILE_SETUPS)) {
      Print("📁 Setup file doesn't exist, will be created on first save");
   } else {
      Print("📁 Setup file found: ", FILE_SETUPS);
   }
   
   WriteLog("Storage system initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Save All Setups to JSON File                                     |
//+------------------------------------------------------------------+
bool SaveSetupsToFile() {
   if(g_setupCount == 0) {
      DebugPrint("No setups to save");
      return true; // Not an error
   }
   
   // Build JSON string
   string json = BuildSetupsJSON();
   
   if(json == "") {
      Print("ERROR: Failed to build JSON string");
      WriteLog("ERROR: Failed to build JSON for save");
      return false;
   }
   
   // Write to main file
   if(!WriteJSONToFile(FILE_SETUPS, json)) {
      Print("ERROR: Failed to write to ", FILE_SETUPS);
      WriteLog("ERROR: Failed to save setups to file");
      return false;
   }
   
   // Append to backup file
   AppendToBackup(json);
   
   Print("💾 Saved ", g_setupCount, " setups to file");
   WriteLog(StringFormat("Saved %d setups to file", g_setupCount));
   
   return true;
}

//+------------------------------------------------------------------+
//| Load Setups from JSON File                                       |
//+------------------------------------------------------------------+
bool LoadSetupsFromFile() {
   if(!FileIsExist(FILE_SETUPS)) {
      Print("📁 No existing setup file found - starting fresh");
      WriteLog("No setup file found - fresh start");
      return true; // Not an error for first run
   }
   
   // Read file
   string json = ReadJSONFromFile(FILE_SETUPS);
   
   if(json == "") {
      Print("⚠️ Setup file is empty or couldn't be read");
      WriteLog("WARNING: Setup file empty or unreadable");
      return true; // Continue anyway
   }
   
   // Parse JSON and populate g_setups array
   if(!ParseSetupsJSON(json)) {
      Print("ERROR: Failed to parse setup file");
      WriteLog("ERROR: Failed to parse setup JSON");
      return false;
   }
   
   Print("📂 Loaded ", g_setupCount, " setups from file");
   WriteLog(StringFormat("Loaded %d setups from file", g_setupCount));
   
   return true;
}

//+------------------------------------------------------------------+
//| Build JSON String from Setup Array                               |
//+------------------------------------------------------------------+
string BuildSetupsJSON() {
   string json = "{\n";
   json += "  \"version\": \"2.0\",\n";
   json += "  \"timestamp\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",\n";
   json += "  \"setupCount\": " + IntegerToString(g_setupCount) + ",\n";
   json += "  \"setups\": [\n";
   
   for(int i = 0; i < g_setupCount; i++) {
      json += "    {\n";
      json += "      \"setupID\": \"" + g_setups[i].setupID + "\",\n";
      json += "      \"magicNumber\": " + IntegerToString(g_setups[i].magicNumber) + ",\n";
      json += "      \"engulfingTime\": " + IntegerToString((long)g_setups[i].engulfingTime) + ",\n";
      json += "      \"engulfedTime\": " + IntegerToString((long)g_setups[i].engulfedTime) + ",\n";
      json += "      \"tappedTime\": " + IntegerToString((long)g_setups[i].tappedTime) + ",\n";
      json += "      \"createdTime\": " + IntegerToString((long)g_setups[i].createdTime) + ",\n";
      json += "      \"rangeHigh\": " + DoubleToString(g_setups[i].rangeHigh, _Digits) + ",\n";
      json += "      \"rangeLow\": " + DoubleToString(g_setups[i].rangeLow, _Digits) + ",\n";
      json += "      \"isBullish\": " + (g_setups[i].isBullish ? "true" : "false") + ",\n";
      json += "      \"state\": " + IntegerToString(g_setups[i].state) + ",\n";
      json += "      \"setupComplete\": " + (g_setups[i].setupComplete ? "true" : "false") + ",\n";
      json += "      \"firstTPHit\": " + (g_setups[i].firstTPHit ? "true" : "false") + ",\n";
      json += "      \"ordersPlaced\": " + IntegerToString(g_setups[i].ordersPlaced) + ",\n";
      json += "      \"ordersExecuted\": " + IntegerToString(g_setups[i].ordersExecuted) + ",\n";
      json += "      \"ordersClosed\": " + IntegerToString(g_setups[i].ordersClosed) + ",\n";
      json += "      \"totalProfit\": " + DoubleToString(g_setups[i].totalProfit, 2) + ",\n";
      json += "      \"tpCount\": " + IntegerToString(g_setups[i].tpCount) + ",\n";
      json += "      \"slCount\": " + IntegerToString(g_setups[i].slCount) + ",\n";
      json += "      \"manualCloseCount\": " + IntegerToString(g_setups[i].manualCloseCount) + "\n";
      json += "    }";
      
      if(i < g_setupCount - 1) {
         json += ",";
      }
      json += "\n";
   }
   
   json += "  ]\n";
   json += "}\n";
   
   return json;
}

//+------------------------------------------------------------------+
//| Parse JSON String and Populate Setup Array                       |
//+------------------------------------------------------------------+
bool ParseSetupsJSON(string json) {
   // Clear existing array
   ArrayResize(g_setups, 0);
   g_setupCount = 0;
   
   // Simple manual JSON parsing (MQL5 doesn't have native JSON parser)
   // We'll extract values using string operations
   
   // Extract setupCount
   int setupCountPos = StringFind(json, "\"setupCount\":");
   if(setupCountPos < 0) {
      Print("ERROR: Cannot find setupCount in JSON");
      return false;
   }
   
   int countStart = StringFind(json, ":", setupCountPos) + 1;
   int countEnd = StringFind(json, ",", countStart);
   string countStr = StringSubstr(json, countStart, countEnd - countStart);
   StringTrimLeft(countStr);
   StringTrimRight(countStr);
   int savedSetupCount = (int)StringToInteger(countStr);
   
   if(savedSetupCount == 0) {
      Print("No setups in file");
      return true;
   }
   
   // Find setups array start
   int setupsArrayStart = StringFind(json, "\"setups\": [");
   if(setupsArrayStart < 0) {
      Print("ERROR: Cannot find setups array in JSON");
      return false;
   }
   
   // Parse each setup
   int searchPos = setupsArrayStart;
   for(int i = 0; i < savedSetupCount; i++) {
      EngulfingSetup setup;
      
      // Find next setup object
      searchPos = StringFind(json, "{", searchPos + 1);
      if(searchPos < 0) break;
      
      int setupEnd = StringFind(json, "}", searchPos);
      if(setupEnd < 0) break;
      
      string setupJSON = StringSubstr(json, searchPos, setupEnd - searchPos + 1);
      
      // Extract fields
      setup.setupID = ExtractStringValue(setupJSON, "setupID");
      setup.magicNumber = (int)ExtractIntValue(setupJSON, "magicNumber");
      setup.engulfingTime = (datetime)ExtractIntValue(setupJSON, "engulfingTime");
      setup.engulfedTime = (datetime)ExtractIntValue(setupJSON, "engulfedTime");
      setup.tappedTime = (datetime)ExtractIntValue(setupJSON, "tappedTime");
      setup.createdTime = (datetime)ExtractIntValue(setupJSON, "createdTime");
      setup.rangeHigh = ExtractDoubleValue(setupJSON, "rangeHigh");
      setup.rangeLow = ExtractDoubleValue(setupJSON, "rangeLow");
      setup.isBullish = ExtractBoolValue(setupJSON, "isBullish");
      setup.state = (int)ExtractIntValue(setupJSON, "state");
      setup.setupComplete = ExtractBoolValue(setupJSON, "setupComplete");
      setup.firstTPHit = ExtractBoolValue(setupJSON, "firstTPHit");
      setup.ordersPlaced = (int)ExtractIntValue(setupJSON, "ordersPlaced");
      setup.ordersExecuted = (int)ExtractIntValue(setupJSON, "ordersExecuted");
      setup.ordersClosed = (int)ExtractIntValue(setupJSON, "ordersClosed");
      setup.totalProfit = ExtractDoubleValue(setupJSON, "totalProfit");
      setup.tpCount = (int)ExtractIntValue(setupJSON, "tpCount");
      setup.slCount = (int)ExtractIntValue(setupJSON, "slCount");
      setup.manualCloseCount = (int)ExtractIntValue(setupJSON, "manualCloseCount");
      
      // Generate line names
      setup.lineHighName = GenerateLineHighName(setup.setupID);
      setup.lineLowName = GenerateLineLowName(setup.setupID);
      
      // Add to array
      ArrayResize(g_setups, g_setupCount + 1);
      g_setups[g_setupCount] = setup;
      g_setupCount++;
      
      searchPos = setupEnd;
   }
   
   Print("Parsed ", g_setupCount, " setups from JSON");
   return true;
}

//+------------------------------------------------------------------+
//| Extract String Value from JSON                                   |
//+------------------------------------------------------------------+
string ExtractStringValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "";
   
   int valueStart = StringFind(json, "\"", keyPos + StringLen(searchKey)) + 1;
   int valueEnd = StringFind(json, "\"", valueStart);
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| Extract Integer Value from JSON                                  |
//+------------------------------------------------------------------+
long ExtractIntValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return 0;
   
   int valueStart = keyPos + StringLen(searchKey);
   int valueEnd = StringFind(json, ",", valueStart);
   if(valueEnd < 0) valueEnd = StringFind(json, "\n", valueStart);
   
   string valueStr = StringSubstr(json, valueStart, valueEnd - valueStart);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToInteger(valueStr);
}

//+------------------------------------------------------------------+
//| Extract Double Value from JSON                                   |
//+------------------------------------------------------------------+
double ExtractDoubleValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return 0;
   
   int valueStart = keyPos + StringLen(searchKey);
   int valueEnd = StringFind(json, ",", valueStart);
   if(valueEnd < 0) valueEnd = StringFind(json, "\n", valueStart);
   
   string valueStr = StringSubstr(json, valueStart, valueEnd - valueStart);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToDouble(valueStr);
}

//+------------------------------------------------------------------+
//| Extract Boolean Value from JSON                                  |
//+------------------------------------------------------------------+
bool ExtractBoolValue(string json, string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return false;
   
   int valueStart = keyPos + StringLen(searchKey);
   string remainder = StringSubstr(json, valueStart, 10);
   
   return (StringFind(remainder, "true") >= 0);
}

//+------------------------------------------------------------------+
//| Write JSON String to File                                        |
//+------------------------------------------------------------------+
bool WriteJSONToFile(string filename, string json) {
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
   
   if(handle == INVALID_HANDLE) {
      int error = GetLastError();
      Print("ERROR: Cannot open file for writing: ", filename, " | Error: ", error);
      return false;
   }
   
   uint written = FileWriteString(handle, json);
   FileClose(handle);
   
   if(written == 0) {
      Print("ERROR: Failed to write to file: ", filename);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Read JSON String from File                                       |
//+------------------------------------------------------------------+
string ReadJSONFromFile(string filename) {
   int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
   
   if(handle == INVALID_HANDLE) {
      int error = GetLastError();
      Print("ERROR: Cannot open file for reading: ", filename, " | Error: ", error);
      return "";
   }
   
   string json = "";
   while(!FileIsEnding(handle)) {
      json += FileReadString(handle);
   }
   
   FileClose(handle);
   return json;
}

//+------------------------------------------------------------------+
//| Append to Backup File (with Timestamp)                           |
//+------------------------------------------------------------------+
void AppendToBackup(string json) {
   int handle = FileOpen(FILE_BACKUPS, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   
   if(handle == INVALID_HANDLE) {
      // File doesn't exist, create it
      handle = FileOpen(FILE_BACKUPS, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE) {
         Print("WARNING: Cannot create backup file");
         return;
      }
   }
   
   // Seek to end
   FileSeek(handle, 0, SEEK_END);
   
   // Write separator and timestamp
   string separator = "\n========================================\n";
   separator += "Backup: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
   separator += "========================================\n";
   
   FileWriteString(handle, separator);
   FileWriteString(handle, json);
   FileWriteString(handle, "\n");
   
   FileClose(handle);
   
   DebugPrint("Backup appended successfully");
}

//+------------------------------------------------------------------+
//| Write Log Entry                                                  |
//+------------------------------------------------------------------+
void WriteLog(string message) {
   int handle = FileOpen(FILE_LOGS, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   
   if(handle == INVALID_HANDLE) {
      // Create new log file
      handle = FileOpen(FILE_LOGS, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE) {
         return; // Silently fail - logging is not critical
      }
   }
   
   // Seek to end
   FileSeek(handle, 0, SEEK_END);
   
   // Write log entry
   string logEntry = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " | " + message + "\n";
   FileWriteString(handle, logEntry);
   
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Clear Old Log Entries (keep last 1000 lines)                     |
//+------------------------------------------------------------------+
void TrimLogFile() {
   // This is optional - implement if log file gets too large
   // For now, we'll keep all logs
   DebugPrint("Log file maintenance check");
}

//+------------------------------------------------------------------+
//| Delete Storage Files (for testing/reset)                         |
//+------------------------------------------------------------------+
void DeleteStorageFiles() {
   if(FileIsExist(FILE_SETUPS)) {
      FileDelete(FILE_SETUPS);
      Print("Deleted: ", FILE_SETUPS);
   }
   
   if(FileIsExist(FILE_BACKUPS)) {
      FileDelete(FILE_BACKUPS);
      Print("Deleted: ", FILE_BACKUPS);
   }
   
   if(FileIsExist(FILE_LOGS)) {
      FileDelete(FILE_LOGS);
      Print("Deleted: ", FILE_LOGS);
   }
   
   WriteLog("Storage files deleted");
}

//+------------------------------------------------------------------+
//| Get File Info                                                    |
//+------------------------------------------------------------------+
void PrintStorageInfo() {
   Print("================== STORAGE INFO ==================");
   
   if(FileIsExist(FILE_SETUPS)) {
      int handle = FileOpen(FILE_SETUPS, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle != INVALID_HANDLE) {
         ulong size = FileSize(handle);
         FileClose(handle);
         Print("Setup File: ", FILE_SETUPS, " | Size: ", size, " bytes");
      }
   } else {
      Print("Setup File: Not found");
   }
   
   if(FileIsExist(FILE_BACKUPS)) {
      int handle = FileOpen(FILE_BACKUPS, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle != INVALID_HANDLE) {
         ulong size = FileSize(handle);
         FileClose(handle);
         Print("Backup File: ", FILE_BACKUPS, " | Size: ", size, " bytes");
      }
   } else {
      Print("Backup File: Not found");
   }
   
   if(FileIsExist(FILE_LOGS)) {
      int handle = FileOpen(FILE_LOGS, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle != INVALID_HANDLE) {
         ulong size = FileSize(handle);
         FileClose(handle);
         Print("Log File: ", FILE_LOGS, " | Size: ", size, " bytes");
      }
   } else {
      Print("Log File: Not found");
   }
   
   Print("===================================================");
}

//+------------------------------------------------------------------+