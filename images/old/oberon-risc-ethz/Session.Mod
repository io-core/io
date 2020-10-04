MODULE Session; (*CP 7.5.2014*)

  IMPORT SYSTEM, Kernel, FileDir, Files, Modules,

    Input, Display, Viewers, Fonts, Texts, Oberon, MenuViewers, TextFrames, Clock, Dates;


  CONST

    StatusMenu = "";

  VAR W,Z: Texts.Writer;
    Status*: Texts.Text;
    T: Oberon.Task;

  PROCEDURE Clear*;
    VAR  buf: Texts.Buffer;
  BEGIN
    Texts.Delete(Status, 0, Status.len, Z.buf)
  END Clear;
 
  PROCEDURE Beep*;
  VAR time : INTEGER;
         td : Dates.DTD;
         ap : ARRAY 3 OF CHAR;
  BEGIN Clear; ap := "am";
    time := Clock.Read();
    Dates.StampToDTD(time,Dates.PST,td);
    Texts.WriteString(W, " Today: "); 
    Texts.WriteInt(W, td.day,0); 
    Texts.WriteString(W, "."); 
    Texts.WriteInt(W, td.month,0); 
    Texts.WriteString(W, "."); 
    Texts.WriteInt(W, td.year,0); 
    Texts.WriteString(W, " ( "); 
    IF (td.weekday = 0) THEN    Texts.WriteString(W, "Sunday") END;
    IF (td.weekday = 1) THEN    Texts.WriteString(W, "Monday") END;
    IF (td.weekday = 2) THEN    Texts.WriteString(W, "Tuesday") END;
    IF (td.weekday = 3) THEN    Texts.WriteString(W, "Wednesday") END;
    IF (td.weekday = 4) THEN    Texts.WriteString(W, "Thursday") END;
    IF (td.weekday = 5) THEN    Texts.WriteString(W, "Friday") END;
    IF (td.weekday = 6) THEN    Texts.WriteString(W, "Saturday") END;
    Texts.WriteString(W, " ) "); 
    IF ( td.hour < 13 ) THEN
    Texts.WriteInt(W, td.hour ,0 ); 
    ELSE
    Texts.WriteInt(W, td.hour - 12 , 0 ); 
    END;
    Texts.WriteString(W, ":"); 
    Texts.WriteInt(W, Dates.MinuteOfHour(time),0 ); 
     Texts.WriteString(W, ":"); 
    Texts.WriteInt(W, time MOD 60 ,0 ); 
   
     Texts.Append(Status, W.buf );
  END Beep;

  PROCEDURE Show*;

    VAR  statusV: Viewers.Viewer;

      menu, main: Display.Frame;

      d: LONGINT; X, Y: INTEGER;

  BEGIN
    Texts.WriteString(W, "ok"); 
    Oberon.AllocateSystemViewer(0, X, Y);

    menu := TextFrames.NewMenu("", StatusMenu);

    main := TextFrames.NewText( Status, 0);
    Texts.Append(Status, W.buf );

    statusV := MenuViewers.New(menu, main, TextFrames.menuH DIV 3, X, Y)

  END Show;



BEGIN  Texts.OpenWriter(W) ;Texts.OpenWriter(Z) ; Status := TextFrames.Text("");
    T := Oberon.NewTask(Beep, 500); Oberon.Install(T)



END Session.

