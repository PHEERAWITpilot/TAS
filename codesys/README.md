(*
================================================================================
README.md - CODEsys Fuel Distribution Simulation System
================================================================================

Complete implementation of a discrete-event fuel distribution simulation
for a network of stations with product-specific processing lines.

## System Overview

This simulation models a multi-station fuel distribution network with:
- **Truck arrivals** based on hourly Poisson processes
- **Multi-stage processing** through 5 stations (S1, S2, S3A/B, S4, O1)
- **Parallel processing** with product-based lane segregation
- **Line failure simulation** with MTTR-based repair cycles
- **Event-based data export** for analysis

## Architecture

### Components

1. **Types.st**
   - Enumerations: E_ProductType, E_TruckState, E_LineStatus, E_CompanyTier
   - Structures: ST_Truck, ST_LineFailure, ST_Server
   - Event types: ST_S1_Event, ST_S2_Event, ST_S3_Event, ST_S4_Event, ST_O1_Event, ST_LineFailure_Event

2. **Globals.st**
   - Simulation constants and configuration
   - Global state arrays (trucks, servers, queues)
   - Event export buffers (9 CSV output buffers)
   - Arrival rate distributions (lambda by hour)

3. **RandomUtils.st**
   - TRIANGULAR(min, mode, max) - Triangular distribution sampling
   - POISSON(lambda) - Poisson distribution for arrivals

4. **QueueUtils.st**
   - Circular queue operations (Enqueue, Dequeue, QueueSize)
   - Queue state checking (IsEmpty, IsFull)

5. **SimulationCore.st**
   - Core utilities (GeneratePO, GenerateShipment, GetHourOfDay)
   - Service time samplers (GetServiceTimeS1, S2, S4)
   - Fill amount generation (GetFillAmountByProduct)
   - Time utilities (AddMinutesToDateTime, GetMinutesBetween)

6. **QueueManagement.st**
   - Queue processing for each station
   - Server allocation logic
   - FIFO assignment with server availability checking

7. **ServerProcessing.st**
   - S1 server updates (2 parallel)
   - S2 server updates (1 sequential)
   - S4 server updates (1 sequential)
   - Event recording on completion

8. **S3Processing.st**
   - S3A/S3B parallel server updates (4 diesel / 2 gasohol slots)
   - Grounding → Filling state transitions
   - Line failure pause/resume logic
   - Fill amount and flow rate calculation

9. **LineFailureManagement.st**
   - Line failure triggering (based on fill-time accumulation)
   - Repair cycle management (MTTR-based)
   - Fill-time accumulation (ONLY when HasActiveFills = TRUE)
   - Failure event recording

10. **O1_Processing.st**
    - Outlet immediate departure
    - Total cycle time calculation
    - Truck departure event recording

11. **DataExport.st**
    - Event buffer management
    - CSV export framework
    - Truck arrival recording

12. **PLC_PRG.st**
    - Main simulation loop
    - Arrival generation (hourly Poisson)
    - Queue processing orchestration
    - Server updates
    - Time advancement
    - Simulation termination logic

## Processing Flow

### Truck Lifecycle (14 States)

```
TRUCK_CREATED
    ↓
TRUCK_QUEUED_S1 → TRUCK_IN_S1 → TRUCK_QUEUED_S2
    ↓
TRUCK_IN_S2 → TRUCK_QUEUED_S3
    ↓
TRUCK_GROUNDING (Waiting for grounding to complete)
    ↓
TRUCK_FILLING → TRUCK_FILLING_PAUSED (if line failure)
    ↓
TRUCK_QUEUED_S4 → TRUCK_IN_S4
    ↓
TRUCK_IN_O1 → TRUCK_DEPARTED
```

### Queue Processing Sequence

Each simulation tick (1 second = 1/60 minute):

1. **Generate Arrivals** - Hourly Poisson sampling
2. **Update Line Failures** - Check failure thresholds (fill-time only)
3. **Process Queues** - Assign trucks to available servers
4. **Update Servers** - Decrement service timers
5. **Advance Time** - Move to next simulation second
6. **Check Termination** - Export data if simulation ends

## Key Parameters

### Service Times (TRIANGULAR distribution)
- **S1**: min=0, mode=3, max=40 minutes
- **S2**: min=0, mode=22, max=80 minutes
- **S4**: min=0, mode=2, max=15 minutes
- **Grounding**: min=3, mode=4, max=6 minutes
- **Productive Fill**: min=38, mode=42, max=46 minutes

### Fill Amounts (TRIANGULAR distribution)
- **Diesel**: min=6000, mode=9612, max=12000 liters
- **Gasohol**: min=6000, mode=9635, max=11000 liters
- **Flow Rate**: FillAmount / ProductiveFillTime (≈220 L/min expected)

### Server Capacity
- **S1**: 2 parallel servers
- **S2**: 1 server
- **S3A** (Diesel): 4 slots with grounding + filling
- **S3B** (Gasohol): 2 slots with grounding + filling
- **S4**: 1 server
- **O1**: Immediate departure (no queue)

### Line Failure Parameters
- **Failure Threshold**: TRIANGULAR(7500, 9000, 10500) minutes (first failure)
- **MTTR**: TRIANGULAR(60, 120, 180) minutes per repair
- **Accumulation**: Only during active fills (HasActiveFills = TRUE)
- **Reset**: After repair, new threshold generated

### Simulation Time
- **Start**: 2026-03-01 00:00:00
- **End**: 2026-03-31 00:00:00
- **Duration**: 30 days continuous
- **Scan Step**: 1 second per tick

### Arrival Rates (Lambda by Hour)
```
Hour  0-5:   3, 4, 2, 2, 2, 1
Hour  6-11:  4, 9, 9, 9, 7, 8
Hour  12-17: 8, 9, 8, 8, 7, 5
Hour  18-23: 3, 2, 0, 0, 0, 0
```

## Data Export

### Output Files (9 CSV buffers, 665 KB total capacity)

1. **S1_Events.csv** - S1 processing completions
   - Columns: TruckID, VehicleNumber, ArrivalTime, StartTime, EndTime, ServiceTimeMin, QueueWaitMin

2. **S2_Events.csv** - S2 processing completions
   - Columns: TruckID, VehicleNumber, ArrivalTime, StartTime, EndTime, ServiceTimeMin, QueueWaitMin

3. **S3A_Events.csv** - S3A (Diesel) grounding & filling
   - Columns: TruckID, VehicleNumber, ProductType, ArrivalTime, GroundingStartTime, GroundingEndTime,
     GroundingTimeMin, FillStartTime, FillEndTime, FillTimeMin, FillAmountL,
     FlowRateLpm, GroundingStatus, FailurePaused, FailurePauseDurationMin

4. **S3B_Events.csv** - S3B (Gasohol) grounding & filling
   - Same columns as S3A

5. **S4_Events.csv** - S4 processing completions
   - Columns: TruckID, VehicleNumber, ArrivalTime, StartTime, EndTime, ServiceTimeMin, QueueWaitMin

6. **O1_Events.csv** - Truck departures
   - Columns: TruckID, VehicleNumber, DepartureTime, TotalCycleTimeMin

7. **L1_FailureEvents.csv** - Diesel line failures
   - Columns: LineID, FailureStartTime, RepairEndTime, FailureDurationMin, AffectedTruckCount

8. **L2_FailureEvents.csv** - Gasohol line failures
   - Columns: LineID, FailureStartTime, RepairEndTime, FailureDurationMin, AffectedTruckCount

9. **db_TruckRecords.csv** - Truck arrival records
   - Columns: TruckID, VehicleNumber, ProductType, PONumber, ShipmentNumber,
     CompanyID, S1_ArrivalTime, S2_ArrivalTime, S3_ArrivalTime, S4_ArrivalTime

## Critical Design Decisions

### 1. Fill-Time Accumulation (Line Failure)
- Accumulates **only when** HasActiveFills() = TRUE
- Does NOT accumulate during server idle time
- Ensures realistic line failure patterns

### 2. Grounding Status State Machine
- FALSE: In queue waiting for service
- TRUE: After grounding phase complete (during/after filling)
- CSV export shows TRUE (because records = post-fill)

**Detailed State Transitions:**
```
S3_ArrivalTime (truck enters queue)
  GroundingStatus := FALSE  (not grounded yet)
  
S3_GroundingStartTime (grounding begins)
  GroundingStatus := FALSE  (grounding in progress, not yet complete)
  
S3_FillStartTime = S3_GroundingStartTime + grounding_time
  GroundingStatus := TRUE  (grounding now locked; fill safe)
  
S3_FillEndTime (and beyond, including pauses/resumes)
  GroundingStatus := TRUE  (remains TRUE; compliance maintained)
```

### 3. Server Allocation (S1 vs S2/S4)
- **S1**: 2 parallel servers → FIFO to each
- **S2/S4**: 1 sequential server → FIFO queue
- **S3**: Product-based segregation (4 diesel / 2 gasohol slots)

### 4. Line Failure Blocking
- S3 filling pauses during L1 (Diesel) failure
- S3 filling pauses during L2 (Gasohol) failure
- Pause start/end recorded in events
- Extends total fill time when failure occurs

### 5. Active Fill Counting
- ActiveFillCount_Diesel: incremented on S3A fill start, decremented on completion
- ActiveFillCount_Gasohol: incremented on S3B fill start, decremented on completion
- Used to determine if line failure accumulation should occur

### 6. O1 Immediate Exit
- No processing delay at O1 (exit gate)
- Trucks depart immediately upon arrival
- Total cycle time calculated as (O1_DepartureTime - S1_ArrivalTime)
- Event recorded to O1_Events buffer with cycle time metrics

### 7. Queue Wraparound & Circular Buffers
- All queues use circular buffer arrays (2500 slots)
- Head/Tail pointers manage FIFO order
- Wraparound logic: if pointer > 2500, wrap to 1
- Prevents memory fragmentation and handles continuous flow

## Integration Notes

This implementation is designed for CODEsys 3.5+ with IEC 61131-3 standard.

For CSV export to actual files:
- Use ADS interface to external application
- Or implement FileIO libraries in CODEsys
- Or use Real-Time Data Hub for external logging

All event data is buffered in global arrays (ST_*_Event types) during simulation
and can be exported via any communication mechanism at simulation termination.

## Expected Simulation Output

Over 30 days with ~6,000 truck arrivals:
- ~5,000+ completed trucks (some still in queue at end)
- 50-100 line failures (5-10 per line, 2-3 hour average duration)
- 0-5 queue overflow events
- Average cycle time: 300-400 minutes per truck
- Average queue wait: 20-50 minutes per station
- Flow rate stability: 210-230 L/min at S3

## Troubleshooting

### Excessive Queue Buildup
- Check S1 or S2 capacity (may need to increase)
- Check if arrival rates are too aggressive
- Monitor HasActiveFills() during peak hours

### Unrealistic Failure Rates
- Verify accumulation is only during active fills
- Check MTTR sampling (should be 60-180 minutes)
- Verify failure threshold is being reset properly

### Missing Events
- Check if event buffers are full (MAX_EVENTS = 10000)
- May need to export data more frequently
- Consider reducing simulation duration for testing

### Zero Departures at O1
- Verify S4 queue is processing correctly
- Check that trucks reach S4_EndTime status
- Ensure O1_Queue.Enqueue is called from S4 completion logic
- Monitor TotalDepartures counter incrementing

## File Compilation Order

When importing into CODEsys IDE, use this order:

1. Types.st (definitions first)
2. Globals.st (global state)
3. RandomUtils.st (utilities)
4. QueueUtils.st (queue operations)
5. SimulationCore.st (core helpers)
6. DataExport.st (event recording)
7. QueueManagement.st (queue processing)
8. ServerProcessing.st (server logic)
9. S3Processing.st (S3 operations)
10. LineFailureManagement.st (failure tracking)
11. O1_Processing.st (departure handling)
12. PLC_PRG.st (main loop - compile last)

## Performance Notes

- **Scan Rate**: 1 second per scan = 86,400 scans per day
- **Duration**: 30 days = 2,592,000 scans total
- **Event Buffer**: 9 buffers × 10,000 events = 90,000 max records
- **Cycle Time**: Expected 5-10 ms per scan on modern PLC hardware
- **Memory**: ~8 MB global state + queues + buffers

================================================================================
*)
