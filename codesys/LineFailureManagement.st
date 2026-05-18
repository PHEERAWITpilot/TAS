(*
================================================================================
LineFailureManagement.st - Line Failure Simulation
================================================================================
Handles line failure triggers, repair completion, and fill-time accumulation.
================================================================================
*)

PROCEDURE InitializeLineFailures
VAR
END_VAR

  (* Sample initial failure thresholds *)
  L1_FailureThresholdMinutes := TRIANGULAR(MTTF_MIN, MTTF_MODE, MTTF_MAX);
  L2_FailureThresholdMinutes := TRIANGULAR(MTTF_MIN, MTTF_MODE, MTTF_MAX);
  
  L1_AccumulatedFillMinutes := 0.0;
  L2_AccumulatedFillMinutes := 0.0;

END_PROCEDURE

PROCEDURE ProcessL1Failures
VAR
  mttr : REAL;
  event : ST_LineFailure_Event;
END_VAR

  (* Check if failure should trigger *)
  IF L1_Status = OPERATIONAL AND L1_ActiveFillCount > 0 THEN
    IF L1_AccumulatedFillMinutes >= L1_FailureThresholdMinutes THEN
      (* Trigger failure *)
      L1_Status := FAILURE;
      L1_FailureStartTime := SimulationTime;
      
      (* Sample MTTR *)
      mttr := GetMTTR();
      L1_RepairEndTime := AddMinutesToDateTime(SimulationTime, mttr);
      
      (* Increment failure count *)
      L1_FailureCount := L1_FailureCount + 1;
      
      (* Record failure event *)
      IF L1_FailureEventCount < MAX_FAILURES THEN
        event.LineID := 1;
        event.FailureStartTime := SimulationTime;
        event.RepairEndTime := L1_RepairEndTime;
        event.FailureDurationMinutes := mttr;
        event.AffectedTruckCount := L1_ActiveFillCount;
        event.FailureSequenceNumber := L1_FailureCount;
        
        L1_FailureEventCount := L1_FailureEventCount + 1;
        L1_FailureEvents[L1_FailureEventCount] := event;
      END_IF;
    END_IF;
  END_IF;
  
  (* Check if repair complete *)
  IF L1_Status = FAILURE AND SimulationTime >= L1_RepairEndTime THEN
    L1_Status := OPERATIONAL;
    
    (* Reset accumulated fill time *)
    L1_AccumulatedFillMinutes := 0.0;
    
    (* Sample next failure threshold *)
    L1_FailureThresholdMinutes := TRIANGULAR(MTTF_MIN, MTTF_MODE, MTTF_MAX);
  END_IF;

END_PROCEDURE

PROCEDURE ProcessL2Failures
VAR
  mttr : REAL;
  event : ST_LineFailure_Event;
END_VAR

  (* Check if failure should trigger *)
  IF L2_Status = OPERATIONAL AND L2_ActiveFillCount > 0 THEN
    IF L2_AccumulatedFillMinutes >= L2_FailureThresholdMinutes THEN
      (* Trigger failure *)
      L2_Status := FAILURE;
      L2_FailureStartTime := SimulationTime;
      
      (* Sample MTTR *)
      mttr := GetMTTR();
      L2_RepairEndTime := AddMinutesToDateTime(SimulationTime, mttr);
      
      (* Increment failure count *)
      L2_FailureCount := L2_FailureCount + 1;
      
      (* Record failure event *)
      IF L2_FailureEventCount < MAX_FAILURES THEN
        event.LineID := 2;
        event.FailureStartTime := SimulationTime;
        event.RepairEndTime := L2_RepairEndTime;
        event.FailureDurationMinutes := mttr;
        event.AffectedTruckCount := L2_ActiveFillCount;
        event.FailureSequenceNumber := L2_FailureCount;
        
        L2_FailureEventCount := L2_FailureEventCount + 1;
        L2_FailureEvents[L2_FailureEventCount] := event;
      END_IF;
    END_IF;
  END_IF;
  
  (* Check if repair complete *)
  IF L2_Status = FAILURE AND SimulationTime >= L2_RepairEndTime THEN
    L2_Status := OPERATIONAL;
    
    (* Reset accumulated fill time *)
    L2_AccumulatedFillMinutes := 0.0;
    
    (* Sample next failure threshold *)
    L2_FailureThresholdMinutes := TRIANGULAR(MTTF_MIN, MTTF_MODE, MTTF_MAX);
  END_IF;

END_PROCEDURE
