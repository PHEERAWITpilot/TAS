# TAS TRUCK SIMULATOR - SIMULATION SPECIFICATION v1
## Safety & Grounding Compliance Enabled

**Document Version:** 1.0  
**Status:** Ready for CODESYS ST Implementation  
**Start Date:** 2026-03-01  
**Simulation Duration:** 30 days  
**Generated:** May 13, 2026  

---

## TABLE OF CONTENTS
1. [Overview](#overview)
2. [Assumptions](#assumptions)
3. [Entity Definitions](#entity-definitions)
4. [State Definitions](#state-definitions)
5. [Random Distributions](#random-distributions)
6. [Routing & Assignment Rules](#routing--assignment-rules)
7. [Failure Model](#failure-model)
8. [Output Files & Schemas](#output-files--schemas)
9. [Implementation Checklist](#implementation-checklist)
10. [CODESYS ST Variable Structures](#codesys-st-variable-structures)

---

## OVERVIEW

### Purpose
Generate synthetic TAS (Truck Arrivals & Safety) data for 30 days with:
- **Safety focus**: Grounding compliance tracking
- **Realism**: Based on historical patterns (2022 data)
- **Operational detail**: Per-station timestamps, per-nozzle resolution, failure events
- **Validation**: Flow rates derived from realistic fill amounts and durations

### Key Philosophy
- **Historical parity**: Arrival patterns match real 2022 data
- **Causality**: Fill amounts → productive time → flow rate (not random)
- **Deterministic randomness**: Seeded for reproducibility
- **Multi-product design**: Diesel (83.8%) vs Gasohol95 (16.2%)
- **Vehicle realism**: 30-company fleet with royal vs normal customer tiers

---

## ASSUMPTIONS

### A. Fleet Size & Vehicle Pool

| Property | Value |
|----------|-------|
| Total companies | 30 |
| Royal (VIP) companies | 5 (companies 1–5) |
| Normal companies | 25 (companies 6–30) |
| Trucks per royal company | 12 vehicles |
| Trucks per normal company | 4 vehicles |
| **Total trucks in pool** | **5 × 12 + 25 × 4 = 160 vehicles** |

### B. Vehicle Reuse Rules
- Same vehicle can appear multiple times in simulation
- **Minimum cooldown**: 10 hours before same truck re-enters queue
- Prevents unrealistic quick turnarounds
- Enables recurring patterns like real fleets

### C. Product Mix
Based on historical analysis (2022):
- **Diesel**: 83.8% (2,584 trucks)
- **Gasohol95**: 16.2% (498 trucks)

### D. Simulation Clock
- **Start time**: 2026-03-01 00:00:00
- **Scan step**: 1 second (precise timestamp fidelity)
- **Duration**: 30 days (720 hours)
- **Stop condition**: Timestamp >= 2026-03-31 00:00:00

### E. Failure Model
- **MTTF (Mean Time To Failure)**: 150 hours per line
- **MTTR (Mean Time To Repair)**: 2 hours per line
- **Scope**: Nozzle-level, not full-line
- **Trigger**: Only during active filling (S3)
- **Resolution**: Paused trucks resume from remaining time

### F. Data Quality
- One row per station visit (completed)
- All timestamps in YYYY-MM-DD HH:MM:SS format
- Missing cells are empty (not null, not 0)
- All volumes in **liters**
- All times in **minutes**

---

## ENTITY DEFINITIONS

### Truck Entity (In-Memory Struct)

```
TruckEntity:
  TruckID                : INT (unique 1..3000+)
  CompanyID              : INT (1..30)
  VehicleNumber          : STRING (e.g., "สค.70-1234")
  ProductType            : ENUM {DIESEL, GASOHOL95}
  PONumber               : INT (200000000 + counter)
  ShipmentNumber         : INT (200000000 + counter)
  
  -- Timestamps --
  ArrivalTime            : TIMESTAMP
  GroundingStatus        : BOOL
  
  -- Current Location & State --
  CurrentStation         : ENUM {S1, S2, S3, S4, O1, EXIT}
  QueuePosition          : INT
  BayNumber              : INT (for S3 only: 0..3 diesel, 0..1 gasohol)
  
  -- Service Metrics --
  FillAmount             : REAL (liters)
  ProductiveFillTime     : REAL (minutes)
  DerivedFlowRate        : REAL (L/min) [calculated at exit]
  
  -- Failure State --
  IsFailurePaused        : BOOL
  FailurePauseStart      : TIMESTAMP
  FailurePauseEnd        : TIMESTAMP
  
  -- Complete?--
  CompletedAllStations   : BOOL
  DepartureTime          : TIMESTAMP
```

### Failure Event (In-Memory Struct)

```
FailureEvent:
  EventID                : INT (unique)
  ProductLine            : ENUM {L1_DIESEL, L2_GASOHOL95}
  FailureStart           : TIMESTAMP
  RepairEnd              : TIMESTAMP
  AffectedTruckCount     : INT
  PausedTruckList        : LIST of TruckID
```

### Company Master Data

```
CompanyMaster:
  CompanyID              : INT (1..30)
  CompanyName            : STRING
  Tier                   : ENUM {ROYAL, NORMAL}
  FleetSize              : INT (12 if royal, 4 if normal)
  PreferredProduct       : ENUM {DIESEL, GASOHOL95, MIXED}
```

---

## STATE DEFINITIONS

### Truck State Diagram

```
[CREATED]
   ↓
[ARRIVING] ← arrival time set, wait for S1 slot
   ↓
[IN_S1] ← S1 processing (arrival → start time)
   ↓
[IN_S2] ← S2 processing (arrival → start time)
   ↓
[QUEUED_S3] ← waiting for bay
   ↓
[GROUNDING] ← safety grounding period
   ↓
[FILLING] ← active fuel transfer (fill start → end time)
   ↓ [if failure during filling]
[FILLING_PAUSED] ← fault pause, resume later
   ↓
[IN_S4] ← S4 processing
   ↓
[IN_O1] ← exit gate
   ↓
[DEPARTED] ← left facility (departure time set)
```

### Line Failure State

```
[OPERATIONAL]
   ↓ [MTTF timer expires]
[FAILURE] ← all active fills on line pause
   ↓ [MTTR timer expires]
[OPERATIONAL]
```

### Queue State (per station)

```
[EMPTY] or [n TRUCKS WAITING]
```

---

## RANDOM DISTRIBUTIONS

### 1. Truck Arrival Distribution (Hourly by Product)

**Data source**: Historical 2022 analysis  
**Method**: Poisson with hourly rate parameter

#### Diesel Arrivals (83.8% of total fleet)

| Hour | Trucks | % | Rate (trucks/day) | Notes |
|------|--------|---|-------------------|-------|
| 00–05 | 311 | 12.0% | Low nightshift |
| 06–09 | 538 | 20.8% | Morning ramp-up |
| 10–15 | 1050 | 40.6% | **PEAK (daytime)** |
| 16–19 | 350 | 13.5% | Evening decline |
| 20–23 | 36 | 1.4% | Near-closed |
| **Daily average** | **86 trucks/day** | | | |

**Recommended implementation**:
```
For each hour H (0–23):
  λ_H = hourly_diesel_lambda[H]  (from above table)
  arrivals = Poisson(λ_H)
  for each arrival:
    ProductType = DIESEL
    select random vehicle from diesel pool
```

#### Gasohol95 Arrivals (16.2% of total fleet)

| Hour | Trucks | % | Rate (trucks/day) | Notes |
|------|--------|---|-------------------|-------|
| 00–01 | 91 | 18.3% | Night loading |
| 02–05 | 39 | 7.8% | Low trough |
| 06–09 | 123 | 24.7% | Morning peak |
| 10–15 | 181 | 36.3% | **DAYTIME PEAK** |
| 16–19 | 43 | 8.6% | Evening decline |
| 20–23 | 2 | 0.4% | Closed |
| **Daily average** | **17 trucks/day** | | | |

**Recommended implementation**: Same Poisson method.

---

### 2. Service Time Distributions (S1, S2, S4)

**Data source**: Historical 2022 analysis (arrival → start time)  
**Method**: Triangular distribution for realism

#### S1 (SALES OFFICE) Service Time

| Statistic | Value | Notes |
|-----------|-------|-------|
| Mean | 9.27 min | |
| Median | 3.27 min | Heavy skew left |
| Std | 13.04 min | |
| 5th percentile | 0.00 min | Many pass-through |
| 25th percentile | 0.00 min | |
| 50th percentile | 3.27 min | |
| 75th percentile | 13.74 min | |
| 95th percentile | 38.86 min | Rare long queues |

**Triangular fit**: min=0, mode=3, max=40 minutes

**CODESYS formula**:
```
S1_ServiceTime := TRIANGULAR(0, 3, 40)  // in minutes
```

#### S2 (INBOUND WEIGHBRIDGE) Service Time

| Statistic | Value | Notes |
|-----------|-------|-------|
| Mean | 28.18 min | **Heavy processing** |
| Median | 21.70 min | |
| Std | 26.38 min | High variance |
| 5th percentile | 0.00 min | |
| 25th percentile | 5.47 min | |
| 50th percentile | 21.70 min | |
| 75th percentile | 45.31 min | |
| 95th percentile | 76.53 min | Long tail |

**Triangular fit**: min=0, mode=22, max=80 minutes

**CODESYS formula**:
```
S2_ServiceTime := TRIANGULAR(0, 22, 80)  // in minutes
```

#### S4 (OUTBOUND WEIGHBRIDGE) Service Time

| Statistic | Value | Notes |
|-----------|-------|-------|
| Mean | 3.74 min | Quick |
| Median | 1.67 min | Heavy left skew |
| Std | 4.76 min | |
| 5th percentile | 0.00 min | Pass-through |
| 25th percentile | 0.00 min | |
| 50th percentile | 1.67 min | |
| 75th percentile | 6.38 min | |
| 95th percentile | 13.35 min | |

**Triangular fit**: min=0, mode=2, max=15 minutes

**CODESYS formula**:
```
S4_ServiceTime := TRIANGULAR(0, 2, 15)  // in minutes
```

---

### 3. Grounding Time Distribution (S3)

**Purpose**: Safety compliance check before filling  
**Method**: Triangular distribution (user-specified)

| Parameter | Value |
|-----------|-------|
| Min | 3 min |
| Mode | 4 min |
| Max | 6 min |

**Validation**: From historical data, 100% of grounding times (post-enhancement) fall in [3, 6] range.

**CODESYS formula**:
```
GroundingTime := TRIANGULAR(3, 4, 6)  // in minutes
```

---

### 4. Fill Amount Distribution (S3)

**Purpose**: Determine truck load  
**Method**: Triangular by product (derived from historical medians)

#### Diesel (S3a)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Min | 6,000 L | 5th percentile |
| Mode | 9,612 L | Historical median |
| Max | 12,000 L | 95th percentile + buffer |

**CODESYS formula**:
```
if ProductType == DIESEL:
  FillAmount := TRIANGULAR(6000, 9612, 12000)  // liters
```

**Validation**: Mean ~8,900 L (matches historical).

#### Gasohol95 (S3b)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Min | 6,000 L | 5th percentile |
| Mode | 9,635 L | Historical median |
| Max | 11,000 L | 95th percentile |

**CODESYS formula**:
```
if ProductType == GASOHOL95:
  FillAmount := TRIANGULAR(6000, 9635, 11000)  // liters
```

**Validation**: Mean ~9,300 L (matches historical).

---

### 5. Productive Fill Time (S3)

**Purpose**: Time spent actively transferring fuel (fill start → end time)  
**Method**: Derived from historical data, no random generation needed

**Historical observation**:
- Diesel: mean 41.86 min, std 4.74 min
- Gasohol95: mean 42.07 min, std 6.17 min

**Simple model (Option A)**:
```
ProductiveFillTime := 41 to 44 minutes (approximately)
  (could add small triangular variance if desired)
```

**Or derive from flow rate**:
```
ProductiveFillTime := FillAmount / TargetFlowRate
where TargetFlowRate ≈ 200–210 L/min (historical median ≈ 220)
```

**CODESYS formula** (simple):
```
ProductiveFillTime := TRIANGULAR(38, 42, 46)  // minutes
```

---

### 6. Actual Flow Rate (S3)

**Derivation**: NOT independently generated  
**Formula**:
```
DerivedFlowRate := FillAmount / ProductiveFillTime  [L/min]
```

**Validation**: Historically, median ~220 L/min (both products).

**Why this works**:
- Fill amount is independent (triangular)
- Productive time is independent (triangular or fixed)
- Flow rate emerges naturally
- No need to add MTTF/MTTR effects to fill time directly

---

### 7. MTTF & MTTR (Failure Recovery)

**Method**: Historical intervals, one failure per 150-hour cycle

#### Diesel Line (L1)

| Parameter | Value |
|-----------|-------|
| MTTF | 150 hours = 9,000 minutes |
| MTTR | 2 hours = 120 minutes |

**CODESYS logic**:
```
if L1_OperationalTime >= 9000:
  L1_Status := FAILURE
  all active S3a fills pause
  FailureResumeTime := now + 120 min
  L1_OperationalTime := 0
```

#### Gasohol95 Line (L2)

| Parameter | Value |
|-----------|-------|
| MTTF | 150 hours = 9,000 minutes |
| MTTR | 2 hours = 120 minutes |

**Same logic as L1**.

---

### 8. Nozzle Capacity (S3)

#### S3a (Diesel)
- **Physical bays**: 2 parallel filling positions
- **Nozzles per bay**: 2 (total 4 nozzles)
- **Modeling**: 4 parallel slots, FIFO queue

#### S3b (Gasohol95)
- **Physical bays**: 2 parallel filling positions
- **Nozzles per bay**: 1 (total 2 nozzles)
- **Modeling**: 2 parallel slots, FIFO queue

**Queue logic**:
```
if available_slot > 0:
  assign next truck from FIFO queue to slot
  truck state := IN_S3
else:
  truck remains in QUEUED_S3
  wait for next slot liberation
```

---

## ROUTING & ASSIGNMENT RULES

### Station Sequence (Fixed)

Every truck visits:
```
S1 (Sales) → S2 (Inbound WB) → S3 (Fill) → S4 (Outbound WB) → O1 (Exit)
```

**No branching or shortcuts.**

### Product-to-Line Routing

```
if ProductType == DIESEL:
  route to S3a (bays 0–1, nozzles 0–3)
else:
  route to S3b (bays 0–1, nozzles 0–1)
```

### Queue Assignment

**Rule: Strict FIFO within product queue.**

```
S3a_FIFOQueue = []  # Diesel trucks waiting
S3b_FIFOQueue = []  # Gasohol95 trucks waiting

every scan step:
  for each free S3a slot:
    if S3a_FIFOQueue not empty:
      truck = S3a_FIFOQueue.pop(0)
      assign to slot
  
  for each free S3b slot:
    if S3b_FIFOQueue not empty:
      truck = S3b_FIFOQueue.pop(0)
      assign to slot
```

### Other Stations (S1, S2, S4, O1)

**Single-server model** (one truck per hour on average, but parallel queueing allowed):
```
S1_Queue = []
every scan:
  if S1_free and S1_Queue not empty:
    truck = S1_Queue.pop(0)
    S1 service start
    end time = now + S1_ServiceTime
```

**Same for S2, S4, O1.**

---

## FAILURE MODEL

### Failure Generation

**Per line (L1 diesel, L2 gasohol95)**:

```
L1_OperationalTime := 0
L1_Status := OPERATIONAL
L1_NextFailureTime := now + MTTF (150 hours)

// Each scan:
if L1_Status == OPERATIONAL:
  L1_OperationalTime += ScanStep
  if L1_OperationalTime >= 9000 minutes:
    L1_Status := FAILURE
    FailureStart := now
    FindAllActiveS3aTrucks()
    for each truck:
      truck.IsFailurePaused := TRUE
      truck.FailurePauseStart := now
    RepairEndTime := now + 120 minutes

if L1_Status == FAILURE:
  if now >= RepairEndTime:
    L1_Status := OPERATIONAL
    L1_OperationalTime := 0
    for each paused truck:
      truck.IsFailurePaused := FALSE
      truck.FailurePauseEnd := now
      // Remaining fill time to complete
```

### Failure Effects

**When L1 fails**:
- All trucks currently in S3a fill state pause
- New S3a assignments blocked
- Queue backs up
- Trucks resume from remaining fill time after repair

**When L2 fails**:
- All trucks currently in S3b fill state pause
- New S3b assignments blocked
- Same resume logic

**Output**:
- `l1_diesel_failure.csv` records each failure event
- `l2_gasohol95_failure.csv` records each failure event

---

## OUTPUT FILES & SCHEMAS

### File 1: db_truck.csv
**Purpose**: Master truck master registry  
**One row per truck**

| Column | Type | Example | Notes |
|--------|------|---------|-------|
| vehicle_id | INT | 1 | Unique 1..160 |
| company_id | INT | 3 | 1..30 |
| vehicle_number | STRING | สค.70-1234 | Thai plate format |
| fleet_tier | STRING | ROYAL or NORMAL | |
| preferred_product | STRING | DIESEL | |
| last_exit_time | TIMESTAMP | 2026-03-15 14:30:00 | For cooldown tracking |

---

### File 2: s1_sales_office.csv
**Purpose**: Sales office check-in  
**One row per truck visit to S1**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| po_number | INT | 200000001 | Shipment ID |
| vehicle_number | STRING | สค.70-1234 | |
| arrival_time | TIMESTAMP | 2026-03-01 07:15:30 | Queue join |
| start_time | TIMESTAMP | 2026-03-01 07:18:45 | Processing start |
| departure_time | TIMESTAMP | 2026-03-01 07:22:10 | Left S1 |

**Service time** = start_time − arrival_time

---

### File 3: s2_inbound_wb.csv
**Purpose**: Inbound weighbridge (before fuel)  
**One row per truck visit to S2**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| po_number | INT | 200000001 | Shipment ID |
| vehicle_number | STRING | สค.70-1234 | |
| arrival_time | TIMESTAMP | 2026-03-01 07:22:10 | Queue join |
| start_time | TIMESTAMP | 2026-03-01 07:25:00 | Weighing start |
| departure_time | TIMESTAMP | 2026-03-01 07:52:30 | Left S2 |

---

### File 4: s3a_diesel_bay.csv
**Purpose**: Diesel bay filling (safety + throughput detail)**  
**One row per diesel truck filled**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| po_number | INT | 200000001 | Shipment ID |
| vehicle_number | STRING | สค.70-1234 | |
| arrival_time | TIMESTAMP | 2026-03-01 07:52:30 | Queue join |
| start_time | TIMESTAMP | 2026-03-01 08:10:00 | Grounding start |
| grounding_time | REAL | 4.25 | minutes, Triangular(3,4,6) |
| fill_start | TIMESTAMP | 2026-03-01 08:14:15 | Actual fuel flow begins |
| end_time | TIMESTAMP | 2026-03-01 08:55:00 | Fuel transfer complete |
| departure_time | TIMESTAMP | 2026-03-01 08:55:05 | Left bay |
| fill_amount | REAL | 9612 | liters, Triangular(6000,9612,12000) |
| average_flow_rate | REAL | 219.87 | L/min = fill_amount / (end_time - fill_start) |

---

### File 5: s3b_gasohol95_bay.csv
**Purpose**: Gasohol95 bay filling  
**One row per gasohol95 truck filled**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| po_number | INT | 200000001 | Shipment ID |
| vehicle_number | STRING | สค.70-1234 | |
| arrival_time | TIMESTAMP | 2026-03-01 10:30:00 | Queue join |
| start_time | TIMESTAMP | 2026-03-01 10:45:00 | Grounding start |
| grounding_time | REAL | 4.10 | minutes, Triangular(3,4,6) |
| fill_start | TIMESTAMP | 2026-03-01 10:49:06 | Fuel flow begins |
| end_time | TIMESTAMP | 2026-03-01 11:31:00 | Transfer complete |
| departure_time | TIMESTAMP | 2026-03-01 11:31:10 | Left bay |
| fill_amount | REAL | 9635 | liters, Triangular(6000,9635,11000) |
| average_flow_rate | REAL | 221.05 | L/min = fill_amount / (end_time - fill_start) |

---

### File 6: s4_outbound_wb.csv
**Purpose**: Outbound weighbridge (after fuel)  
**One row per truck visit to S4**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| po_number | INT | 200000001 | Shipment ID |
| vehicle_number | STRING | สค.70-1234 | |
| arrival_time | TIMESTAMP | 2026-03-01 08:55:05 | From S3 |
| start_time | TIMESTAMP | 2026-03-01 08:58:00 | Weighing start |
| departure_time | TIMESTAMP | 2026-03-01 09:03:30 | Left S4 |

---

### File 7: o1_exit_gate.csv
**Purpose**: Exit gate final check  
**One row per truck exiting**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| po_number | INT | 200000001 | Shipment ID |
| vehicle_number | STRING | สค.70-1234 | |
| arrival_time | TIMESTAMP | 2026-03-01 09:03:30 | From S4 |
| departure_time | TIMESTAMP | 2026-03-01 09:05:00 | Final exit |

---

### File 8: l1_diesel_failure.csv
**Purpose**: Diesel line failure events  
**One row per failure**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| failure_id | INT | 1 | Unique per line |
| failure_start | TIMESTAMP | 2026-03-05 14:22:00 | When breakdown began |
| repair_end | TIMESTAMP | 2026-03-05 16:22:00 | When repairs finished (MTTR=120 min) |
| affected_trucks | INT | 3 | Trucks paused during failure |

---

### File 9: l2_gasohol95_failure.csv
**Purpose**: Gasohol95 line failure events  
**One row per failure**

| Column | Type | Format | Notes |
|--------|------|--------|-------|
| failure_id | INT | 1 | Unique per line |
| failure_start | TIMESTAMP | 2026-03-08 10:15:00 | When breakdown began |
| repair_end | TIMESTAMP | 2026-03-08 12:15:00 | When repairs finished (MTTR=120 min) |
| affected_trucks | INT | 2 | Trucks paused during failure |

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Data Structures
- [ ] Define TruckEntity struct in CODESYS ST
- [ ] Define FailureEvent struct
- [ ] Define CompanyMaster lookup table
- [ ] Define 4 global queues: S1, S2, S3a_diesel, S3b_gasohol95, S4, O1

### Phase 2: Random Number Generation
- [ ] Implement TRIANGULAR(min, mode, max) function
- [ ] Implement Poisson(lambda) function for arrivals
- [ ] Set seed for reproducibility
- [ ] Test distributions match expected histograms

### Phase 3: Initialization
- [ ] Load company master (30 companies, vehicle pools)
- [ ] Calculate hourly lambda values for diesel & gasohol arrivals
- [ ] Initialize failure timers for L1 and L2
- [ ] Create global clock (start 2026-03-01 00:00:00)

### Phase 4: Main Simulation Loop
- [ ] Truck arrival generation (hourly Poisson by product)
- [ ] Vehicle pool assignment (with 10-hour cooldown check)
- [ ] Station queue management (S1, S2, S4, O1)
- [ ] Service time sampling (S1, S2, S4)
- [ ] S3 bay management (parallel slots, FIFO assignment)
- [ ] Grounding time + fill start time calculation
- [ ] Fill amount + productive fill time sampling
- [ ] Failure event generation & truck pause/resume logic
- [ ] Timestamp recording at all state transitions

### Phase 5: Output Writing
- [ ] Write db_truck.csv at end of simulation
- [ ] Write s1_sales_office.csv (one row per completion)
- [ ] Write s2_inbound_wb.csv (one row per completion)
- [ ] Write s3a_diesel_bay.csv (one row per completion)
- [ ] Write s3b_gasohol95_bay.csv (one row per completion)
- [ ] Write s4_outbound_wb.csv (one row per completion)
- [ ] Write o1_exit_gate.csv (one row per completion)
- [ ] Write l1_diesel_failure.csv (one row per failure)
- [ ] Write l2_gasohol95_failure.csv (one row per failure)

### Phase 6: Validation
- [ ] Check total trucks ≈ expected (daily avg 103)
- [ ] Check product split ≈ 83.8% diesel, 16.2% gasohol95
- [ ] Check grounding times 100% in [3, 6]
- [ ] Check fill amounts match triangular distributions
- [ ] Check flow rates 200–230 L/min
- [ ] Check no duplicate vehicle+timestamp pairs
- [ ] Check all timestamps ordered chronologically
- [ ] Check failure event frequency (≈ 1 per 150 hours per line)

---

## CODESYS ST VARIABLE STRUCTURES

### 1. Global Constants

```codesys
CONST
  (* Simulation parameters *)
  SIM_START_DATE        : DATE := DATE#2026-03-01;
  SIM_START_TIME        : TIME_OF_DAY := TIME#00:00:00;
  SIM_DURATION_DAYS     : INT := 30;
  SCAN_STEP_SECONDS     : INT := 1;
  
  (* Fleet parameters *)
  TOTAL_COMPANIES       : INT := 30;
  ROYAL_COMPANIES       : INT := 5;
  NORMAL_COMPANIES      : INT := 25;
  TRUCKS_PER_ROYAL      : INT := 12;
  TRUCKS_PER_NORMAL     : INT := 4;
  TOTAL_VEHICLES        : INT := 160;  (* 5*12 + 25*4 *)
  VEHICLE_COOLDOWN_MIN  : INT := 600;  (* 10 hours in minutes *)
  
  (* Failure parameters *)
  MTTF_HOURS            : INT := 150;
  MTTF_MINUTES          : INT := 9000;  (* 150 * 60 *)
  MTTR_MINUTES          : INT := 120;
  
  (* S3 bay capacities *)
  S3A_SLOTS             : INT := 4;     (* 2 bays × 2 nozzles *)
  S3B_SLOTS             : INT := 2;     (* 2 bays × 1 nozzle *)
  
  (* Distribution parameters *)
  GROUNDING_MIN         : REAL := 3.0;
  GROUNDING_MODE        : REAL := 4.0;
  GROUNDING_MAX         : REAL := 6.0;
  
  (* Fill amounts *)
  DIESEL_FILL_MIN       : REAL := 6000.0;
  DIESEL_FILL_MODE      : REAL := 9612.0;
  DIESEL_FILL_MAX       : REAL := 12000.0;
  
  GASOHOL_FILL_MIN      : REAL := 6000.0;
  GASOHOL_FILL_MODE     : REAL := 9635.0;
  GASOHOL_FILL_MAX      : REAL := 11000.0;
END_CONST
```

### 2. Truck Entity Structure

```codesys
TYPE TruckEntity :
  STRUCT
    TruckID               : UDINT;
    CompanyID             : INT;
    VehicleNumber         : STRING[20];
    ProductType           : (DIESEL, GASOHOL95);  (* ENUM *)
    PONumber              : DINT;
    ShipmentNumber        : DINT;
    
    (* Timestamps *)
    ArrivalTime           : DT;      (* DATETIME *)
    DepartureTime         : DT;
    GroundingStatus       : BOOL;    (* Compliant? *)
    
    (* Current state *)
    CurrentStation        : (S1, S2, S3, S4, O1, EXIT, UNKNOWN);
    QueuePosition         : INT;
    BayNumber             : INT;     (* 0–3 for S3a, 0–1 for S3b *)
    
    (* Metrics *)
    FillAmount            : REAL;    (* liters *)
    ProductiveFillTime    : REAL;    (* minutes *)
    DerivedFlowRate       : REAL;    (* L/min *)
    
    (* Failure *)
    IsFailurePaused       : BOOL;
    FailurePauseStart     : DT;
    FailurePauseEnd       : DT;
    
    (* Completion *)
    CompletedAllStations  : BOOL;
  END_STRUCT
END_TYPE
```

### 3. Global Variables

```codesys
VAR_GLOBAL
  (* Clock *)
  SimulationTime        : DT := DT#2026-03-01-00:00:00;
  SimulationRunning     : BOOL := FALSE;
  
  (* Fleet *)
  VehiclePool[160]      : STRING;    (* vehicle numbers *)
  LastUseTime[160]      : DT;        (* for 10-hour cooldown *)
  
  (* Queues *)
  S1_Queue              : ARRAY[0..1000] OF UDINT;
  S1_QueueLen           : INT := 0;
  
  S2_Queue              : ARRAY[0..1000] OF UDINT;
  S2_QueueLen           : INT := 0;
  
  S3a_Queue             : ARRAY[0..1000] OF UDINT;
  S3a_QueueLen          : INT := 0;
  
  S3b_Queue             : ARRAY[0..1000] OF UDINT;
  S3b_QueueLen          : INT := 0;
  
  S4_Queue              : ARRAY[0..1000] OF UDINT;
  S4_QueueLen           : INT := 0;
  
  O1_Queue              : ARRAY[0..1000] OF UDINT;
  O1_QueueLen           : INT := 0;
  
  (* Active trucks in facility *)
  AllTrucks             : ARRAY[1..10000] OF TruckEntity;
  TruckCount            : UDINT := 0;
  
  (* S3 Bay States *)
  S3a_BayOccupied[0..3] : BOOL;      (* occupied flags *)
  S3a_TruckInBay[0..3]  : UDINT;     (* truck IDs *)
  
  S3b_BayOccupied[0..1] : BOOL;
  S3b_TruckInBay[0..1]  : UDINT;
  
  (* Failure states *)
  L1_Status             : (OPERATIONAL, FAILURE);
  L1_OperationalTime    : INT := 0;  (* minutes *)
  L1_FailureStart       : DT;
  L1_FailureEnd         : DT;
  L1_FailureCount       : INT := 0;
  
  L2_Status             : (OPERATIONAL, FAILURE);
  L2_OperationalTime    : INT := 0;
  L2_FailureStart       : DT;
  L2_FailureEnd         : DT;
  L2_FailureCount       : INT := 0;
  
  (* Output counters *)
  S1_CompletedCount     : INT := 0;
  S2_CompletedCount     : INT := 0;
  S3a_CompletedCount    : INT := 0;
  S3b_CompletedCount    : INT := 0;
  S4_CompletedCount     : INT := 0;
  O1_CompletedCount     : INT := 0;
END_VAR
```

### 4. Random Number Function (Triangular)

```codesys
FUNCTION TRIANGULAR : REAL
VAR_INPUT
  min_val               : REAL;
  mode_val              : REAL;
  max_val               : REAL;
END_VAR
VAR
  u                     : REAL;
  F_mode                : REAL;
END_VAR

  u := RAND();  (* 0.0 to 1.0 *)
  F_mode := (mode_val - min_val) / (max_val - min_val);
  
  IF u < F_mode THEN
    TRIANGULAR := min_val + SQRT(u * (max_val - min_val) * (mode_val - min_val));
  ELSE
    TRIANGULAR := max_val - SQRT((1.0 - u) * (max_val - min_val) * (max_val - mode_val));
  END_IF;
END_FUNCTION
```

### 5. Hourly Lambda Values (for Poisson arrivals)

```codesys
VAR_GLOBAL CONSTANT
  (* Diesel arrivals per hour *)
  DIESEL_LAMBDA : ARRAY[0..23] OF INT := 
    [3, 4, 2, 2, 2, 1, 4, 9, 9, 9, 7, 8, 8, 9, 8, 8, 7, 5, 3, 2, 0, 0, 0, 0];
  
  (* Gasohol95 arrivals per hour *)
  GASOHOL_LAMBDA : ARRAY[0..23] OF INT := 
    [3, 2, 0, 1, 1, 0, 1, 1, 1, 2, 4, 3, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
END_VAR
```

---

## FINAL NOTES

1. **Reproducibility**: Set random seed at simulation start for deterministic behavior.
2. **File I/O**: Use CSV writer utility; ensure UTF-8 encoding for Thai characters.
3. **Validation**: Compare generated data distribution histograms against historical data.
4. **Performance**: 1-second scan step over 30 days = 2.592M scans; optimize state updates.
5. **Documentation**: Include this specification in simulator repository for future maintenance.

---

**End of Simulation Specification v1**
