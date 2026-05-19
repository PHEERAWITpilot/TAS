(*
================================================================================
PLC_PRG.st - Main Simulation Program
================================================================================
30-day fuel distribution simulation with truck generation and state processing.
Runs 2,592,000 scans at 1 scan per second.
================================================================================
*)

PROGRAM PLC_PRG
VAR
  scan_count : UDINT := 0;
  next_arrival_scan : UDINT := 0;
  i : INT;
  truck_idx : UDINT;
  truck : ST_Truck;
  hourly_arrivals : INT;
  day_of_sim : INT;
  hour_of_day : INT;
  min_of_hour : INT;
END_VAR

  (* Initialize on first scan *)
  IF scan_count = 0 THEN
    SimulationStartTime := DATE_AND_TIME();
    SimulationTime := SimulationStartTime;
    
    (* Initialize systems *)
    InitializeServers();
    InitializeLineFailures();
    
    (* Schedule first truck arrival *)
    next_arrival_scan := RAND_INT(60, 300); (* 1-5 minutes *)
  END_IF;
  
  (* Main simulation loop - runs for 30 days *)
  IF scan_count < TOTAL_SCANS THEN
    
    (* Increment simulation time *)
    SimulationTime := AddSecondsToDateTime(SimulationTime, SCAN_STEP_SECONDS);
    scan_count := scan_count + 1;
    
    (* === TRUCK ARRIVAL GENERATION === *)
    IF scan_count = next_arrival_scan THEN
      (* Sample hourly arrival rate (POISSON distributed) *)
      day_of_sim := INT_TO_INT(scan_count / 1440); (* 1440 scans per day *)
      hour_of_day := INT_TO_INT((scan_count MOD 1440) / 60);
      
      (* Get arrival rate for this hour *)
      hourly_arrivals := GetArrivalRateByHour(hour_of_day, day_of_sim);
      
      IF TruckCount < MAX_TRUCKS THEN
        TruckCount := TruckCount + 1;
        truck_idx := TruckCount;
        
        (* Generate truck *)
        AllTrucks[truck_idx].TruckID := truck_idx;
        AllTrucks[truck_idx].VehicleNumber := GenerateVehicleNumber();
        AllTrucks[truck_idx].CompanyID := RAND_INT(1, 500);
        AllTrucks[truck_idx].ProductType := RAND_INT(0, 1); (* 0=Diesel, 1=Gasohol *)
        AllTrucks[truck_idx].PONumber := GenerateShipmentNumber();
        AllTrucks[truck_idx].S1_ArrivalTime := SimulationTime;
        AllTrucks[truck_idx].CurrentStation := S1;
        AllTrucks[truck_idx].CompletedAllStations := FALSE;
        
        (* Enqueue to S1 *)
        Enqueue(S1_Queue, S1_Head, S1_Tail, truck_idx, 2500);
        TotalArrivals := TotalArrivals + 1;
      END_IF;
      
      (* Schedule next arrival *)
      next_arrival_scan := scan_count + RAND_INT(60, 300);
    END_IF;
    
    (* === QUEUE PROCESSING === *)
    ProcessS1Queue();
    ProcessS2Queue();
    ProcessS3aQueue();
    ProcessS3bQueue();
    ProcessS4Queue();
    ProcessO1Queue();
    
    (* === SERVER COMPLETION === *)
    CompleteS1Service();
    CompleteS2Service();
    CompleteS4Service();
    
    (* === S3 PROCESSING (GROUNDING + FILLING) === *)
    ProcessS3aProcessing();
    ProcessS3bProcessing();
    
    (* === LINE FAILURE MANAGEMENT === *)
    ProcessL1Failures();
    ProcessL2Failures();
    
  END_IF;
  
  (* Simulation complete *)
  IF scan_count >= TOTAL_SCANS THEN
    SimulationComplete := TRUE;
    ExportAllEvents();
  END_IF;

END_PROGRAM
