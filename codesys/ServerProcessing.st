(*
================================================================================
ServerProcessing.st - Server Completion and State Transitions
================================================================================
Logic to complete service and advance trucks to next stations.
================================================================================
*)

PROCEDURE CompleteS1Service
VAR
  server_idx : INT;
  truck_idx : UDINT;
  event : ST_S1_Event;
  queue_wait : REAL;
END_VAR

  FOR server_idx := 1 TO S1_SERVERS DO
    IF NOT S1_ServerFree[server_idx] AND SimulationTime >= S1_ServerEndTime[server_idx] THEN
      
      (* Find truck on this server *)
      (* In real implementation, would track truck_idx per server *)
      (* Simplified: find truck with matching end time *)
      
      (* Mark server free *)
      S1_ServerFree[server_idx] := TRUE;
      
      (* Move truck to S2 queue *)
      (* Would need to find which truck was being processed *)
      
    END_IF;
  END_FOR;

END_PROCEDURE

PROCEDURE CompleteS2Service
VAR
  truck_idx : UDINT;
  event : ST_S2_Event;
  queue_wait : REAL;
END_VAR

  IF NOT S2_ServerFree AND SimulationTime >= S2_ServerEndTime THEN
    
    (* Mark server free *)
    S2_ServerFree := TRUE;
    
    (* Find truck and route to S3 based on product type *)
    (* Move to appropriate S3 queue *)
    
  END_IF;

END_PROCEDURE

PROCEDURE CompleteS4Service
VAR
  truck_idx : UDINT;
  event : ST_S4_Event;
  queue_wait : REAL;
END_VAR

  IF NOT S4_ServerFree AND SimulationTime >= S4_ServerEndTime THEN
    
    (* Mark server free *)
    S4_ServerFree := TRUE;
    
    (* Move truck to O1 queue *)
    
  END_IF;

END_PROCEDURE

PROCEDURE ProcessO1Queue
VAR
  truck_idx : UDINT;
  truck : ST_Truck;
  event : ST_O1_Event;
  cycle_time : REAL;
END_VAR

  IF NOT IsQueueEmpty(O1_Head, O1_Tail) THEN
    truck_idx := QueuePeek(O1_Queue, O1_Head, O1_Tail);
    
    IF truck_idx > 0 AND truck_idx <= TruckCount THEN
      truck := AllTrucks[truck_idx];
      
      (* Dequeue *)
      Dequeue(O1_Queue, O1_Head, O1_Tail, 2500);
      
      (* Update truck *)
      AllTrucks[truck_idx].O1_ArrivalTime := SimulationTime;
      AllTrucks[truck_idx].O1_DepartureTime := SimulationTime;
      AllTrucks[truck_idx].CurrentStation := O1;
      
      (* Calculate total cycle time *)
      cycle_time := GetMinutesBetween(AllTrucks[truck_idx].S1_ArrivalTime, SimulationTime);
      AllTrucks[truck_idx].TotalCycleTimeMinutes := cycle_time;
      AllTrucks[truck_idx].CompletedAllStations := TRUE;
      
      (* Record O1 event *)
      IF O1_EventCount < MAX_EVENTS THEN
        event.TruckID := truck_idx;
        event.VehicleNumber := truck.VehicleNumber;
        event.DepartureTime := SimulationTime;
        event.TotalCycleTimeMinutes := cycle_time;
        
        O1_EventCount := O1_EventCount + 1;
        O1_Events[O1_EventCount] := event;
      END_IF;
      
      (* Increment departure counter *)
      TotalDepartures := TotalDepartures + 1;
      AllTrucks[truck_idx].CurrentStation := DEPARTED;
    END_IF;
  END_IF;

END_PROCEDURE
