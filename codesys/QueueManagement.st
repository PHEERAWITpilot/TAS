(*
================================================================================
QueueManagement.st - Queue Processing and Server Allocation
================================================================================
Queue advancement logic for all stations with server allocation.
================================================================================
*)

PROCEDURE InitializeServers
VAR
  i : INT;
END_VAR

  (* S1 Servers *)
  FOR i := 1 TO S1_SERVERS DO
    S1_ServerFree[i] := TRUE;
  END_FOR;
  
  (* S2 Server *)
  S2_ServerFree := TRUE;
  
  (* S3A Bays *)
  FOR i := 1 TO S3A_SLOTS DO
    S3a_Bays[i].BayID := i;
    S3a_Bays[i].StationID := 30;
    S3a_Bays[i].IsOccupied := FALSE;
    S3a_Bays[i].CurrentState := IDLE;
  END_FOR;
  
  (* S3B Bays *)
  FOR i := 1 TO S3B_SLOTS DO
    S3b_Bays[i].BayID := i;
    S3b_Bays[i].StationID := 31;
    S3b_Bays[i].IsOccupied := FALSE;
    S3b_Bays[i].CurrentState := IDLE;
  END_FOR;
  
  (* S4 Server *)
  S4_ServerFree := TRUE;

END_PROCEDURE

PROCEDURE ProcessS1Queue
VAR
  truck_idx : UDINT;
  truck : ST_Truck;
  service_time : REAL;
  server_idx : INT;
  i : INT;
END_VAR

  (* Find available S1 server *)
  FOR server_idx := 1 TO S1_SERVERS DO
    IF S1_ServerFree[server_idx] AND NOT IsQueueEmpty(S1_Head, S1_Tail) THEN
      truck_idx := QueuePeek(S1_Queue, S1_Head, S1_Tail);
      
      IF truck_idx > 0 AND truck_idx <= TruckCount THEN
        truck := AllTrucks[truck_idx];
        
        (* Dequeue *)
        Dequeue(S1_Queue, S1_Head, S1_Tail, 2500);
        
        (* Sample service time *)
        service_time := GetServiceTimeS1();
        
        (* Update truck *)
        AllTrucks[truck_idx].S1_StartTime := SimulationTime;
        AllTrucks[truck_idx].S1_ServiceMinutes := service_time;
        AllTrucks[truck_idx].S1_EndTime := AddMinutesToDateTime(SimulationTime, service_time);
        AllTrucks[truck_idx].CurrentStation := S1;
        
        (* Mark server busy *)
        S1_ServerFree[server_idx] := FALSE;
        S1_ServerEndTime[server_idx] := AllTrucks[truck_idx].S1_EndTime;
      END_IF;
    END_IF;
  END_FOR;

END_PROCEDURE

PROCEDURE ProcessS2Queue
VAR
  truck_idx : UDINT;
  truck : ST_Truck;
  service_time : REAL;
END_VAR

  IF S2_ServerFree AND NOT IsQueueEmpty(S2_Head, S2_Tail) THEN
    truck_idx := QueuePeek(S2_Queue, S2_Head, S2_Tail);
    
    IF truck_idx > 0 AND truck_idx <= TruckCount THEN
      truck := AllTrucks[truck_idx];
      
      (* Dequeue *)
      Dequeue(S2_Queue, S2_Head, S2_Tail, 2500);
      
      (* Sample service time *)
      service_time := GetServiceTimeS2();
      
      (* Update truck *)
      AllTrucks[truck_idx].S2_StartTime := SimulationTime;
      AllTrucks[truck_idx].S2_ServiceMinutes := service_time;
      AllTrucks[truck_idx].S2_EndTime := AddMinutesToDateTime(SimulationTime, service_time);
      AllTrucks[truck_idx].CurrentStation := S2;
      
      (* Mark server busy *)
      S2_ServerFree := FALSE;
      S2_ServerEndTime := AllTrucks[truck_idx].S2_EndTime;
    END_IF;
  END_IF;

END_PROCEDURE

PROCEDURE ProcessS3aQueue
VAR
  truck_idx : UDINT;
  bay_idx : INT;
  grounding_time : REAL;
  fill_time : REAL;
  i : INT;
END_VAR

  (* Find available bay *)
  FOR bay_idx := 1 TO S3A_SLOTS DO
    IF NOT S3a_Bays[bay_idx].IsOccupied AND NOT IsQueueEmpty(S3a_Head, S3a_Tail) THEN
      truck_idx := QueuePeek(S3a_Queue, S3a_Head, S3a_Tail);
      
      IF truck_idx > 0 AND truck_idx <= TruckCount THEN
        (* Dequeue *)
        Dequeue(S3a_Queue, S3a_Head, S3a_Tail, 2500);
        
        (* Sample grounding and fill times *)
        grounding_time := GetGroundingTime();
        fill_time := GetProductiveFillTime();
        
        (* Update truck *)
        AllTrucks[truck_idx].S3_ArrivalTime := SimulationTime;
        AllTrucks[truck_idx].S3_GroundingStartTime := SimulationTime;
        AllTrucks[truck_idx].S3_GroundingTimeMinutes := grounding_time;
        AllTrucks[truck_idx].S3_GroundingStatus := FALSE;
        AllTrucks[truck_idx].S3_FillStartTime := AddMinutesToDateTime(SimulationTime, grounding_time);
        AllTrucks[truck_idx].S3_ProductiveFillTimeMinutes := fill_time;
        AllTrucks[truck_idx].S3_FillAmountLiters := GetFillAmountByProduct(DIESEL);
        AllTrucks[truck_idx].S3_FillEndTime := AddMinutesToDateTime(AllTrucks[truck_idx].S3_FillStartTime, fill_time);
        AllTrucks[truck_idx].CurrentStation := S3;
        
        (* Update bay *)
        S3a_Bays[bay_idx].IsOccupied := TRUE;
        S3a_Bays[bay_idx].CurrentTruckID := truck_idx;
        S3a_Bays[bay_idx].CurrentState := GROUNDING;
        S3a_Bays[bay_idx].GroundingEndTime := AddMinutesToDateTime(SimulationTime, grounding_time);
        S3a_Bays[bay_idx].FillEndTime := AddMinutesToDateTime(AllTrucks[truck_idx].S3_FillStartTime, fill_time);
        
        (* Increment active fill count *)
        L1_ActiveFillCount := L1_ActiveFillCount + 1;
      END_IF;
    END_IF;
  END_FOR;

END_PROCEDURE

PROCEDURE ProcessS3bQueue
VAR
  truck_idx : UDINT;
  bay_idx : INT;
  grounding_time : REAL;
  fill_time : REAL;
  i : INT;
END_VAR

  (* Find available bay *)
  FOR bay_idx := 1 TO S3B_SLOTS DO
    IF NOT S3b_Bays[bay_idx].IsOccupied AND NOT IsQueueEmpty(S3b_Head, S3b_Tail) THEN
      truck_idx := QueuePeek(S3b_Queue, S3b_Head, S3b_Tail);
      
      IF truck_idx > 0 AND truck_idx <= TruckCount THEN
        (* Dequeue *)
        Dequeue(S3b_Queue, S3b_Head, S3b_Tail, 2500);
        
        (* Sample grounding and fill times *)
        grounding_time := GetGroundingTime();
        fill_time := GetProductiveFillTime();
        
        (* Update truck *)
        AllTrucks[truck_idx].S3_ArrivalTime := SimulationTime;
        AllTrucks[truck_idx].S3_GroundingStartTime := SimulationTime;
        AllTrucks[truck_idx].S3_GroundingTimeMinutes := grounding_time;
        AllTrucks[truck_idx].S3_GroundingStatus := FALSE;
        AllTrucks[truck_idx].S3_FillStartTime := AddMinutesToDateTime(SimulationTime, grounding_time);
        AllTrucks[truck_idx].S3_ProductiveFillTimeMinutes := fill_time;
        AllTrucks[truck_idx].S3_FillAmountLiters := GetFillAmountByProduct(GASOHOL95);
        AllTrucks[truck_idx].S3_FillEndTime := AddMinutesToDateTime(AllTrucks[truck_idx].S3_FillStartTime, fill_time);
        AllTrucks[truck_idx].CurrentStation := S3;
        
        (* Update bay *)
        S3b_Bays[bay_idx].IsOccupied := TRUE;
        S3b_Bays[bay_idx].CurrentTruckID := truck_idx;
        S3b_Bays[bay_idx].CurrentState := GROUNDING;
        S3b_Bays[bay_idx].GroundingEndTime := AddMinutesToDateTime(SimulationTime, grounding_time);
        S3b_Bays[bay_idx].FillEndTime := AddMinutesToDateTime(AllTrucks[truck_idx].S3_FillStartTime, fill_time);
        
        (* Increment active fill count *)
        L2_ActiveFillCount := L2_ActiveFillCount + 1;
      END_IF;
    END_IF;
  END_FOR;

END_PROCEDURE

PROCEDURE ProcessS4Queue
VAR
  truck_idx : UDINT;
  truck : ST_Truck;
  service_time : REAL;
END_VAR

  IF S4_ServerFree AND NOT IsQueueEmpty(S4_Head, S4_Tail) THEN
    truck_idx := QueuePeek(S4_Queue, S4_Head, S4_Tail);
    
    IF truck_idx > 0 AND truck_idx <= TruckCount THEN
      truck := AllTrucks[truck_idx];
      
      (* Dequeue *)
      Dequeue(S4_Queue, S4_Head, S4_Tail, 2500);
      
      (* Sample service time *)
      service_time := GetServiceTimeS4();
      
      (* Update truck *)
      AllTrucks[truck_idx].S4_StartTime := SimulationTime;
      AllTrucks[truck_idx].S4_ServiceMinutes := service_time;
      AllTrucks[truck_idx].S4_EndTime := AddMinutesToDateTime(SimulationTime, service_time);
      AllTrucks[truck_idx].CurrentStation := S4;
      
      (* Mark server busy *)
      S4_ServerFree := FALSE;
      S4_ServerEndTime := AllTrucks[truck_idx].S4_EndTime;
    END_IF;
  END_IF;

END_PROCEDURE
