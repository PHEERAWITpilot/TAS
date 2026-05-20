(*
================================================================================
O1_Processing.st - Outlet (O1) Processing and Truck Departure
================================================================================
Handles truck departure from the facility at the exit gate (O1).
O1 has no queue - trucks depart immediately after S4 completion.
Records final departure event and calculates total cycle time.
================================================================================
*)

(* ============================================================================ *)
(* FUNCTION: ProcessO1Queue *)
(* ============================================================================ *)
(* Purpose: Immediate exit for trucks completing S4 *)
(* Logic: *)
(*   - For each truck in O1 queue, departure is immediate *)
(*   - Calculate total cycle time (O1_DepartureTime - S1_ArrivalTime) *)
(*   - Record O1 event *)
(*   - Mark truck as DEPARTED *)
(*   - Remove from O1 queue *)
(* ============================================================================ *)

FUNCTION_BLOCK ProcessO1Queue
VAR
  queue_size : INT;
  i : INT;
  truck_id : UDINT;
  truck : ST_Truck;
  queue_wait_minutes : REAL;
END_VAR

  (* Calculate queue size *)
  IF O1_Tail >= O1_Head THEN
    queue_size := O1_Tail - O1_Head;
  ELSE
    queue_size := (2500 - O1_Head) + O1_Tail;
  END_IF;
  
  (* Process all trucks in O1 queue (immediate exit, no processing) *)
  FOR i := 1 TO queue_size DO
    
    (* Get truck from queue (FIFO) *)
    truck_id := O1_Queue[O1_Head];
    truck := AllTrucks[truck_id];
    
    (* Set O1 timestamps *)
    truck.O1_ArrivalTime := SimulationTime;
    truck.O1_DepartureTime := SimulationTime; (* Immediate departure *)
    
    (* Calculate total cycle time (minutes) *)
    truck.TotalCycleTimeMinutes := GetMinutesBetween(
      truck.S1_ArrivalTime,
      truck.O1_DepartureTime
    );
    
    (* Mark truck as completed *)
    truck.CurrentStation := DEPARTED;
    truck.CompletedAllStations := TRUE;
    
    (* Record O1 event *)
    IF O1_EventCount < MAX_EVENTS THEN
      O1_Events[O1_EventCount + 1].TruckID := truck_id;
      O1_Events[O1_EventCount + 1].VehicleNumber := truck.VehicleNumber;
      O1_Events[O1_EventCount + 1].DepartureTime := truck.O1_DepartureTime;
      O1_Events[O1_EventCount + 1].TotalCycleTimeMinutes := truck.TotalCycleTimeMinutes;
      O1_EventCount := O1_EventCount + 1;
    END_IF;
    
    (* Update truck in global array *)
    AllTrucks[truck_id] := truck;
    
    (* Dequeue (circular queue wraparound) *)
    O1_Head := O1_Head + 1;
    IF O1_Head > 2500 THEN
      O1_Head := 1;
    END_IF;
    
    (* Increment departure counter *)
    TotalDepartures := TotalDepartures + 1;
    
  END_FOR;

END_FUNCTION_BLOCK

(* ============================================================================ *)
(* FUNCTION: GetMinutesBetween *)
(* ============================================================================ *)
(* Purpose: Calculate minutes between two timestamps *)
(* Input: start_time, end_time (DT type) *)
(* Output: Minutes as REAL *)
(* ============================================================================ *)

FUNCTION GetMinutesBetween : REAL
VAR_INPUT
  start_time : DT;
  end_time : DT;
END_VAR
VAR
  seconds_diff : DINT;
END_VAR

  seconds_diff := DT_TO_DINT(end_time) - DT_TO_DINT(start_time);
  GetMinutesBetween := DINT_TO_REAL(seconds_diff) / 60.0;

END_FUNCTION

(* ============================================================================ *)
(* FUNCTION: RecordO1Event *)
(* ============================================================================ *)
(* Purpose: Record O1 departure event to buffer *)
(* Validates buffer capacity before recording *)
(* ============================================================================ *)

FUNCTION RecordO1Event
VAR_INPUT
  truck_id : UDINT;
  vehicle_number : STRING;
  departure_time : DT;
  total_cycle_minutes : REAL;
END_VAR

  IF O1_EventCount < MAX_EVENTS THEN
    O1_Events[O1_EventCount + 1].TruckID := truck_id;
    O1_Events[O1_EventCount + 1].VehicleNumber := vehicle_number;
    O1_Events[O1_EventCount + 1].DepartureTime := departure_time;
    O1_Events[O1_EventCount + 1].TotalCycleTimeMinutes := total_cycle_minutes;
    O1_EventCount := O1_EventCount + 1;
  END_IF;

END_FUNCTION

(* ============================================================================ *)
(* FUNCTION: IsO1QueueEmpty *)
(* ============================================================================ *)
(* Purpose: Check if O1 queue has any trucks *)
(* Returns: TRUE if empty, FALSE if trucks present *)
(* ============================================================================ *)

FUNCTION IsO1QueueEmpty : BOOL

  IF O1_Head = O1_Tail THEN
    IsO1QueueEmpty := TRUE;
  ELSE
    IsO1QueueEmpty := FALSE;
  END_IF;

END_FUNCTION

(* ============================================================================ *)
(* FUNCTION: GetO1QueueSize *)
(* ============================================================================ *)
(* Purpose: Get number of trucks currently in O1 queue *)
(* Returns: Number of trucks waiting at exit gate *)
(* ============================================================================ *)

FUNCTION GetO1QueueSize : INT
VAR
  size : INT;
END_VAR

  IF O1_Tail >= O1_Head THEN
    size := O1_Tail - O1_Head;
  ELSE
    size := (2500 - O1_Head) + O1_Tail;
  END_IF;
  
  GetO1QueueSize := size;

END_FUNCTION

(* ============================================================================ *)
(* FUNCTION: EnqueueO1 *)
(* ============================================================================ *)
(* Purpose: Add truck to O1 exit queue *)
(* Input: truck_id (UDINT) *)
(* Logic: Append to circular queue with wraparound *)
(* ============================================================================ *)

FUNCTION EnqueueO1
VAR_INPUT
  truck_id : UDINT;
END_VAR
VAR
  next_tail : INT;
END_VAR

  next_tail := O1_Tail + 1;
  IF next_tail > 2500 THEN
    next_tail := 1;
  END_IF;
  
  (* Check if queue is full (wraparound detected) *)
  IF next_tail <> O1_Head THEN
    O1_Queue[O1_Tail] := truck_id;
    O1_Tail := next_tail;
  END_IF;

END_FUNCTION
