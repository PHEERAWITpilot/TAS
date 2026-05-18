(*
================================================================================
S3Processing.st - S3 Grounding, Filling, and Failure Integration
================================================================================
Handles grounding state machine, fill processing, and failure pausing logic.
================================================================================
*)

PROCEDURE ProcessS3aProcessing
VAR
  bay_idx : INT;
  truck_idx : UDINT;
  truck : ST_Truck;
  event : ST_S3_Event;
  failure_pause_duration : REAL;
  i : INT;
END_VAR

  FOR bay_idx := 1 TO S3A_SLOTS DO
    IF S3a_Bays[bay_idx].IsOccupied THEN
      truck_idx := S3a_Bays[bay_idx].CurrentTruckID;
      
      IF truck_idx > 0 AND truck_idx <= TruckCount THEN
        truck := AllTrucks[truck_idx];
        
        (* Handle grounding state *)
        IF S3a_Bays[bay_idx].CurrentState = GROUNDING THEN
          IF SimulationTime >= S3a_Bays[bay_idx].GroundingEndTime THEN
            (* Transition to filling *)
            AllTrucks[truck_idx].S3_GroundingStatus := TRUE;
            S3a_Bays[bay_idx].CurrentState := FILLING;
          END_IF;
        END_IF;
        
        (* Handle filling state *)
        IF S3a_Bays[bay_idx].CurrentState = FILLING THEN
          (* Accumulate fill time if line is operational *)
          IF L1_Status = OPERATIONAL THEN
            L1_AccumulatedFillMinutes := L1_AccumulatedFillMinutes + DINT_TO_REAL(SCAN_STEP_SECONDS) / 60.0;
          ELSE
            (* Line failed - pause truck *)
            IF NOT truck.IsFailurePaused THEN
              AllTrucks[truck_idx].IsFailurePaused := TRUE;
              AllTrucks[truck_idx].FailurePauseStartTime := SimulationTime;
              S3a_Bays[bay_idx].CurrentState := PAUSED;
            END_IF;
          END_IF;
          
          (* Check if fill complete *)
          IF SimulationTime >= S3a_Bays[bay_idx].FillEndTime AND L1_Status = OPERATIONAL THEN
            AllTrucks[truck_idx].S3_FillEndTime := SimulationTime;
            AllTrucks[truck_idx].S3_DerivedFlowRateLpm := CalculateFlowRate(
              AllTrucks[truck_idx].S3_FillAmountLiters,
              AllTrucks[truck_idx].S3_ProductiveFillTimeMinutes
            );
            
            (* Calculate failure downtime if paused *)
            IF truck.IsFailurePaused THEN
              failure_pause_duration := GetMinutesBetween(
                AllTrucks[truck_idx].FailurePauseEndTime,
                SimulationTime
              );
              AllTrucks[truck_idx].S3_FailureDowntimeMinutes := failure_pause_duration;
            END_IF;
            
            (* Record event *)
            IF S3a_EventCount < MAX_EVENTS THEN
              event.TruckID := truck_idx;
              event.VehicleNumber := truck.VehicleNumber;
              event.ProductType := DIESEL;
              event.ArrivalTime := truck.S3_ArrivalTime;
              event.GroundingStartTime := truck.S3_GroundingStartTime;
              event.GroundingEndTime := AddMinutesToDateTime(truck.S3_GroundingStartTime, truck.S3_GroundingTimeMinutes);
              event.GroundingTimeMinutes := truck.S3_GroundingTimeMinutes;
              event.FillStartTime := truck.S3_FillStartTime;
              event.FillEndTime := truck.S3_FillEndTime;
              event.FillTimeMinutes := truck.S3_ProductiveFillTimeMinutes;
              event.FillAmountLiters := truck.S3_FillAmountLiters;
              event.FlowRateLpm := truck.S3_DerivedFlowRateLpm;
              event.GroundingStatus := truck.S3_GroundingStatus;
              event.FailurePaused := truck.IsFailurePaused;
              event.FailurePauseDurationMinutes := truck.S3_FailureDowntimeMinutes;
              
              S3a_EventCount := S3a_EventCount + 1;
              S3a_Events[S3a_EventCount] := event;
            END_IF;
            
            (* Move to S4 queue *)
            Enqueue(S4_Queue, S4_Head, S4_Tail, truck_idx, 2500);
            
            (* Bay complete *)
            S3a_Bays[bay_idx].IsOccupied := FALSE;
            S3a_Bays[bay_idx].CurrentState := IDLE;
            S3a_Bays[bay_idx].CompletionCount := S3a_Bays[bay_idx].CompletionCount + 1;
            
            (* Decrement active fill *)
            L1_ActiveFillCount := L1_ActiveFillCount - 1;
          END_IF;
        END_IF;
        
        (* Handle paused state *)
        IF S3a_Bays[bay_idx].CurrentState = PAUSED THEN
          (* Check if failure resolved *)
          IF L1_Status = OPERATIONAL THEN
            AllTrucks[truck_idx].FailurePauseEndTime := SimulationTime;
            AllTrucks[truck_idx].IsFailurePaused := FALSE;
            
            (* Resume filling *)
            S3a_Bays[bay_idx].CurrentState := FILLING;
            
            (* Recalculate fill end time *)
            failure_pause_duration := GetMinutesBetween(
              AllTrucks[truck_idx].FailurePauseStartTime,
              SimulationTime
            );
            S3a_Bays[bay_idx].FillEndTime := AddMinutesToDateTime(
              S3a_Bays[bay_idx].FillEndTime,
              failure_pause_duration
            );
          END_IF;
        END_IF;
      END_IF;
    END_IF;
  END_FOR;

END_PROCEDURE

PROCEDURE ProcessS3bProcessing
VAR
  bay_idx : INT;
  truck_idx : UDINT;
  truck : ST_Truck;
  event : ST_S3_Event;
  failure_pause_duration : REAL;
  i : INT;
END_VAR

  FOR bay_idx := 1 TO S3B_SLOTS DO
    IF S3b_Bays[bay_idx].IsOccupied THEN
      truck_idx := S3b_Bays[bay_idx].CurrentTruckID;
      
      IF truck_idx > 0 AND truck_idx <= TruckCount THEN
        truck := AllTrucks[truck_idx];
        
        (* Handle grounding state *)
        IF S3b_Bays[bay_idx].CurrentState = GROUNDING THEN
          IF SimulationTime >= S3b_Bays[bay_idx].GroundingEndTime THEN
            (* Transition to filling *)
            AllTrucks[truck_idx].S3_GroundingStatus := TRUE;
            S3b_Bays[bay_idx].CurrentState := FILLING;
          END_IF;
        END_IF;
        
        (* Handle filling state *)
        IF S3b_Bays[bay_idx].CurrentState = FILLING THEN
          (* Accumulate fill time if line is operational *)
          IF L2_Status = OPERATIONAL THEN
            L2_AccumulatedFillMinutes := L2_AccumulatedFillMinutes + DINT_TO_REAL(SCAN_STEP_SECONDS) / 60.0;
          ELSE
            (* Line failed - pause truck *)
            IF NOT truck.IsFailurePaused THEN
              AllTrucks[truck_idx].IsFailurePaused := TRUE;
              AllTrucks[truck_idx].FailurePauseStartTime := SimulationTime;
              S3b_Bays[bay_idx].CurrentState := PAUSED;
            END_IF;
          END_IF;
          
          (* Check if fill complete *)
          IF SimulationTime >= S3b_Bays[bay_idx].FillEndTime AND L2_Status = OPERATIONAL THEN
            AllTrucks[truck_idx].S3_FillEndTime := SimulationTime;
            AllTrucks[truck_idx].S3_DerivedFlowRateLpm := CalculateFlowRate(
              AllTrucks[truck_idx].S3_FillAmountLiters,
              AllTrucks[truck_idx].S3_ProductiveFillTimeMinutes
            );
            
            (* Calculate failure downtime if paused *)
            IF truck.IsFailurePaused THEN
              failure_pause_duration := GetMinutesBetween(
                AllTrucks[truck_idx].FailurePauseEndTime,
                SimulationTime
              );
              AllTrucks[truck_idx].S3_FailureDowntimeMinutes := failure_pause_duration;
            END_IF;
            
            (* Record event *)
            IF S3b_EventCount < MAX_EVENTS THEN
              event.TruckID := truck_idx;
              event.VehicleNumber := truck.VehicleNumber;
              event.ProductType := GASOHOL95;
              event.ArrivalTime := truck.S3_ArrivalTime;
              event.GroundingStartTime := truck.S3_GroundingStartTime;
              event.GroundingEndTime := AddMinutesToDateTime(truck.S3_GroundingStartTime, truck.S3_GroundingTimeMinutes);
              event.GroundingTimeMinutes := truck.S3_GroundingTimeMinutes;
              event.FillStartTime := truck.S3_FillStartTime;
              event.FillEndTime := truck.S3_FillEndTime;
              event.FillTimeMinutes := truck.S3_ProductiveFillTimeMinutes;
              event.FillAmountLiters := truck.S3_FillAmountLiters;
              event.FlowRateLpm := truck.S3_DerivedFlowRateLpm;
              event.GroundingStatus := truck.S3_GroundingStatus;
              event.FailurePaused := truck.IsFailurePaused;
              event.FailurePauseDurationMinutes := truck.S3_FailureDowntimeMinutes;
              
              S3b_EventCount := S3b_EventCount + 1;
              S3b_Events[S3b_EventCount] := event;
            END_IF;
            
            (* Move to S4 queue *)
            Enqueue(S4_Queue, S4_Head, S4_Tail, truck_idx, 2500);
            
            (* Bay complete *)
            S3b_Bays[bay_idx].IsOccupied := FALSE;
            S3b_Bays[bay_idx].CurrentState := IDLE;
            S3b_Bays[bay_idx].CompletionCount := S3b_Bays[bay_idx].CompletionCount + 1;
            
            (* Decrement active fill *)
            L2_ActiveFillCount := L2_ActiveFillCount - 1;
          END_IF;
        END_IF;
        
        (* Handle paused state *)
        IF S3b_Bays[bay_idx].CurrentState = PAUSED THEN
          (* Check if failure resolved *)
          IF L2_Status = OPERATIONAL THEN
            AllTrucks[truck_idx].FailurePauseEndTime := SimulationTime;
            AllTrucks[truck_idx].IsFailurePaused := FALSE;
            
            (* Resume filling *)
            S3b_Bays[bay_idx].CurrentState := FILLING;
            
            (* Recalculate fill end time *)
            failure_pause_duration := GetMinutesBetween(
              AllTrucks[truck_idx].FailurePauseStartTime,
              SimulationTime
            );
            S3b_Bays[bay_idx].FillEndTime := AddMinutesToDateTime(
              S3b_Bays[bay_idx].FillEndTime,
              failure_pause_duration
            );
          END_IF;
        END_IF;
      END_IF;
    END_IF;
  END_FOR;

END_PROCEDURE
