MODULE Dates;  (*CP 7.7.2014*)

CONST SecondsPerDay = 86400; SecondsPerHour = 3600; 
           GMT* = 0;  PST* = -8;

TYPE
	DTD* = RECORD
		year*, month*, day*, weekday*, hour*, minute*, second*: LONGINT
	END;

VAR
	Months* : ARRAY 12 OF ARRAY 10 OF CHAR;	(* month's names (January = 0....December=11) *)
	Days* : ARRAY 7 OF ARRAY 10 OF CHAR;	(* day's names (Sunday = 0, .... Saturday = 6) *)
	NoDays*: ARRAY 12 OF INTEGER;

(* Date and Time functions *)

PROCEDURE StampToDTD*( utime,tz: LONGINT; VAR td : DTD);
VAR s, ts, h, m, x, b, c, d, e, f : INTEGER;
BEGIN
  s := (utime+(SecondsPerHour*tz)) MOD 86400;
  ts := (utime+(SecondsPerHour*tz)) DIV 86400;
  h := s DIV 3600;
  m := s DIV 60 MOD 60;
  s := s MOD 60;
  x := (ts*4+102032) DIV 146097+15;
  b := ts+2442113+x-(x DIV 4);
  c := (b*20-2442) DIV 7305;
  d := b-365*c-c DIV 4;
  e := d*1000 DIV 30601;
  f := d-e*30-e*601 DIV 1000;
  td.weekday := ((((utime+(SecondsPerHour*tz)) DIV SecondsPerDay )+4) MOD 7 );
  IF ( e < 14 ) THEN
    td.year := c-4716; td.month := e-1; td.day := f; td.hour := h; td.minute := m; td.second := s
  ELSE
    td.year := c-4715; td.month := e-13; td.day := f; td.hour := h; td.minute := m; td.second := s
  END
END StampToDTD;

PROCEDURE LeapYear*(year: LONGINT): BOOLEAN;    (** returns TRUE if 'year' is a leap year *)
BEGIN
	RETURN (year > 0) & (year MOD 4 = 0) & (~(year MOD 100 = 0) OR (year MOD 400 = 0))
END LeapYear;

PROCEDURE DayOfWeek*( utime, tz : LONGINT ) : LONGINT; (* returns the day of the week 0..6 of the unix time stamp *)
BEGIN
    RETURN ((((utime+(SecondsPerHour*tz)) DIV SecondsPerDay )+4) MOD 7 )
END DayOfWeek;

PROCEDURE HourOfDay*( utime, tz  : LONGINT ) : LONGINT; (* returns the hour of the day 0..23 of the unix time stamp *)
BEGIN
    RETURN (((utime+(SecondsPerHour*tz)) DIV SecondsPerHour ) MOD 24 )
END HourOfDay;

PROCEDURE MinuteOfHour*( utime : LONGINT ) : LONGINT; (* returns the minute of the hour  0..59 of the unix time stamp *)
BEGIN
    RETURN ((utime DIV 60 ) MOD 60 )
END MinuteOfHour;



PROCEDURE GetWeekDay*( day : LONGINT; VAR str : ARRAY  OF CHAR );
  VAR i : INTEGER;
BEGIN i := 0;
  WHILE i < LEN(str) DO str[i] := Days[day][i]; INC(i) END
END GetWeekDay;

PROCEDURE NofDays*(year, month: LONGINT): LONGINT;   (* returns the number of days in that month *)
   VAR n : LONGINT;
BEGIN
	DEC(month);
	ASSERT((month >= 0) & (month < 12));
    n := NoDays[month];
	IF (month = 1) & LeapYear(year) THEN n := NoDays[1]+1 END
    RETURN n
END NofDays;

PROCEDURE ValidDateTime*(dt: DTD): BOOLEAN;     (* checks if the values of a DateTime structure are valid *)
BEGIN
	RETURN ((dt.year > 0) & (dt.month > 0) & (dt.month <= 12) & (dt.day > 0) & (dt.day <= NofDays(dt.year, dt.month)) &
		(dt.weekday >= 0) & (dt.weekday < 7) & (dt.hour >= 0) & (dt.hour < 24) & (dt.minute >= 0) & (dt.minute < 60) & 
        (dt.second >= 0) & (dt.second < 60))
END ValidDateTime;

BEGIN
	Months[0] := "January"; Months[1] := "February"; Months[2] := "March"; Months[3] := "April"; Months[4] := "May";
	Months[5] := "June"; Months[6] := "July"; Months[7] := "August"; Months[8] := "September";
	Months[9] := "October"; Months[10] := "November"; Months[11] := "December";
	Days[1] := "Monday"; Days[2] := "Tuesday"; Days[3] := "Wednesday"; Days[4] := "Thursday";
	Days[5] := "Friday"; Days[6] := "Saturday"; Days[0] := "Sunday";
	NoDays[0] := 31; NoDays[1] := 28; NoDays[2] := 31; NoDays[3] := 30; NoDays[4] := 31; NoDays[5] := 30;
	NoDays[6] := 31; NoDays[7] := 31; NoDays[8] := 30; NoDays[9] := 31; NoDays[10] := 30; NoDays[11] := 31;
END Dates.