# Gold Engulfing EA - Project Brief

## Strategy Overview
- **Asset**: XAUUSD only
- **Timeframe**: H1 only
- **Pattern**: Engulfing candles (opposite colors)
- **Entry**: 10 limit orders across engulfed candle body (3-3-4 distribution)
- **Risk**: $4 SL per order, $8 TP per order (1:2 RR)
- **Position Size**: 0.01 lots per order
- **Gap Tolerance**: 2 pips (0.20 points)
- **Min Body Size**: 2 pips (engulfed candle)

## Core Logic Flow
1. **New H1 Bar** → Detect engulfing (bar 1 engulfs bar 2)
2. **Create Setup** → Time-based ID: "Engulf_DDMMYYYY-HHMM-D"
3. **Draw Lines** → Yellow dotted lines (UNTAPPED)
4. **Place Orders** → 10 limit orders across range
5. **Price Taps** → Lines turn RED (TAPPED)
6. **First TP Hit** → Cancel all remaining pending orders
7. **All Done** → Mark COMPLETE.
8. **14 Days Pass** → Mark limit orders EXPIRED if never tapped

## State Machine
```
UNTAPPED (yellow) → TAPPED (red) → COMPLETE (deleted)
                 ↓
             EXPIRED (14+ days)
```

## File Structure
```
GoldEngulfing_Main.mq5          # Orchestrator
├── Config.mqh                   # All inputs & EngulfingSetup struct
├── Utils.mqh                    # ID generation, pip value, helpers
├── EngulfingDetector.mqh       # DetectNewEngulfing(), IsBullish/Bearish
├── VisualManager.mqh           # DrawRangeLines(), RedrawTappedLines()
├── OrderManager.mqh            # PlaceOrders() (3-3-4), CancelPendingOrders()
├── SetupManager.mqh            # CheckUntappedSetups(), MarkAsTapped/Complete
├── StorageSystem.mqh           # JSON save/load (persistent memory)
└── TableLogger.mqh             # DisplayCandleTable() (336 bars)
```

## Key Data Structure
```cpp
struct EngulfingSetup {
   string setupID;              // "Engulf_13122025-1000-B"
   int magicNumber;             // Generated from ID
   datetime engulfingTime;      // Bar 1 time
   datetime engulfedTime;       // Bar 2 time
   datetime tappedTime;         // When price hit range
   double rangeHigh/Low;        // Engulfed candle body
   bool isBullish;
   int state;                   // 0=UNTAPPED, 1=TAPPED, 2=COMPLETE, 3=EXPIRED
   bool firstTPHit;             // Cancel rest when true
   int ordersPlaced/Executed/Closed;
   double totalProfit;
   // ... visual line names, performance tracking
}
```

## Critical Functions
- `DetectNewEngulfing()` → Returns setupID or ""
- `ProcessNewSetup(setupID)` → Create→Draw→Place Orders
- `CheckUntappedSetups()` → Monitor for price tap
- `CheckTappedSetups()` → Monitor for TP hits
- `PlaceOrders(setup)` → 3 top, 3 mid, 4 bottom zone
- `CancelPendingOrders(setupID)` → When first TP hits
- `SaveSetupsToFile()` → JSON persistence
- `LoadSetupsFromFile()` → Restore on restart

## Persistence (JSON Files)
- `GoldEngulfing_setups.json` → Current state
- `GoldEngulfing_backups.json` → History trail
- `GoldEngulfing_logs.json` → Event log

## Key Design Decisions
1. **Time-based IDs** → Bulletproof duplicate prevention
2. **First TP = Cancel Rest** → Risk management
3. **Manual close detection** → Also cancels rest
4. **State persistence** → Survives restarts
5. **Visual feedback** → Yellow (fresh) → Red (tapped)
6. **336-bar logging** → Full 14-day visibility

## Current Status
- Version: 2.0
- Status: [Testing/Production/Bug Fix/etc]
- Last Modified: [Date]
- Known Issues: [List any]

## Future Enhancements (TODO)
- [ ] Feature X
- [ ] Optimization Y
```
