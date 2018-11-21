MODULE Snooze;   (*CP 11.2018*)
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
  BEGIN z := 1-z; LED(z);
     SYSTEM.PUT(-64,1000)
  END Snoozer;

BEGIN z := 0; T := Oberon.NewTask(Snoozer, 500)
END Snooze.
