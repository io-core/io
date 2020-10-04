MODULE Listen;   (*CP 11.2018*)
  IMPORT SYSTEM, Oberon;
  VAR z: INTEGER;
    T: Oberon.Task;
  
  PROCEDURE Start*;
  BEGIN Oberon.Install(T)
  END Start;

  PROCEDURE Stop*;
  BEGIN Oberon.Remove(T)
  END Stop;

  PROCEDURE Listener;
  BEGIN z := 1-z; LED(z);
     SYSTEM.PUT(-64,1000)
  END Listener;

BEGIN z := 0; T := Oberon.NewTask(Snoozer, 500)
END Listen.
