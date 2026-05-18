(*
================================================================================
DataExport.st - Event Buffering and Truck Record Management
================================================================================
Exports event data and truck records for external analysis.
================================================================================
*)

PROCEDURE RecordS1Event
VAR_INPUT
  TruckID : UDINT;
  VehicleNumber : STRING[30];
  ArrivalTime : DT;
  StartTime : DT;
  EndTime : DT;
  ServiceTimeMinutes : REAL;
END_VAR
VAR
  event : ST_S1_Event;
  queue_wait : REAL;
END_VAR

  IF S1_EventCount < MAX_EVENTS THEN
    queue_wait := GetMinutesBetween(ArrivalTime, StartTime);
    
    event.TruckID := TruckID;
    event.VehicleNumber := VehicleNumber;
    event.ArrivalTime := ArrivalTime;
    event.StartTime := StartTime;
    event.EndTime := EndTime;
    event.ServiceTimeMinutes := ServiceTimeMinutes;
    event.QueueWaitMinutes := queue_wait;
    
    S1_EventCount := S1_EventCount + 1;
    S1_Events[S1_EventCount] := event;
  END_IF;

END_PROCEDURE

PROCEDURE RecordS2Event
VAR_INPUT
  TruckID : UDINT;
  VehicleNumber : STRING[30];
  ArrivalTime : DT;
  StartTime : DT;
  EndTime : DT;
  ServiceTimeMinutes : REAL;
END_VAR
VAR
  event : ST_S2_Event;
  queue_wait : REAL;
END_VAR

  IF S2_EventCount < MAX_EVENTS THEN
    queue_wait := GetMinutesBetween(ArrivalTime, StartTime);
    
    event.TruckID := TruckID;
    event.VehicleNumber := VehicleNumber;
    event.ArrivalTime := ArrivalTime;
    event.StartTime := StartTime;
    event.EndTime := EndTime;
    event.ServiceTimeMinutes := ServiceTimeMinutes;
    event.QueueWaitMinutes := queue_wait;
    
    S2_EventCount := S2_EventCount + 1;
    S2_Events[S2_EventCount] := event;
  END_IF;

END_PROCEDURE

PROCEDURE RecordS4Event
VAR_INPUT
  TruckID : UDINT;
  VehicleNumber : STRING[30];
  ArrivalTime : DT;
  StartTime : DT;
  EndTime : DT;
  ServiceTimeMinutes : REAL;
END_VAR
VAR
  event : ST_S4_Event;
  queue_wait : REAL;
END_VAR

  IF S4_EventCount < MAX_EVENTS THEN
    queue_wait := GetMinutesBetween(ArrivalTime, StartTime);
    
    event.TruckID := TruckID;
    event.VehicleNumber := VehicleNumber;
    event.ArrivalTime := ArrivalTime;
    event.StartTime := StartTime;
    event.EndTime := EndTime;
    event.ServiceTimeMinutes := ServiceTimeMinutes;
    event.QueueWaitMinutes := queue_wait;
    
    S4_EventCount := S4_EventCount + 1;
    S4_Events[S4_EventCount] := event;
  END_IF;

END_PROCEDURE

PROCEDURE RecordTruckInDatabase
VAR_INPUT
  truck_idx : UDINT;
END_VAR
VAR
  truck : ST_Truck;
  record : ST_db_TruckRecord;
  company_tier : E_CompanyTier;
END_VAR

  IF truck_idx > 0 AND truck_idx <= TruckCount THEN
    truck := AllTrucks[truck_idx];
    
    (* Determine company tier *)
    IF truck.CompanyID <= ROYAL_COMPANIES THEN
      company_tier := ROYAL;
    ELSE
      company_tier := NORMAL;
    END_IF;
    
    (* Create database record *)
    record.TruckID := truck.TruckID;
    record.VehicleNumber := truck.VehicleNumber;
    record.ProductType := truck.ProductType;
    record.PONumber := truck.PONumber;
    record.ShipmentNumber := truck.ShipmentNumber;
    record.CompanyID := truck.CompanyID;
    record.CompanyTier := company_tier;
    record.S1_ArrivalTime := truck.S1_ArrivalTime;
    record.S2_ArrivalTime := truck.S2_ArrivalTime;
    record.S3_ArrivalTime := truck.S3_ArrivalTime;
    record.S4_ArrivalTime := truck.S4_ArrivalTime;
    
    IF db_TruckCount < 10000 THEN
      db_TruckCount := db_TruckCount + 1;
      db_TruckRecords[db_TruckCount] := record;
    END_IF;
  END_IF;

END_PROCEDURE

PROCEDURE ExportAllEvents
VAR
  i : INT;
END_VAR

  (* All events are already buffered in global arrays *)
  (* S1_Events[1..S1_EventCount] *)
  (* S2_Events[1..S2_EventCount] *)
  (* S3a_Events[1..S3a_EventCount] *)
  (* S3b_Events[1..S3b_EventCount] *)
  (* S4_Events[1..S4_EventCount] *)
  (* O1_Events[1..O1_EventCount] *)
  (* L1_FailureEvents[1..L1_FailureEventCount] *)
  (* L2_FailureEvents[1..L2_FailureEventCount] *)
  (* db_TruckRecords[1..db_TruckCount] *)
  
  (* Export via OPC UA, HTTP, or file system *)

END_PROCEDURE
