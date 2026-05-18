(*
================================================================================
Globals.st - Global Variables, Constants, and Configuration
================================================================================
All global state for the simulation including queues, servers, and event buffers.
================================================================================
*)

VAR_GLOBAL CONSTANT
  (* Simulation Timing *)
  SIM_START_DATE : DATE := DATE#2026-03-01;
  SIM_START_TIME : TIME_OF_DAY := TIME#00:00:00;
  SIM_DURATION_DAYS : INT := 30;
  SIM_END_DATE : DATE := DATE#2026-03-31;
  SCAN_STEP_SECONDS : INT := 1;
  TOTAL_SCANS : DINT := 2592000; (* 30 * 24 * 60 * 60 *)
  
  (* Fleet Configuration *)
  TOTAL_COMPANIES : INT := 30;
  ROYAL_COMPANIES : INT := 5;
  NORMAL_COMPANIES : INT := 25;
  TRUCKS_PER_ROYAL : INT := 12;
  TRUCKS_PER_NORMAL : INT := 4;
  TOTAL_VEHICLES : INT := 160;
  VEHICLE_COOLDOWN_MINUTES : INT := 600; (* 10 hours *)
  
  (* Station Capacities *)
  S1_SERVERS : INT := 2;
  S2_SERVERS : INT := 1;
  S3A_SLOTS : INT := 4;
  S3B_SLOTS : INT := 2;
  S4_SERVERS : INT := 1;
  
  (* Failure Parameters *)
  MTTF_MIN : REAL := 7500.0; (* 125 hours *)
  MTTF_MODE : REAL := 9000.0; (* 150 hours *)
  MTTF_MAX : REAL := 10500.0; (* 175 hours *)
  MTTR_MIN : REAL := 60.0;
  MTTR_MODE : REAL := 120.0;
  MTTR_MAX : REAL := 180.0;
  
  (* Service Times (minutes) *)
  S1_SERVICE_MIN : REAL := 0.0;
  S1_SERVICE_MODE : REAL := 3.0;
  S1_SERVICE_MAX : REAL := 40.0;
  
  S2_SERVICE_MIN : REAL := 0.0;
  S2_SERVICE_MODE : REAL := 22.0;
  S2_SERVICE_MAX : REAL := 80.0;
  
  S4_SERVICE_MIN : REAL := 0.0;
  S4_SERVICE_MODE : REAL := 2.0;
  S4_SERVICE_MAX : REAL := 15.0;
  
  (* Grounding & Fill Times *)
  GROUNDING_MIN : REAL := 3.0;
  GROUNDING_MODE : REAL := 4.0;
  GROUNDING_MAX : REAL := 6.0;
  
  PRODUCTIVE_FILL_MIN : REAL := 38.0;
  PRODUCTIVE_FILL_MODE : REAL := 42.0;
  PRODUCTIVE_FILL_MAX : REAL := 46.0;
  
  (* Fill Amounts (liters) *)
  DIESEL_FILL_MIN : REAL := 6000.0;
  DIESEL_FILL_MODE : REAL := 9612.0;
  DIESEL_FILL_MAX : REAL := 12000.0;
  
  GASOHOL_FILL_MIN : REAL := 6000.0;
  GASOHOL_FILL_MODE : REAL := 9635.0;
  GASOHOL_FILL_MAX : REAL := 11000.0;
  
  (* Event Buffer Sizes *)
  MAX_EVENTS : INT := 10000;
  MAX_FAILURES : INT := 100;
END_VAR

VAR_GLOBAL
  (* Simulation Clock *)
  SimulationTime : DT;
  SimulationRunning : BOOL := FALSE;
  ScanCount : DINT := 0;
  
  (* Truck Management *)
  TruckCount : UDINT := 0;
  NextTruckID : UDINT := 1;
  NextPONumber : DINT := 200000000;
  NextShipmentNumber : DINT := 200000000;
  
  (* Vehicle Pool *)
  VehiclePool : ARRAY[1..160] OF STRING[30];
  LastUseTime : ARRAY[1..160] OF DT;
  
  (* Truck Array *)
  AllTrucks : ARRAY[1..10000] OF ST_Truck;
  
  (* S1 Server Queue *)
  S1_Queue : ARRAY[1..2500] OF UDINT;
  S1_Head : INT := 1;
  S1_Tail : INT := 1;
  S1_ServerFree : ARRAY[1..2] OF BOOL;
  S1_ServerEndTime : ARRAY[1..2] OF DT;
  
  (* S2 Server Queue *)
  S2_Queue : ARRAY[1..2500] OF UDINT;
  S2_Head : INT := 1;
  S2_Tail : INT := 1;
  S2_ServerFree : BOOL := TRUE;
  S2_ServerEndTime : DT;
  
  (* S3A (Diesel) Bay Queue *)
  S3a_Queue : ARRAY[1..2500] OF UDINT;
  S3a_Head : INT := 1;
  S3a_Tail : INT := 1;
  S3a_Bays : ARRAY[1..4] OF ST_S3_Bay;
  
  (* S3B (Gasohol) Bay Queue *)
  S3b_Queue : ARRAY[1..2500] OF UDINT;
  S3b_Head : INT := 1;
  S3b_Tail : INT := 1;
  S3b_Bays : ARRAY[1..2] OF ST_S3_Bay;
  
  (* S4 Server Queue *)
  S4_Queue : ARRAY[1..2500] OF UDINT;
  S4_Head : INT := 1;
  S4_Tail : INT := 1;
  S4_ServerFree : BOOL := TRUE;
  S4_ServerEndTime : DT;
  
  (* O1 Immediate Exit *)
  O1_Queue : ARRAY[1..2500] OF UDINT;
  O1_Head : INT := 1;
  O1_Tail : INT := 1;
  
  (* Line Failure States *)
  L1_Status : E_LineStatus := OPERATIONAL;
  L1_FailureThresholdMinutes : REAL;
  L1_AccumulatedFillMinutes : REAL := 0.0;
  L1_FailureStartTime : DT;
  L1_RepairEndTime : DT;
  L1_FailureCount : INT := 0;
  L1_ActiveFillCount : INT := 0;
  
  L2_Status : E_LineStatus := OPERATIONAL;
  L2_FailureThresholdMinutes : REAL;
  L2_AccumulatedFillMinutes : REAL := 0.0;
  L2_FailureStartTime : DT;
  L2_RepairEndTime : DT;
  L2_FailureCount : INT := 0;
  L2_ActiveFillCount : INT := 0;
  
  (* Event Buffers *)
  S1_Events : ARRAY[1..10000] OF ST_S1_Event;
  S1_EventCount : INT := 0;
  
  S2_Events : ARRAY[1..10000] OF ST_S2_Event;
  S2_EventCount : INT := 0;
  
  S3a_Events : ARRAY[1..10000] OF ST_S3_Event;
  S3a_EventCount : INT := 0;
  
  S3b_Events : ARRAY[1..10000] OF ST_S3_Event;
  S3b_EventCount : INT := 0;
  
  S4_Events : ARRAY[1..10000] OF ST_S4_Event;
  S4_EventCount : INT := 0;
  
  O1_Events : ARRAY[1..10000] OF ST_O1_Event;
  O1_EventCount : INT := 0;
  
  L1_FailureEvents : ARRAY[1..100] OF ST_LineFailure_Event;
  L1_FailureEventCount : INT := 0;
  
  L2_FailureEvents : ARRAY[1..100] OF ST_LineFailure_Event;
  L2_FailureEventCount : INT := 0;
  
  db_TruckRecords : ARRAY[1..10000] OF ST_db_TruckRecord;
  db_TruckCount : INT := 0;
  
  (* Arrival Rates (Poisson lambda by hour) *)
  DIESEL_LAMBDA : ARRAY[0..23] OF INT := 
    [3, 4, 2, 2, 2, 1, 4, 9, 9, 9, 7, 8, 8, 9, 8, 8, 7, 5, 3, 2, 0, 0, 0, 0];
  
  GASOHOL_LAMBDA : ARRAY[0..23] OF INT := 
    [3, 2, 0, 1, 1, 0, 1, 1, 1, 2, 4, 3, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
  
  (* Counters *)
  TotalArrivals : INT := 0;
  DieselArrivals : INT := 0;
  GasoholArrivals : INT := 0;
  TotalDepartures : INT := 0;
  
END_VAR
