(*
================================================================================
SimulationCore.st - Core Utility Functions
================================================================================
Time manipulation, service time sampling, fill amount generation, and
truck lookup utilities.
================================================================================
*)

(* ============================================================================ *)
(* TIME UTILITIES *)
(* ============================================================================ *)

FUNCTION GetHourOfDay : INT
VAR_INPUT
  CurrentTime : DT;
END_VAR
VAR
  hour_val : INT;
END_VAR

  hour_val := HOUR(CurrentTime);
  IF hour_val < 0 THEN
    GetHourOfDay := 0;
  ELSIF hour_val > 23 THEN
    GetHourOfDay := 23;
  ELSE
    GetHourOfDay := hour_val;
  END_IF;

END_FUNCTION

FUNCTION AddMinutesToDateTime : DT
VAR_INPUT
  BaseTime : DT;
  Minutes : REAL;
END_VAR
VAR
  TotalSeconds : DINT;
  TimeInterval : TIME;
END_VAR

  TotalSeconds := REAL_TO_DINT(Minutes * 60.0);
  TimeInterval := DINT_TO_TIME(TotalSeconds * 1000); (* Convert to milliseconds *)
  AddMinutesToDateTime := BaseTime + TimeInterval;

END_FUNCTION

FUNCTION GetMinutesBetween : REAL
VAR_INPUT
  StartTime : DT;
  EndTime : DT;
END_VAR
VAR
  diff_seconds : DINT;
END_VAR

  (* Simple calculation: assumes times are in correct order *)
  IF EndTime > StartTime THEN
    diff_seconds := DT_TO_DINT(EndTime) - DT_TO_DINT(StartTime);
    GetMinutesBetween := DINT_TO_REAL(diff_seconds) / 60.0;
  ELSE
    GetMinutesBetween := 0.0;
  END_IF;

END_FUNCTION

(* ============================================================================ *)
(* SERVICE TIME SAMPLERS *)
(* ============================================================================ *)

FUNCTION GetServiceTimeS1 : REAL

  GetServiceTimeS1 := TRIANGULAR(S1_SERVICE_MIN, S1_SERVICE_MODE, S1_SERVICE_MAX);

END_FUNCTION

FUNCTION GetServiceTimeS2 : REAL

  GetServiceTimeS2 := TRIANGULAR(S2_SERVICE_MIN, S2_SERVICE_MODE, S2_SERVICE_MAX);

END_FUNCTION

FUNCTION GetServiceTimeS4 : REAL

  GetServiceTimeS4 := TRIANGULAR(S4_SERVICE_MIN, S4_SERVICE_MODE, S4_SERVICE_MAX);

END_FUNCTION

FUNCTION GetGroundingTime : REAL

  GetGroundingTime := TRIANGULAR(GROUNDING_MIN, GROUNDING_MODE, GROUNDING_MAX);

END_FUNCTION

FUNCTION GetProductiveFillTime : REAL

  GetProductiveFillTime := TRIANGULAR(PRODUCTIVE_FILL_MIN, PRODUCTIVE_FILL_MODE, PRODUCTIVE_FILL_MAX);

END_FUNCTION

FUNCTION GetMTTR : REAL

  GetMTTR := TRIANGULAR(MTTR_MIN, MTTR_MODE, MTTR_MAX);

END_FUNCTION

(* ============================================================================ *)
(* FILL AMOUNT GENERATION *)
(* ============================================================================ *)

FUNCTION GetFillAmountByProduct : REAL
VAR_INPUT
  ProductType : E_ProductType;
END_VAR

  CASE ProductType OF
    DIESEL:
      GetFillAmountByProduct := TRIANGULAR(DIESEL_FILL_MIN, DIESEL_FILL_MODE, DIESEL_FILL_MAX);
    GASOHOL95:
      GetFillAmountByProduct := TRIANGULAR(GASOHOL_FILL_MIN, GASOHOL_FILL_MODE, GASOHOL_FILL_MAX);
  ELSE
    GetFillAmountByProduct := DIESEL_FILL_MODE; (* Default to diesel *)
  END_CASE;

END_FUNCTION

(* ============================================================================ *)
(* TRUCK ID GENERATION *)
(* ============================================================================ *)

FUNCTION GeneratePONumber : DINT
VAR_OUTPUT
  Result : DINT;
END_VAR

  Result := NextPONumber;
  NextPONumber := NextPONumber + 1;

END_FUNCTION

FUNCTION GenerateShipmentNumber : DINT
VAR_OUTPUT
  Result : DINT;
END_VAR

  Result := NextShipmentNumber;
  NextShipmentNumber := NextShipmentNumber + 1;

END_FUNCTION

(* ============================================================================ *)
(* TRUCK LOOKUP *)
(* ============================================================================ *)

FUNCTION FindTruckByID : UDINT
VAR_INPUT
  TruckID : UDINT;
END_VAR
VAR
  i : UDINT;
END_VAR

  FOR i := 1 TO TruckCount DO
    IF AllTrucks[i].TruckID = TruckID THEN
      FindTruckByID := i;
      RETURN;
    END_IF;
  END_FOR;
  
  FindTruckByID := 0; (* Not found *)

END_FUNCTION

(* ============================================================================ *)
(* VEHICLE SELECTION (with cooldown check) *)
(* ============================================================================ *)

FUNCTION SelectVehicle : STRING[30]
VAR
  idx : INT;
  attempts : INT := 0;
  cooldown_expired : BOOL;
  selected_idx : INT := 0;
END_VAR

  (* Try to find vehicle that has cooled down *)
  WHILE attempts < 160 DO
    idx := RAND_INT(1, 160);
    
    (* Check cooldown *)
    IF (SimulationTime > AddMinutesToDateTime(LastUseTime[idx], DINT_TO_REAL(VEHICLE_COOLDOWN_MINUTES))) THEN
      selected_idx := idx;
      EXIT;
    END_IF;
    
    attempts := attempts + 1;
  END_WHILE;
  
  IF selected_idx > 0 THEN
    LastUseTime[selected_idx] := SimulationTime;
    SelectVehicle := VehiclePool[selected_idx];
  ELSE
    SelectVehicle := 'UNAVAILABLE';
  END_IF;

END_FUNCTION

(* ============================================================================ *)
(* DERIVE FLOW RATE *)
(* ============================================================================ *)

FUNCTION CalculateFlowRate : REAL
VAR_INPUT
  FillAmountLiters : REAL;
  ProductiveFillTimeMinutes : REAL;
END_VAR

  IF ProductiveFillTimeMinutes > 0.0 THEN
    CalculateFlowRate := FillAmountLiters / ProductiveFillTimeMinutes;
  ELSE
    CalculateFlowRate := 0.0;
  END_IF;

END_FUNCTION
