# TAS SIMULATOR - IMPLEMENTATION DESIGN GUIDE
## Complete Breakdown of 7 Missing Components

**Date**: May 13, 2026  
**Based on**: SIMULATION_SPECIFICATION_v2.md  
**Target**: CODESYS ST (IEC 61131-3)

---

## TABLE OF CONTENTS
1. [Queue Management Logic](#1-queue-management-logic)
2. [Server Allocation & Service Time](#2-server-allocation--service-time-calculation)
3. [State Transition Logic](#3-state-transition-logic)
4. [Line Failure Triggering & Repair](#4-line-failure-triggering--repair-simulation)
5. [Fill Amount Calculations](#5-fill-amount-calculations)
6. [Grounding Status Logic](#6-grounding-status-logic)
7. [Data Export & Logging](#7-data-exportlogging-mechanisms)

---

## 1. QUEUE MANAGEMENT LOGIC

### Circular Buffer Design

**Goal**: Efficient FIFO queue for each station with fixed capacity (2500 slots)

```codesys
(* ===== CIRCULAR BUFFER HELPER FUNCTIONS ===== *)

FUNCTION Enqueue : BOOL
VAR_INPUT
  Queue : ARRAY OF UDINT;           (* Queue array *)
  Head : REFERENCE TO INT;          (* Current head pointer *)
  Tail : REFERENCE TO INT;          (* Current tail pointer *)
  Value : UDINT;                    (* Truck ID to enqueue *)
  MaxSize : INT;                    (* Buffer size *)
END_VAR
VAR
  NextTail : INT;
END_VAR

  NextTail := (Tail + 1) MOD MaxSize;
  
  (* Check for overflow *)
  IF NextTail = Head THEN
    LogError("Queue overflow");
    Enqueue := FALSE;
  ELSE
    Queue[Tail] := Value;
    Tail := NextTail;
    Enqueue := TRUE;
  END_IF;
END_FUNCTION

FUNCTION Dequeue : BOOL
VAR_INPUT
  Queue : ARRAY OF UDINT;
  Head : REFERENCE TO INT;
  Tail : REFERENCE TO INT;
  MaxSize : INT;
END_VAR
VAR_OUTPUT
  Value : UDINT;
END_VAR

  (* Check for empty *)
  IF Head = Tail THEN
    Dequeue := FALSE;
  ELSE
    Value := Queue[Head];
    Head := (Head + 1) MOD MaxSize;
    Dequeue := TRUE;
  END_IF;
END_FUNCTION

FUNCTION QueueSize : INT
VAR_INPUT
  Head : INT;
  Tail : INT;
  MaxSize : INT;
END_VAR

  IF Tail >= Head THEN
    QueueSize := Tail - Head;
  ELSE
    QueueSize := MaxSize - (Head - Tail);
  END_IF;
END_FUNCTION

FUNCTION IsQueueEmpty : BOOL
VAR_INPUT
  Head : INT;
  Tail : INT;
END_VAR

  IsQueueEmpty := (Head = Tail);
END_FUNCTION

FUNCTION IsQueueFull : BOOL
VAR_INPUT
  Head : INT;
  Tail : INT;
  MaxSize : INT;
END_VAR

  IsQueueFull := ((Tail + 1) MOD MaxSize = Head);
END_FUNCTION
```

### Usage Pattern in Main Loop

```codesys
(* ===== USAGE: ENQUEUE ON ARRIVAL ===== *)

PROCEDURE OnTruckArrival(TruckID : UDINT; ProductType : (DIESEL, GASOHOL95))
  IF ProductType = DIESEL THEN
    (* Route to S1 queue *)
    IF Enqueue(S1_Queue, S1_Head, S1_Tail, TruckID, 2500) THEN
      AllTrucks[TruckID].CurrentStation := S1;
      AllTrucks[TruckID].S1_ArrivalTime := SimulationTime;
    ELSE
      LogError("S1 Queue overflow - truck rejected");
    END_IF;
  ELSE (* GASOHOL95 *)
    IF Enqueue(S1_Queue, S1_Head, S1_Tail, TruckID, 2500) THEN
      AllTrucks[TruckID].CurrentStation := S1;
      AllTrucks[TruckID].S1_ArrivalTime := SimulationTime;
    ELSE
      LogError("S1 Queue overflow - truck rejected");
    END_IF;
  END_IF;
END_PROCEDURE

(* ===== USAGE: DEQUEUE & PROCESS ===== *)

PROCEDURE ProcessS1Queue()
VAR
  TruckID : UDINT;
  FreeServerIdx : INT := -1;
  i : INT;
END_VAR

  (* Find first free S1 server *)
  FOR i := 0 TO 1 DO  (* S1 has 2 parallel servers *)
    IF S1_ServerFree[i] THEN
      FreeServerIdx := i;
      EXIT;
    END_IF;
  END_FOR;
  
  (* If server free and queue not empty, start service *)
  IF FreeServerIdx >= 0 AND NOT IsQueueEmpty(S1_Head, S1_Tail) THEN
    IF Dequeue(S1_Queue, S1_Head, S1_Tail, 2500, TruckID) THEN
      (* Start service on this truck *)
      S1_ServerFree[FreeServerIdx] := FALSE;
      AllTrucks[TruckID].S1_StartTime := SimulationTime;
      (* Calculate service time end *)
      S1_ServerEndTime[FreeServerIdx] := 
        AddMinutes(SimulationTime, TRIANGULAR(0, 3, 40));
    END_IF;
  END_IF;
END_PROCEDURE

(* ===== USAGE: MOVE TO NEXT STATION ON COMPLETION ===== *)

PROCEDURE CompleteS1Service()
VAR
  ServerIdx : INT;
  TruckID : UDINT;
END_VAR

  FOR ServerIdx := 0 TO 1 DO
    IF NOT S1_ServerFree[ServerIdx] AND 
       SimulationTime >= S1_ServerEndTime[ServerIdx] THEN
      (* Find which truck was on this server *)
      TruckID := FindTruckInStation(S1);
      IF TruckID > 0 THEN
        (* Complete S1 *)
        AllTrucks[TruckID].S1_EndTime := SimulationTime;
        AllTrucks[TruckID].S1_DepartureTime := SimulationTime;
        
        (* Move to S2 *)
        AllTrucks[TruckID].CurrentStation := S2;
        IF Enqueue(S2_Queue, S2_Head, S2_Tail, TruckID, 2500) THEN
          AllTrucks[TruckID].S2_ArrivalTime := SimulationTime;
        END_IF;
        
        (* Free server *)
        S1_ServerFree[ServerIdx] := TRUE;
      END_IF;
    END_IF;
  END_FOR;
END_PROCEDURE
```

---

## 2. SERVER ALLOCATION & SERVICE TIME CALCULATION

### Parallel vs Single Server Logic

**S1**: 2 parallel servers  
**S2, S4**: 1 server each  
**S3a, S3b**: Multiple slots (4 and 2) with line failure blocking

```codesys
(* ===== SERVICE TIME SAMPLING ===== *)

FUNCTION SampleServiceTime : REAL
VAR_INPUT
  Station : INT;  (* 1=S1, 2=S2, 4=S4 *)
END_VAR

  CASE Station OF
    1: (* S1 - Sales Office *)
      SampleServiceTime := TRIANGULAR(0, 3, 40);     (* minutes *)
    2: (* S2 - Inbound WB *)
      SampleServiceTime := TRIANGULAR(0, 22, 80);    (* minutes *)
    4: (* S4 - Outbound WB *)
      SampleServiceTime := TRIANGULAR(0, 2, 15);     (* minutes *)
  ELSE
    SampleServiceTime := 0;
  END_CASE;
END_FUNCTION

(* ===== TWO-PARALLEL-SERVER LOGIC (S1) ===== *)

PROCEDURE ManageS1Servers()
VAR
  QueuedTruckID : UDINT;
  i : INT;
  ServiceMinutes : REAL;
END_VAR

  (* Check for completed services *)
  FOR i := 0 TO 1 DO
    IF NOT S1_ServerFree[i] AND SimulationTime >= S1_ServerEndTime[i] THEN
      (* Service complete - mark server free *)
      S1_ServerFree[i] := TRUE;
      (* Remove truck from S1, move to S2 *)
      CompleteS1Service();
    END_IF;
  END_FOR;
  
  (* Assign next queued truck to any free server *)
  FOR i := 0 TO 1 DO
    IF S1_ServerFree[i] AND NOT IsQueueEmpty(S1_Head, S1_Tail) THEN
      IF Dequeue(S1_Queue, S1_Head, S1_Tail, 2500, QueuedTruckID) THEN
        ServiceMinutes := SampleServiceTime(1);  (* S1 station *)
        
        AllTrucks[QueuedTruckID].S1_StartTime := SimulationTime;
        S1_ServerEndTime[i] := AddMinutes(SimulationTime, ServiceMinutes);
        S1_ServerFree[i] := FALSE;
      END_IF;
    END_IF;
  END_FOR;
END_PROCEDURE

(* ===== SINGLE-SERVER LOGIC (S2, S4) ===== *)

PROCEDURE ManageSingleServer(
  StationID : INT;  (* 2 for S2, 4 for S4 *)
  VAR Queue : ARRAY OF UDINT;
  VAR QHead : INT;
  VAR QTail : INT;
  VAR ServerFree : BOOL;
  VAR ServerEndTime : DT
)
VAR
  QueuedTruckID : UDINT;
  ServiceMinutes : REAL;
END_VAR

  (* Check for completed service *)
  IF NOT ServerFree AND SimulationTime >= ServerEndTime THEN
    ServerFree := TRUE;
    (* Move truck to next station *)
    CompleteStationService(StationID);
  END_IF;
  
  (* Assign next truck if available *)
  IF ServerFree AND NOT IsQueueEmpty(QHead, QTail) THEN
    IF Dequeue(Queue, QHead, QTail, 2500, QueuedTruckID) THEN
      ServiceMinutes := SampleServiceTime(StationID);
      
      IF StationID = 2 THEN
        AllTrucks[QueuedTruckID].S2_StartTime := SimulationTime;
      ELSIF StationID = 4 THEN
        AllTrucks[QueuedTruckID].S4_StartTime := SimulationTime;
      END_IF;
      
      ServerEndTime := AddMinutes(SimulationTime, ServiceMinutes);
      ServerFree := FALSE;
    END_IF;
  END_IF;
END_PROCEDURE

(* ===== MULTI-SLOT LOGIC (S3a: 4 slots, S3b: 2 slots) ===== *)

PROCEDURE ManageS3Slots()
VAR
  SlotIdx : INT;
  QueuedTruckID : UDINT;
END_VAR

  (* ===== DIESEL (S3a - 4 slots) ===== *)
  IF L1_Status = OPERATIONAL THEN
    FOR SlotIdx := 0 TO 3 DO
      IF NOT S3a_BayOccupied[SlotIdx] AND 
         NOT IsQueueEmpty(S3a_Head, S3a_Tail) THEN
        IF Dequeue(S3a_Queue, S3a_Head, S3a_Tail, 2500, QueuedTruckID) THEN
          (* Start grounding *)
          S3a_BayOccupied[SlotIdx] := TRUE;
          S3a_TruckInBay[SlotIdx] := QueuedTruckID;
          AllTrucks[QueuedTruckID].S3_ArrivalTime := SimulationTime;
          AllTrucks[QueuedTruckID].S3_GroundingStartTime := SimulationTime;
          AllTrucks[QueuedTruckID].S3_GroundingStatus := FALSE;  (* NOT grounded yet *)
          AllTrucks[QueuedTruckID].S3_GroundingTime := TRIANGULAR(3, 4, 6);
        END_IF;
      END_IF;
    END_FOR;
  END_IF;
  
  (* ===== GASOHOL (S3b - 2 slots) ===== *)
  IF L2_Status = OPERATIONAL THEN
    FOR SlotIdx := 0 TO 1 DO
      IF NOT S3b_BayOccupied[SlotIdx] AND 
         NOT IsQueueEmpty(S3b_Head, S3b_Tail) THEN
        IF Dequeue(S3b_Queue, S3b_Head, S3b_Tail, 2500, QueuedTruckID) THEN
          S3b_BayOccupied[SlotIdx] := TRUE;
          S3b_TruckInBay[SlotIdx] := QueuedTruckID;
          AllTrucks[QueuedTruckID].S3_ArrivalTime := SimulationTime;
          AllTrucks[QueuedTruckID].S3_GroundingStartTime := SimulationTime;
          AllTrucks[QueuedTruckID].S3_GroundingStatus := FALSE;
          AllTrucks[QueuedTruckID].S3_GroundingTime := TRIANGULAR(3, 4, 6);
        END_IF;
      END_IF;
    END_FOR;
  END_IF;
END_PROCEDURE
```

---

## 3. STATE TRANSITION LOGIC

### Truck Journey: S1 → S2 → S3 → S4 → O1

```codesys
(* ===== STATE TRANSITION HANDLER ===== *)

PROCEDURE TransitionTruck(TruckID : UDINT; FromStation : INT; ToStation : INT)
VAR
  EnqueueSuccess : BOOL := FALSE;
END_VAR

  (* Complete FROM station *)
  AllTrucks[TruckID].S1_DepartureTime := SimulationTime;  (* example for S1 *)
  
  (* Transition TO station *)
  CASE ToStation OF
    1: (* S1 *)
      AllTrucks[TruckID].CurrentStation := S1;
      EnqueueSuccess := Enqueue(S1_Queue, S1_Head, S1_Tail, TruckID, 2500);
      IF EnqueueSuccess THEN
        AllTrucks[TruckID].S1_ArrivalTime := SimulationTime;
      END_IF;
      
    2: (* S2 *)
      AllTrucks[TruckID].CurrentStation := S2;
      EnqueueSuccess := Enqueue(S2_Queue, S2_Head, S2_Tail, TruckID, 2500);
      IF EnqueueSuccess THEN
        AllTrucks[TruckID].S2_ArrivalTime := SimulationTime;
      END_IF;
      
    3: (* S3 - Product-based routing *)
      AllTrucks[TruckID].CurrentStation := S3;
      IF AllTrucks[TruckID].ProductType = DIESEL THEN
        EnqueueSuccess := Enqueue(S3a_Queue, S3a_Head, S3a_Tail, TruckID, 2500);
      ELSE
        EnqueueSuccess := Enqueue(S3b_Queue, S3b_Head, S3b_Tail, TruckID, 2500);
      END_IF;
      
    4: (* S4 *)
      AllTrucks[TruckID].CurrentStation := S4;
      EnqueueSuccess := Enqueue(S4_Queue, S4_Head, S4_Tail, TruckID, 2500);
      IF EnqueueSuccess THEN
        AllTrucks[TruckID].S4_ArrivalTime := SimulationTime;
      END_IF;
      
    5: (* O1 - Immediate exit *)
      AllTrucks[TruckID].CurrentStation := O1;
      AllTrucks[TruckID].O1_ArrivalTime := SimulationTime;
      AllTrucks[TruckID].O1_DepartureTime := SimulationTime;  (* immediate *)
      AllTrucks[TruckID].CompletedAllStations := TRUE;
      
      (* Buffer event for O1 *)
      BufferO1Event(TruckID);
      
      (* Move to export for this truck *)
      CompleteExport(TruckID);
      
  END_CASE;
  
  IF NOT EnqueueSuccess THEN
    LogError("Queue overflow during transition");
  END_IF;
END_PROCEDURE

(* ===== COMPLETE S1 → S2 ===== *)

PROCEDURE CompleteS1()
VAR
  TruckID : UDINT;
  ServerIdx : INT;
END_VAR

  FOR ServerIdx := 0 TO 1 DO
    IF NOT S1_ServerFree[ServerIdx] AND 
       SimulationTime >= S1_ServerEndTime[ServerIdx] THEN
      
      TruckID := FindTruckOnServer(S1, ServerIdx);
      IF TruckID > 0 THEN
        AllTrucks[TruckID].S1_EndTime := SimulationTime;
        AllTrucks[TruckID].S1_DepartureTime := SimulationTime;
        
        (* Buffer S1 event *)
        BufferS1Event(TruckID);
        
        (* Transition to S2 *)
        TransitionTruck(TruckID, S1, S2);
        S1_ServerFree[ServerIdx] := TRUE;
      END_IF;
    END_IF;
  END_FOR;
END_PROCEDURE

(* ===== COMPLETE S2 → S3 ===== *)

PROCEDURE CompleteS2()
  IF NOT S2_ServerFree AND SimulationTime >= S2_ServerEndTime THEN
    VAR
      TruckID : UDINT;
    END_VAR;
    
    TruckID := FindTruckOnServer(S2, 0);
    IF TruckID > 0 THEN
      AllTrucks[TruckID].S2_EndTime := SimulationTime;
      AllTrucks[TruckID].S2_DepartureTime := SimulationTime;
      
      BufferS2Event(TruckID);
      TransitionTruck(TruckID, S2, S3);
      S2_ServerFree := TRUE;
    END_IF;
  END_IF;
END_PROCEDURE

(* ===== SIMILAR FOR S3 → S4, S4 → O1 ===== *)
```

---

## 4. LINE FAILURE TRIGGERING & REPAIR SIMULATION

### Fill-Time Accumulation Model (NOT wall-clock)

```codesys
(* ===== FAILURE INITIALIZATION ===== *)

PROCEDURE InitializeFailures()
  L1_FailureThresholdMinutes := TRIANGULAR(7500, 9000, 10500);
  L1_AccumulatedFillMinutes := 0.0;
  
  L2_FailureThresholdMinutes := TRIANGULAR(7500, 9000, 10500);
  L2_AccumulatedFillMinutes := 0.0;
END_PROCEDURE

(* ===== ACCUMULATE FILL TIME (ONLY DURING ACTIVE FILLING) ===== *)

FUNCTION HasActiveDieselFills : BOOL
VAR
  SlotIdx : INT;
END_VAR

  FOR SlotIdx := 0 TO 3 DO
    IF S3a_BayOccupied[SlotIdx] AND
       AllTrucks[S3a_TruckInBay[SlotIdx]].S3_GroundingStatus = TRUE THEN
      (* Truck is past grounding, actively filling *)
      RETURN TRUE;
    END_IF;
  END_FOR;
  HasActiveDieselFills := FALSE;
END_FUNCTION

FUNCTION HasActiveGasoholFills : BOOL
VAR
  SlotIdx : INT;
END_VAR

  FOR SlotIdx := 0 TO 1 DO
    IF S3b_BayOccupied[SlotIdx] AND
       AllTrucks[S3b_TruckInBay[SlotIdx]].S3_GroundingStatus = TRUE THEN
      RETURN TRUE;
    END_IF;
  END_FOR;
  HasActiveGasoholFills := FALSE;
END_FUNCTION

(* ===== CHECK FAILURES EACH SCAN ===== *)

PROCEDURE CheckLineFailures()
VAR
  SlotIdx : INT;
  TruckID : UDINT;
END_VAR

  (* ===== DIESEL LINE (L1) ===== *)
  IF L1_Status = OPERATIONAL THEN
    (* Accumulate fill time ONLY if active fills exist *)
    IF HasActiveDieselFills() THEN
      L1_AccumulatedFillMinutes := L1_AccumulatedFillMinutes + (1.0 / 60.0);  (* +1 sec *)
    END_IF;
    
    (* Check if failure threshold reached *)
    IF L1_AccumulatedFillMinutes >= L1_FailureThresholdMinutes THEN
      (* TRIGGER FAILURE *)
      L1_Status := FAILURE;
      L1_FailureStart := SimulationTime;
      L1_RepairEndTime := AddMinutes(SimulationTime, 120);
      L1_FailureCount := L1_FailureCount + 1;
      
      (* Pause all active S3a trucks *)
      FOR SlotIdx := 0 TO 3 DO
        IF S3a_BayOccupied[SlotIdx] THEN
          TruckID := S3a_TruckInBay[SlotIdx];
          AllTrucks[TruckID].IsFailurePaused := TRUE;
          AllTrucks[TruckID].FailurePauseStart := SimulationTime;
          
          (* Track for failure event *)
          L1_AffectedTrucks[L1_AffectedCount] := TruckID;
          L1_AffectedCount := L1_AffectedCount + 1;
        END_IF;
      END_FOR;
      
      (* Sample NEXT failure threshold *)
      L1_FailureThresholdMinutes := TRIANGULAR(7500, 9000, 10500);
      L1_AccumulatedFillMinutes := 0.0;  (* Reset accumulator *)
      
      (* Buffer failure event *)
      BufferL1FailureEvent(L1_AffectedCount);
    END_IF;
  END_IF;
  
  (* ===== REPAIR TIMEOUT ===== *)
  IF L1_Status = FAILURE THEN
    IF SimulationTime >= L1_RepairEndTime THEN
      L1_Status := OPERATIONAL;
      
      (* Resume all paused trucks *)
      FOR SlotIdx := 0 TO 3 DO
        IF S3a_BayOccupied[SlotIdx] THEN
          TruckID := S3a_TruckInBay[SlotIdx];
          IF AllTrucks[TruckID].IsFailurePaused THEN
            AllTrucks[TruckID].IsFailurePaused := FALSE;
            AllTrucks[TruckID].FailurePauseEnd := SimulationTime;
            AllTrucks[TruckID].FailureDowntimeMinutes := 
              AllTrucks[TruckID].FailureDowntimeMinutes + 
              (AllTrucks[TruckID].FailurePauseEnd - AllTrucks[TruckID].FailurePauseStart);
          END_IF;
        END_IF;
      END_FOR;
      
      L1_AffectedCount := 0;  (* Reset *)
    END_IF;
  END_IF;
  
  (* ===== GASOHOL LINE (L2) - SAME LOGIC ===== *)
  (* ... (identical to L1, but for S3b slots) ... *)
END_PROCEDURE
```

---

## 5. FILL AMOUNT CALCULATIONS

### Product-Based Fill Amount & Flow Rate Derivation

```codesys
(* ===== SAMPLE FILL AMOUNT BY PRODUCT ===== *)

FUNCTION SampleFillAmount : REAL
VAR_INPUT
  ProductType : (DIESEL, GASOHOL95);
END_VAR

  CASE ProductType OF
    DIESEL:
      SampleFillAmount := TRIANGULAR(6000, 9612, 12000);   (* liters *)
    GASOHOL95:
      SampleFillAmount := TRIANGULAR(6000, 9635, 11000);   (* liters *)
  END_CASE;
END_FUNCTION

(* ===== SAMPLE PRODUCTIVE FILL TIME ===== *)

FUNCTION SampleProductiveFillTime : REAL
  (* Both products have similar fill time *)
  SampleProductiveFillTime := TRIANGULAR(38, 42, 46);  (* minutes *)
END_FUNCTION

(* ===== ON GROUNDING COMPLETION, START FILL ===== *)

PROCEDURE CompleteGrounding(TruckID : UDINT)
VAR
  SlotIdx : INT;
  FillTime : REAL;
  ProductiveFillTime : REAL;
END_VAR

  (* Mark grounding complete *)
  AllTrucks[TruckID].S3_FillStartTime := SimulationTime;
  AllTrucks[TruckID].S3_GroundingStatus := TRUE;  (* NOW grounded ✓ *)
  
  (* Sample fill amount *)
  AllTrucks[TruckID].S3_FillAmount := SampleFillAmount(AllTrucks[TruckID].ProductType);
  
  (* Sample productive fill time *)
  AllTrucks[TruckID].S3_ProductiveFillTime := SampleProductiveFillTime();
  
  (* Initialize failure downtime (starts at 0) *)
  AllTrucks[TruckID].S3_FailureDowntimeMin := 0.0;
  
  (* Calculate fill end time *)
  AllTrucks[TruckID].S3_FillEndTime := 
    AddMinutes(SimulationTime, AllTrucks[TruckID].S3_ProductiveFillTime);
END_PROCEDURE

(* ===== DERIVE FLOW RATE (AFTER FILL COMPLETE) ===== *)

PROCEDURE CalculateDerivedFlowRate(TruckID : UDINT)
VAR
  EffectiveFillTime : REAL;
END_VAR

  (* Flow rate = fill_amount / productive_fill_time *)
  (* (productive_fill_time already excludes failure downtime) *)
  
  IF AllTrucks[TruckID].S3_ProductiveFillTime > 0 THEN
    AllTrucks[TruckID].S3_DerivedFlowRate := 
      AllTrucks[TruckID].S3_FillAmount / AllTrucks[TruckID].S3_ProductiveFillTime;
  ELSE
    AllTrucks[TruckID].S3_DerivedFlowRate := 0;
  END_IF;
  
  (* Validation: should be ~220 L/min *)
  (* Historical range: 200-240 L/min *)
END_PROCEDURE

(* ===== ON COMPLETION, CALCULATE METRICS ===== *)

PROCEDURE CompleteS3Fill(TruckID : UDINT)
  AllTrucks[TruckID].S3_EndTime := SimulationTime;
  AllTrucks[TruckID].S3_DepartureTime := SimulationTime;
  
  (* Calculate derived flow rate *)
  CalculateDerivedFlowRate(TruckID);
  
  (* Buffer S3 event *)
  BufferS3Event(TruckID);
  
  (* Transition to S4 *)
  TransitionTruck(TruckID, S3, S4);
END_PROCEDURE
```

---

## 6. GROUNDING STATUS LOGIC

### Critical: TRUE Only After Grounding Time Finishes (Must Clear Queue)

```codesys
(* ===== GROUNDING STATE MACHINE ===== *)

PROCEDURE ManageS3Grounding()
VAR
  SlotIdx : INT;
  TruckID : UDINT;
  GroundingDueTime : DT;
END_VAR

  (* ===== DIESEL GROUNDING (S3a) ===== *)
  FOR SlotIdx := 0 TO 3 DO
    IF S3a_BayOccupied[SlotIdx] THEN
      TruckID := S3a_TruckInBay[SlotIdx];
      
      (* STEP 1: Truck in queue, NOT grounded yet *)
      IF AllTrucks[TruckID].S3_GroundingStatus = FALSE AND
         AllTrucks[TruckID].S3_FillStartTime = NULL_DT THEN
        
        (* Calculate when grounding should complete *)
        GroundingDueTime := AddMinutes(
          AllTrucks[TruckID].S3_GroundingStartTime,
          AllTrucks[TruckID].S3_GroundingTime
        );
        
        (* STEP 2: Grounding time elapsed → NOW GROUNDED ✓ *)
        IF SimulationTime >= GroundingDueTime THEN
          CompleteGrounding(TruckID);  (* Sets GroundingStatus := TRUE *)
        END_IF;
      END_IF;
      
      (* STEP 3: Truck is grounded, check if filling should end *)
      IF AllTrucks[TruckID].S3_GroundingStatus = TRUE AND
         AllTrucks[TruckID].S3_FillEndTime <> NULL_DT THEN
        
        IF SimulationTime >= AllTrucks[TruckID].S3_FillEndTime AND
           NOT AllTrucks[TruckID].IsFailurePaused THEN
          (* Fill complete, move to S4 *)
          CompleteS3Fill(TruckID);
          S3a_BayOccupied[SlotIdx] := FALSE;
          S3a_TruckInBay[SlotIdx] := 0;
        END_IF;
      END_IF;
    END_IF;
  END_FOR;
  
  (* ===== GASOHOL GROUNDING (S3b) - SAME PATTERN ===== *)
  FOR SlotIdx := 0 TO 1 DO
    IF S3b_BayOccupied[SlotIdx] THEN
      TruckID := S3b_TruckInBay[SlotIdx];
      
      IF AllTrucks[TruckID].S3_GroundingStatus = FALSE AND
         AllTrucks[TruckID].S3_FillStartTime = NULL_DT THEN
        
        GroundingDueTime := AddMinutes(
          AllTrucks[TruckID].S3_GroundingStartTime,
          AllTrucks[TruckID].S3_GroundingTime
        );
        
        IF SimulationTime >= GroundingDueTime THEN
          CompleteGrounding(TruckID);
        END_IF;
      END_IF;
      
      IF AllTrucks[TruckID].S3_GroundingStatus = TRUE AND
         AllTrucks[TruckID].S3_FillEndTime <> NULL_DT THEN
        
        IF SimulationTime >= AllTrucks[TruckID].S3_FillEndTime AND
           NOT AllTrucks[TruckID].IsFailurePaused THEN
          CompleteS3Fill(TruckID);
          S3b_BayOccupied[SlotIdx] := FALSE;
          S3b_TruckInBay[SlotIdx] := 0;
        END_IF;
      END_IF;
    END_IF;
  END_FOR;
END_PROCEDURE

(* ===== GROUNDING STATUS OUTPUT ===== *)

PROCEDURE GetGroundingStatusForCSV(TruckID : UDINT) : BOOL
  (* Output always TRUE because CSV records only exist AFTER truck completed fill *)
  (* (Which means grounding was already done) *)
  RETURN AllTrucks[TruckID].S3_GroundingStatus;
END_PROCEDURE

(* ===== GROUNDING STATUS SUMMARY ===== *)
(*
STATE: QUEUED_S3
  GroundingStatus = FALSE (truck waiting in bay queue)
  
STATE: GROUNDING (grounding_time counting down)
  GroundingStatus = FALSE (grounding in progress)
  
STATE: FILLING (at FillStartTime)
  GroundingStatus = TRUE ← TRANSITION HERE ✓
  (truck is grounded, safe to fill)
  
STATE: FILLING_PAUSED (failure pause)
  GroundingStatus = TRUE (remains TRUE)
  
STATE: CSV OUTPUT
  grounding_status = TRUE (always, because record only exists post-fill)
*)
```

---

## 7. DATA EXPORT/LOGGING MECHANISMS

### Event Buffering & CSV Writing Strategy

```codesys
(* ===== EVENT BUFFER STRUCTURES ===== *)

TYPE S1_Event :
  STRUCT
    po_number : DINT;
    vehicle_number : STRING[30];
    arrival_time : DT;
    start_time : DT;
    end_time : DT;
    departure_time : DT;
  END_STRUCT
END_TYPE

TYPE S3_Event :
  STRUCT
    po_number : DINT;
    vehicle_number : STRING[30];
    arrival_time : DT;
    start_time : DT;
    grounding_time : REAL;
    fill_start : DT;
    end_time : DT;
    departure_time : DT;
    fill_amount : REAL;
    productive_fill_time : REAL;
    failure_downtime_mins : REAL;
    average_flow_rate : REAL;
  END_STRUCT
END_TYPE

TYPE FailureEvent :
  STRUCT
    failure_id : INT;
    failure_start : DT;
    repair_end : DT;
    affected_truck_count : INT;
  END_STRUCT
END_TYPE

(* ===== GLOBAL EVENT BUFFERS ===== *)

VAR_GLOBAL
  (* S1 events *)
  S1_Events : ARRAY[1..5000] OF S1_Event;
  S1_EventCount : INT := 0;
  
  (* S2 events *)
  S2_Events : ARRAY[1..5000] OF S1_Event;  (* same schema *)
  S2_EventCount : INT := 0;
  
  (* S3a events *)
  S3a_Events : ARRAY[1..5000] OF S3_Event;
  S3a_EventCount : INT := 0;
  
  (* S3b events *)
  S3b_Events : ARRAY[1..5000] OF S3_Event;
  S3b_EventCount : INT := 0;
  
  (* S4 events *)
  S4_Events : ARRAY[1..5000] OF S1_Event;  (* same schema as S1/S2 *)
  S4_EventCount : INT := 0;
  
  (* O1 events *)
  O1_Events : ARRAY[1..5000] OF O1_Event;
  O1_EventCount : INT := 0;
  
  (* Failure events *)
  L1_FailureEvents : ARRAY[1..100] OF FailureEvent;
  L1_FailureEventCount : INT := 0;
  
  L2_FailureEvents : ARRAY[1..100] OF FailureEvent;
  L2_FailureEventCount : INT := 0;
  
  (* db_truck master *)
  db_truck_Records : ARRAY[1..10000] OF db_truck_Event;
  db_truck_Count : INT := 0;
END_VAR

(* ===== BUFFER S1 EVENT ===== *)

PROCEDURE BufferS1Event(TruckID : UDINT)
  IF S1_EventCount < 5000 THEN
    S1_EventCount := S1_EventCount + 1;
    
    S1_Events[S1_EventCount].po_number := AllTrucks[TruckID].PONumber;
    S1_Events[S1_EventCount].vehicle_number := AllTrucks[TruckID].VehicleNumber;
    S1_Events[S1_EventCount].arrival_time := AllTrucks[TruckID].S1_ArrivalTime;
    S1_Events[S1_EventCount].start_time := AllTrucks[TruckID].S1_StartTime;
    S1_Events[S1_EventCount].end_time := AllTrucks[TruckID].S1_EndTime;
    S1_Events[S1_EventCount].departure_time := AllTrucks[TruckID].S1_DepartureTime;
  ELSE
    LogError("S1 event buffer full");
  END_IF;
END_PROCEDURE

(* ===== BUFFER S3a EVENT ===== *)

PROCEDURE BufferS3aEvent(TruckID : UDINT)
  IF S3a_EventCount < 5000 THEN
    S3a_EventCount := S3a_EventCount + 1;
    
    S3a_Events[S3a_EventCount].po_number := AllTrucks[TruckID].PONumber;
    S3a_Events[S3a_EventCount].vehicle_number := AllTrucks[TruckID].VehicleNumber;
    S3a_Events[S3a_EventCount].arrival_time := AllTrucks[TruckID].S3_ArrivalTime;
    S3a_Events[S3a_EventCount].start_time := AllTrucks[TruckID].S3_GroundingStartTime;
    S3a_Events[S3a_EventCount].grounding_time := AllTrucks[TruckID].S3_GroundingTime;
    S3a_Events[S3a_EventCount].fill_start := AllTrucks[TruckID].S3_FillStartTime;
    S3a_Events[S3a_EventCount].end_time := AllTrucks[TruckID].S3_EndTime;
    S3a_Events[S3a_EventCount].departure_time := AllTrucks[TruckID].S3_DepartureTime;
    S3a_Events[S3a_EventCount].fill_amount := AllTrucks[TruckID].S3_FillAmount;
    S3a_Events[S3a_EventCount].productive_fill_time := AllTrucks[TruckID].S3_ProductiveFillTime;
    S3a_Events[S3a_EventCount].failure_downtime_mins := AllTrucks[TruckID].S3_FailureDowntimeMin;
    S3a_Events[S3a_EventCount].average_flow_rate := AllTrucks[TruckID].S3_DerivedFlowRate;
  ELSE
    LogError("S3a event buffer full");
  END_IF;
END_PROCEDURE

(* ===== BUFFER FAILURE EVENT ===== *)

PROCEDURE BufferL1FailureEvent(AffectedCount : INT)
  IF L1_FailureEventCount < 100 THEN
    L1_FailureEventCount := L1_FailureEventCount + 1;
    
    L1_FailureEvents[L1_FailureEventCount].failure_id := L1_FailureEventCount;
    L1_FailureEvents[L1_FailureEventCount].failure_start := L1_FailureStart;
    L1_FailureEvents[L1_FailureEventCount].repair_end := L1_RepairEndTime;
    L1_FailureEvents[L1_FailureEventCount].affected_truck_count := AffectedCount;
  ELSE
    LogError("L1 failure event buffer full");
  END_IF;
END_PROCEDURE

(* ===== ON TRUCK ARRIVAL: BUFFER TO db_truck ===== *)

PROCEDURE Bufferdb_TruckEvent(TruckID : UDINT)
  IF db_truck_Count < 10000 THEN
    db_truck_Count := db_truck_Count + 1;
    
    db_truck_Records[db_truck_Count].po_number := AllTrucks[TruckID].PONumber;
    db_truck_Records[db_truck_Count].vehicle_number := AllTrucks[TruckID].VehicleNumber;
    db_truck_Records[db_truck_Count].company_id := AllTrucks[TruckID].CompanyID;
    db_truck_Records[db_truck_Count].sold_to := "TAS Facility";  (* placeholder *)
    db_truck_Records[db_truck_Count].arrival_time := AllTrucks[TruckID].S1_ArrivalTime;
    IF AllTrucks[TruckID].ProductType = DIESEL THEN
      db_truck_Records[db_truck_Count].product_type := "DIESEL";
    ELSE
      db_truck_Records[db_truck_Count].product_type := "GASOHOL95";
    END_IF;
  ELSE
    LogError("db_truck buffer full");
  END_IF;
END_PROCEDURE

(* ===== WRITE ALL CSV FILES AT END OF SIMULATION ===== *)

PROCEDURE WriteAllOutputFiles()
  LogInfo("Writing S1 CSV...");
  WriteCSVFile("s1_sales_office.csv", S1_Events, S1_EventCount);
  
  LogInfo("Writing S2 CSV...");
  WriteCSVFile("s2_inbound_wb.csv", S2_Events, S2_EventCount);
  
  LogInfo("Writing S3a CSV...");
  WriteS3CSVFile("s3a_diesel_bay.csv", S3a_Events, S3a_EventCount);
  
  LogInfo("Writing S3b CSV...");
  WriteS3CSVFile("s3b_gasohol95_bay.csv", S3b_Events, S3b_EventCount);
  
  LogInfo("Writing S4 CSV...");
  WriteCSVFile("s4_outbound_wb.csv", S4_Events, S4_EventCount);
  
  LogInfo("Writing O1 CSV...");
  WriteO1CSVFile("o1_exit_gate.csv", O1_Events, O1_EventCount);
  
  LogInfo("Writing db_truck CSV...");
  Writedb_TruckCSVFile("db_truck.csv", db_truck_Records, db_truck_Count);
  
  LogInfo("Writing L1 failure CSV...");
  WriteFailureCSVFile("l1_diesel_failure.csv", L1_FailureEvents, L1_FailureEventCount);
  
  LogInfo("Writing L2 failure CSV...");
  WriteFailureCSVFile("l2_gasohol95_failure.csv", L2_FailureEvents, L2_FailureEventCount);
  
  LogInfo("All files written successfully");
END_PROCEDURE

(* ===== EXAMPLE: WRITE CSV HELPER (pseudo-code, adapt to your CSV library) ===== *)

PROCEDURE WriteCSVFile(FileName : STRING; Events : ARRAY OF S1_Event; Count : INT)
VAR
  i : INT;
  FileHandle : HANDLE;
  Line : STRING;
END_VAR

  FileHandle := FileOpen(FileName, "w");
  
  (* Write header *)
  Line := "po_number,vehicle_number,arrival_time,start_time,end_time,departure_time";
  FileWriteLine(FileHandle, Line);
  
  (* Write events *)
  FOR i := 1 TO Count DO
    Line := CONCAT(
      INT_TO_STRING(Events[i].po_number), ",",
      Events[i].vehicle_number, ",",
      DT_TO_STRING(Events[i].arrival_time), ",",
      DT_TO_STRING(Events[i].start_time), ",",
      DT_TO_STRING(Events[i].end_time), ",",
      DT_TO_STRING(Events[i].departure_time)
    );
    FileWriteLine(FileHandle, Line);
  END_FOR;
  
  FileClose(FileHandle);
END_PROCEDURE
```

---

## INTEGRATION: Main Simulation Loop (Each 1-Second Scan)

```codesys
PROCEDURE MainSimulationLoop()
  WHILE SimulationTime < SimStop DO
    (* 1. Generate arrivals *)
    GenerateArrivals();
    
    (* 2. Check failures *)
    CheckLineFailures();
    
    (* 3. Manage all queues & servers *)
    ManageS1Servers();
    ManageSingleServer(2, S2_Queue, S2_Head, S2_Tail, S2_ServerFree, S2_ServerEndTime);
    ManageS3Slots();
    ManageSingleServer(4, S4_Queue, S4_Head, S4_Tail, S4_ServerFree, S4_ServerEndTime);
    
    (* 4. Manage grounding & filling *)
    ManageS3Grounding();
    
    (* 5. Manage state transitions & completions *)
    CompleteS1();
    CompleteS2();
    CompleteS3();
    CompleteS4();
    
    (* 6. Advance time *)
    SimulationTime := AddSeconds(SimulationTime, 1);
    ScanCount := ScanCount + 1;
  END_WHILE;
  
  (* 7. Write all outputs *)
  WriteAllOutputFiles();
  
  SimulationRunning := FALSE;
  LogInfo("Simulation complete");
END_PROCEDURE
```

---

## Summary: 7 Components Interconnected

| Component | Purpose | Trigger | Output |
|-----------|---------|---------|--------|
| Queue Management | FIFO arrival/departure | Arrival/completion | Queue head/tail pointers |
| Server Allocation | Assign available servers | Queue not empty | ServiceEndTime |
| Service Time | Sample duration | On server assignment | Triangular(min,mode,max) |
| State Transition | Move truck S1→S2→S3→S4→O1 | Completion signal | CurrentStation, queued |
| Failure Logic | Accumulate fill time, trigger | Active filling > threshold | Paused trucks, RepairEndTime |
| Grounding | FALSE until complete | Grounding time elapsed | GroundingStatus TRUE |
| Fill Amount | Product-based | Grounding complete | FillAmount, DerivedFlowRate |
| Data Export | Buffer events | On completion | CSV files at sim end |

**All components feed into the main 1-second scan loop.**

---

**End of Implementation Design Guide**

Ready to code in CODESYS ST? 🚀
