//+------------------------------------------------------------------+
//|                                             OrderManager.mqh      |
//|                    Gold Engulfing EA - Order Management System    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place All Orders for Setup (Main Function)                       |
//+------------------------------------------------------------------+
void PlaceOrders(EngulfingSetup &setup) {

   // Safety checks
   if(setup.firstTPHit) {
      Print("⚠️ Skipping order placement for Setup ID: ", setup.setupID, " - TP already hit!");
      return;
   }
   
   if(setup.setupComplete) {
      Print("⚠️ Skipping order placement for Setup ID: ", setup.setupID, " - Setup complete!");
      return;
   }
   
   // Calculate unified TP
   double rangeSize = setup.rangeHigh - setup.rangeLow;
   double pipValue = GetPipValue();

   double unifiedTP;
   if(setup.isBullish) {
      unifiedTP = setup.rangeHigh + (InpTPPips * pipValue);
   } else {
      unifiedTP = setup.rangeLow - (InpTPPips * pipValue);
   }
   unifiedTP = NormalizeDouble(unifiedTP, _Digits);

   // Print header
   if(InpEnableTableLogs) {
      Print("------------------------------------------------------------------------");
      Print(StringFormat("ORDERS for Setup %s (%s):", 
                        setup.setupID,
                        setup.isBullish ? "BULLISH" : "BEARISH"));
      Print(StringFormat("Range: %s to %s | TP: %s", 
                        DoubleToString(setup.rangeHigh, 3),
                        DoubleToString(setup.rangeLow, 3),
                        DoubleToString(unifiedTP, 3)));
   } else {
      Print("========================================");
      Print("📊 PLACING ORDERS - Setup ID: ", setup.setupID);
      Print("Direction: ", setup.isBullish ? "BULLISH (Buy Limits)" : "BEARISH (Sell Limits)");
      Print("========================================");
   }

   // Calculate zone boundaries
   double topZoneStart    = setup.rangeHigh;
   double topZoneEnd      = setup.rangeHigh - (rangeSize * 0.30);
   double midZoneStart    = topZoneEnd;
   double midZoneEnd      = setup.rangeLow + (rangeSize * 0.40);
   double bottomZoneStart = midZoneEnd;
   double bottomZoneEnd   = setup.rangeLow;

   ENUM_ORDER_TYPE orderType = setup.isBullish ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;

   // Place orders in each zone
   int ordersPlaced = 0;
   ordersPlaced += PlaceOrdersInZone(topZoneStart, topZoneEnd, InpTopZoneOrders, 
                                     orderType, setup.setupID, setup.magicNumber, unifiedTP);
   ordersPlaced += PlaceOrdersInZone(midZoneStart, midZoneEnd, InpMidZoneOrders, 
                                     orderType, setup.setupID, setup.magicNumber, unifiedTP);
   ordersPlaced += PlaceOrdersInZone(bottomZoneStart, bottomZoneEnd, InpBottomZoneOrders, 
                                     orderType, setup.setupID, setup.magicNumber, unifiedTP);

   // Update setup
   setup.ordersPlaced = ordersPlaced;
   g_totalActiveTrades += ordersPlaced;
   
   if(InpEnableTableLogs) {
      Print(StringFormat("Total: %d orders placed", ordersPlaced));
      Print("------------------------------------------------------------------------");
   } else {
      Print("✅ Successfully placed ", ordersPlaced, " orders with unified TP: ", unifiedTP);
   }
   
   // Send alert
   SendAlert(StringFormat("📊 %d orders placed for %s", ordersPlaced, setup.setupID));
}

//+------------------------------------------------------------------+
//| Place Orders in Specific Zone                                    |
//+------------------------------------------------------------------+
int PlaceOrdersInZone(double zoneHigh, double zoneLow, int numOrders, 
                      ENUM_ORDER_TYPE orderType, string setupID, int magicNumber, double unifiedTP) {
    
   double zoneSize = MathAbs(zoneHigh - zoneLow);
   double spacing = zoneSize / (numOrders + 1);
   double pipValue = GetPipValue();
   int placedCount = 0;

   if(!InpEnableTableLogs) {
      Print("--- Zone: ", zoneHigh, " to ", zoneLow, " (", numOrders, " orders) ---");
   }

   for(int i = 1; i <= numOrders; i++) {
      // Calculate entry price
      double price = (orderType == ORDER_TYPE_SELL_LIMIT) ? 
                     (zoneHigh - spacing * i) : 
                     (zoneLow + spacing * i);
      price = NormalizeDouble(price, _Digits);

      // Calculate SL
      double sl = (orderType == ORDER_TYPE_SELL_LIMIT) ? 
                  price + (InpSLPips * pipValue) : 
                  price - (InpSLPips * pipValue);
      sl = NormalizeDouble(sl, _Digits);

      double tp = unifiedTP;

      // Show profit potential
      if(!InpEnableTableLogs) {
         double profitPips = MathAbs(tp - price) / pipValue;
         double profitDollar = profitPips * 0.10;
         Print("  Order ", i, " | Entry: ", price, " | SL: ", sl, " | TP: ", tp, 
               " | Profit Potential: ", DoubleToString(profitPips, 1), " pips (≈$", 
               DoubleToString(profitDollar, 2), ")");
      }

      // Check if order already exists at this price
      if(!OrderExistsAtPrice(price, setupID)) {
         MqlTradeRequest request = {};
         MqlTradeResult  result  = {};
         
         request.action   = TRADE_ACTION_PENDING;
         request.symbol   = _Symbol;
         request.volume   = InpLotSize;
         request.type     = orderType;
         request.price    = price;
         request.sl       = sl;
         request.tp       = tp;
         request.deviation= 10;
         request.magic    = magicNumber;
         request.comment  = setupID;

         if(OrderSend(request, result)) {
            placedCount++;
            if(!InpEnableTableLogs) {
               Print("    ✓ Order placed successfully | Ticket: ", result.order);
            }
         } else {
            if(!InpEnableTableLogs) {
               int error = GetLastError();
               Print("    ✗ Order failed | Error: ", error, " - ", ErrorDescription(error));
            }
         }
      } else {
         if(!InpEnableTableLogs) {
            Print("    ⚠️ Order already exists at this price - skipping");
         }
      }
   }

   if(!InpEnableTableLogs) {
      Print("  Zone complete: ", placedCount, "/", numOrders, " orders placed");
   }
   return placedCount;
}

//+------------------------------------------------------------------+
//| Cancel All Pending Orders for Setup                              |
//+------------------------------------------------------------------+
int CancelPendingOrders(string setupID) {
   int cancelledCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetString(ORDER_COMMENT) != setupID) continue;
      
      MqlTradeRequest request = {};
      MqlTradeResult  result  = {};
      
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      
      if(OrderSend(request, result)) {
         cancelledCount++;
         DebugPrint(StringFormat("Cancelled order #%lld for setup: %s", ticket, setupID));
      } else {
         int error = GetLastError();
         Print("Failed to cancel order #", ticket, " | Error: ", error, " - ", ErrorDescription(error));
      }
   }
   
   if(cancelledCount > 0) {
      Print("🚫 Cancelled ", cancelledCount, " pending orders for setup: ", setupID);
   }
   
   return cancelledCount;
}

//+------------------------------------------------------------------+
//| Check Order Status for Setup (Update Execution Count)            |
//+------------------------------------------------------------------+
void UpdateOrderStatus(EngulfingSetup &setup) {
   int pendingCount = CountPendingOrders(setup.setupID);
   int executedCount = CountExecutedPositions(setup.setupID, setup.magicNumber);
   
   // Update setup
   setup.ordersExecuted = executedCount;
   
   DebugPrint(StringFormat("Setup %s | Placed: %d | Pending: %d | Executed: %d",
                          setup.setupID, setup.ordersPlaced, pendingCount, executedCount));
}

//+------------------------------------------------------------------+
//| Check if First TP Hit for Any Position in Setup                  |
//+------------------------------------------------------------------+
bool CheckFirstTPHit(EngulfingSetup &setup) {
   // Check closed positions in history
   if(!HistorySelect(setup.createdTime, TimeCurrent())) {
      return false;
   }
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != setup.magicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      
      // Check if it's an exit deal (not entry)
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         
         // Positive profit = TP hit (we assume, could also check DEAL_REASON)
         if(profit > 0) {
            DebugPrint(StringFormat("First TP hit detected for setup %s | Deal: #%lld | Profit: $%.2f",
                                   setup.setupID, ticket, profit));
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate Total Profit from Closed Positions                     |
//+------------------------------------------------------------------+
void CalculateSetupProfit(EngulfingSetup &setup) {
   double totalProfit = 0;
   int tpCount = 0;
   int slCount = 0;
   int closedCount = 0;
   
   if(!HistorySelect(setup.createdTime, TimeCurrent())) {
      return;
   }
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != setup.magicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      
      // Check if it's an exit deal
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         totalProfit += profit;
         closedCount++;
         
         if(profit > 0) {
            tpCount++;
         } else if(profit < 0) {
            slCount++;
         }
      }
   }
   
   setup.totalProfit = totalProfit;
   setup.tpCount = tpCount;
   setup.slCount = slCount;
   setup.ordersClosed = closedCount;
   
   DebugPrint(StringFormat("Setup %s Profit: $%.2f | TP: %d | SL: %d | Closed: %d",
                          setup.setupID, totalProfit, tpCount, slCount, closedCount));
}

//+------------------------------------------------------------------+
//| Check if All Orders Handled (Complete Condition)                 |
//+------------------------------------------------------------------+
bool AreAllOrdersHandled(EngulfingSetup &setup) {
   int pendingCount = CountPendingOrders(setup.setupID);
   int executedCount = CountExecutedPositions(setup.setupID, setup.magicNumber);
   
   // All orders handled = no pending orders AND no open positions
   return (pendingCount == 0 && executedCount == 0);
}

//+------------------------------------------------------------------+
//| Get Pending Order Tickets for Setup                              |
//+------------------------------------------------------------------+
void GetPendingOrderTickets(string setupID, ulong &tickets[]) {
   ArrayResize(tickets, 0);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
         OrderGetString(ORDER_COMMENT) == setupID) {
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }
}

//+------------------------------------------------------------------+
//| Get Open Position Tickets for Setup                              |
//+------------------------------------------------------------------+
void GetPositionTickets(int magicNumber, ulong &tickets[]) {
   ArrayResize(tickets, 0);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magicNumber) {
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }
}

//+------------------------------------------------------------------+