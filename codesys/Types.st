(*
================================================================================
Types.st - Complete Type System for TAS Fuel Distribution Simulator
================================================================================
Enumerations and data structures for truck processing, server management,
and event recording.
================================================================================
*)

(* ============================================================================ *)
(* ENUMERATIONS *)
(* ============================================================================ *)

TYPE E_ProductType :
  (DIESEL, GASOHOL95)
END_TYPE

TYPE E_TruckState :
  (CREATED, S1, S2, S3, S4, O1, DEPARTED)
END_TYPE

TYPE E_LineStatus :
  (OPERATIONAL, FAILURE)
END_TYPE

TYPE E_CompanyTier :
  (ROYAL, NORMAL)
END_TYPE

TYPE E_S3State :
  (IDLE, GROUNDING, FILLING, PAUSED, COMPLETE)
END_TYPE

(* ============================================================================ *)
(* STRUCTURES *)
(* ============================================================================ *)

TYPE ST_Truck :
  STRUCT
    TruckID : UDINT;
    CompanyID : INT;
    VehicleNumber : STRING[30];
    ProductType : E_ProductType;
    PONumber : DINT;
    ShipmentNumber : DINT;
    
    (* Station Timestamps *)
    S1_ArrivalTime : DT;
    S1_StartTime : DT;
    S1_EndTime : DT;
    S1_DepartureTime : DT;
    S1_ServiceMinutes : REAL;
    
    S2_ArrivalTime : DT;
    S2_StartTime : DT;
    S2_EndTime : DT;
    S2_DepartureTime : DT;
    S2_ServiceMinutes : REAL;
    
    S3_ArrivalTime : DT;
    S3_GroundingStartTime : DT;
    S3_GroundingTimeMinutes : REAL;
    S3_GroundingStatus : BOOL;
    S3_FillStartTime : DT;
    S3_FillEndTime : DT;
    S3_DepartureTime : DT;
    S3_FillAmountLiters : REAL;
    S3_ProductiveFillTimeMinutes : REAL;
    S3_FailureDowntimeMinutes : REAL;
    S3_DerivedFlowRateLpm : REAL;
    
    S4_ArrivalTime : DT;
    S4_StartTime : DT;
    S4_EndTime : DT;
    S4_DepartureTime : DT;
    S4_ServiceMinutes : REAL;
    
    O1_ArrivalTime : DT;
    O1_DepartureTime : DT;
    
    (* Failure State *)
    IsFailurePaused : BOOL;
    FailurePauseStartTime : DT;
    FailurePauseEndTime : DT;
    
    (* Status *)
    CurrentStation : E_TruckState;
    CompletedAllStations : BOOL;
    TotalCycleTimeMinutes : REAL;
  END_STRUCT
END_TYPE

TYPE ST_Server :
  STRUCT
    ServerID : INT;
    StationID : INT;
    IsFree : BOOL;
    EndTime : DT;
    CurrentTruckID : UDINT;
    CompletionCount : INT;
  END_STRUCT
END_TYPE

TYPE ST_S3_Bay :
  STRUCT
    BayID : INT;
    StationID : INT;
    IsOccupied : BOOL;
    CurrentTruckID : UDINT;
    CurrentState : E_S3State;
    GroundingEndTime : DT;
    FillEndTime : DT;
    CompletionCount : INT;
  END_STRUCT
END_TYPE

(* ============================================================================ *)
(* EVENT TYPES FOR DATA EXPORT *)
(* ============================================================================ *)

TYPE ST_S1_Event :
  STRUCT
    TruckID : UDINT;
    VehicleNumber : STRING[30];
    ArrivalTime : DT;
    StartTime : DT;
    EndTime : DT;
    ServiceTimeMinutes : REAL;
    QueueWaitMinutes : REAL;
  END_STRUCT
END_TYPE

TYPE ST_S2_Event :
  STRUCT
    TruckID : UDINT;
    VehicleNumber : STRING[30];
    ArrivalTime : DT;
    StartTime : DT;
    EndTime : DT;
    ServiceTimeMinutes : REAL;
    QueueWaitMinutes : REAL;
  END_STRUCT
END_TYPE

TYPE ST_S3_Event :
  STRUCT
    TruckID : UDINT;
    VehicleNumber : STRING[30];
    ProductType : E_ProductType;
    ArrivalTime : DT;
    GroundingStartTime : DT;
    GroundingEndTime : DT;
    GroundingTimeMinutes : REAL;
    FillStartTime : DT;
    FillEndTime : DT;
    FillTimeMinutes : REAL;
    FillAmountLiters : REAL;
    FlowRateLpm : REAL;
    GroundingStatus : BOOL;
    FailurePaused : BOOL;
    FailurePauseDurationMinutes : REAL;
  END_STRUCT
END_TYPE

TYPE ST_S4_Event :
  STRUCT
    TruckID : UDINT;
    VehicleNumber : STRING[30];
    ArrivalTime : DT;
    StartTime : DT;
    EndTime : DT;
    ServiceTimeMinutes : REAL;
    QueueWaitMinutes : REAL;
  END_STRUCT
END_TYPE

TYPE ST_O1_Event :
  STRUCT
    TruckID : UDINT;
    VehicleNumber : STRING[30];
    DepartureTime : DT;
    TotalCycleTimeMinutes : REAL;
  END_STRUCT
END_TYPE

TYPE ST_LineFailure_Event :
  STRUCT
    LineID : INT;
    FailureStartTime : DT;
    RepairEndTime : DT;
    FailureDurationMinutes : REAL;
    AffectedTruckCount : INT;
    FailureSequenceNumber : INT;
  END_STRUCT
END_TYPE

TYPE ST_db_TruckRecord :
  STRUCT
    TruckID : UDINT;
    VehicleNumber : STRING[30];
    ProductType : E_ProductType;
    PONumber : DINT;
    ShipmentNumber : DINT;
    CompanyID : INT;
    CompanyTier : E_CompanyTier;
    S1_ArrivalTime : DT;
    S2_ArrivalTime : DT;
    S3_ArrivalTime : DT;
    S4_ArrivalTime : DT;
  END_STRUCT
END_TYPE

TYPE ST_LineFailure :
  STRUCT
    LineID : INT;
    Status : E_LineStatus;
    FailureThresholdMinutes : REAL;
    AccumulatedFillMinutes : REAL;
    FailureStartTime : DT;
    RepairEndTime : DT;
    FailureCount : INT;
    ActiveFillCount : INT;
  END_STRUCT
END_TYPE
