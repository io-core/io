MODULE Snooze;   (*CP 3.11.2018*)
  IMPORT SYSTEM, Oberon;
  VAR z: INTEGER;
    T: Oberon.Task;
  
  PROCEDURE Yes*;
  BEGIN Oberon.Install(T)
  END Yes;

  PROCEDURE No*;
  BEGIN Oberon.Remove(T)
  END No;

  PROCEDURE Snoozer;
  BEGIN z := 1-z; LED(z)
  END Snoozer;

BEGIN z := 0; T := Oberon.NewTask(Snoozer, 500)
END Snooze.
