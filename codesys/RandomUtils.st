(*
================================================================================
RandomUtils.st - Random Distribution Functions
================================================================================
TRIANGULAR and POISSON random sampling for simulation.
================================================================================
*)

FUNCTION TRIANGULAR : REAL
VAR_INPUT
  min_val : REAL;
  mode_val : REAL;
  max_val : REAL;
END_VAR
VAR
  u : REAL;
  F_mode : REAL;
  numerator : REAL;
  denominator : REAL;
END_VAR

  u := RAND();
  
  IF max_val <= min_val THEN
    TRIANGULAR := min_val;
    RETURN;
  END_IF;
  
  denominator := max_val - min_val;
  F_mode := (mode_val - min_val) / denominator;
  
  IF u < F_mode THEN
    numerator := u * denominator * (mode_val - min_val);
    TRIANGULAR := min_val + SQRT(numerator);
  ELSE
    numerator := (1.0 - u) * denominator * (max_val - mode_val);
    TRIANGULAR := max_val - SQRT(numerator);
  END_IF;

END_FUNCTION

FUNCTION POISSON : INT
VAR_INPUT
  lambda : INT;
END_VAR
VAR
  k : INT := 0;
  p : REAL := 1.0;
  e_neg_lambda : REAL;
  u : REAL;
  threshold : REAL;
END_VAR

  IF lambda <= 0 THEN
    POISSON := 0;
    RETURN;
  END_IF;
  
  (* e^(-lambda) approximation *)
  e_neg_lambda := EXP(DINT_TO_REAL(-lambda));
  threshold := e_neg_lambda;
  p := RAND();
  
  WHILE p > threshold DO
    k := k + 1;
    u := RAND();
    threshold := threshold * DINT_TO_REAL(lambda) / DINT_TO_REAL(k);
    p := p - threshold;
  END_WHILE;
  
  POISSON := k;

END_FUNCTION

FUNCTION RAND_INT : INT
VAR_INPUT
  min_val : INT;
  max_val : INT;
END_VAR
VAR
  range : INT;
  random_val : REAL;
END_VAR

  IF min_val >= max_val THEN
    RAND_INT := min_val;
    RETURN;
  END_IF;
  
  range := max_val - min_val + 1;
  random_val := RAND() * DINT_TO_REAL(range);
  RAND_INT := min_val + REAL_TO_INT(random_val);

END_FUNCTION
