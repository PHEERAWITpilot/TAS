(*
================================================================================
QueueUtils.st - Circular Queue Operations
================================================================================
FIFO queue management with wraparound logic for efficient memory usage.
================================================================================
*)

FUNCTION Enqueue : BOOL
VAR_INPUT
  Queue : ARRAY[*] OF UDINT;
  Head : INT;
  Tail : INT;
  Value : UDINT;
  MaxSize : INT;
END_VAR
VAR
  NextTail : INT;
END_VAR

  NextTail := Tail + 1;
  IF NextTail > MaxSize THEN
    NextTail := 1;
  END_IF;
  
  IF NextTail = Head THEN
    Enqueue := FALSE; (* Queue full *)
    RETURN;
  END_IF;
  
  Queue[Tail] := Value;
  Tail := NextTail;
  Enqueue := TRUE;

END_FUNCTION

FUNCTION Dequeue : BOOL
VAR_INPUT
  Queue : ARRAY[*] OF UDINT;
  Head : INT;
  Tail : INT;
  MaxSize : INT;
END_VAR
VAR_OUTPUT
  Value : UDINT;
END_VAR
VAR
  NextHead : INT;
END_VAR

  IF Head = Tail THEN
    Dequeue := FALSE; (* Queue empty *)
    Value := 0;
    RETURN;
  END_IF;
  
  Value := Queue[Head];
  NextHead := Head + 1;
  IF NextHead > MaxSize THEN
    NextHead := 1;
  END_IF;
  Head := NextHead;
  Dequeue := TRUE;

END_FUNCTION

FUNCTION QueueSize : INT
VAR_INPUT
  Head : INT;
  Tail : INT;
  MaxSize : INT;
END_VAR

  IF Tail >= Head THEN
    QueueSize := Tail - Head;
  ELSE
    QueueSize := MaxSize - Head + Tail;
  END_IF;

END_FUNCTION

FUNCTION IsQueueEmpty : BOOL
VAR_INPUT
  Head : INT;
  Tail : INT;
END_VAR

  IsQueueEmpty := (Head = Tail);

END_FUNCTION

FUNCTION IsQueueFull : BOOL
VAR_INPUT
  Head : INT;
  Tail : INT;
  MaxSize : INT;
END_VAR
VAR
  NextTail : INT;
END_VAR

  NextTail := Tail + 1;
  IF NextTail > MaxSize THEN
    NextTail := 1;
  END_IF;
  
  IsQueueFull := (NextTail = Head);

END_FUNCTION

FUNCTION QueuePeek : UDINT
VAR_INPUT
  Queue : ARRAY[*] OF UDINT;
  Head : INT;
  Tail : INT;
END_VAR

  IF Head = Tail THEN
    QueuePeek := 0;
  ELSE
    QueuePeek := Queue[Head];
  END_IF;

END_FUNCTION
