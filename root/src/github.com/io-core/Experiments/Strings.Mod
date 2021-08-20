MODULE Strings;  (* CP 2021 *)
  IMPORT SYSTEM, Streams;

  CONST

  TYPE
        Reader* = POINTER TO ReaderDesc;
        ReaderDesc* = RECORD (Streams.ReaderDesc) END;

        Writer* = POINTER TO WriterDesc;
        WriterDesc* = RECORD (Streams.WriterDesc) END;

  VAR

  (** A special writer that buffers output to be fetched by GetString or GetRawString. *)
        
  PROCEDURE & InitStringWriter*( size: LONGINT );
  BEGIN
          InitWriter( Send, size )
  END InitStringWriter;

  PROCEDURE Send( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
  BEGIN
          res := StringFull
  END Send;

  PROCEDURE CanSetPos*( ): BOOLEAN;
  BEGIN
  RETURN TRUE
  END CanSetPos;

  (* Set the position for the writer *)
  PROCEDURE SetPos*( pos: LONGINT );
  BEGIN
          IF pos > LEN( buf ) THEN pos := LEN( buf ) END;
          tail := pos;  sent := 0;  res := Ok;
  END SetPos;

  PROCEDURE Update;
  (* nothing to do *)
  END Update;

  (** Return the contents of the string writer (0X-terminated). *)
  PROCEDURE Get*( VAR s: ARRAY OF CHAR );
  VAR i, m: LONGINT;
  BEGIN
          m := LEN( s ) - 1;  i := 0;
          WHILE (i # tail) & (i < m) DO s[i] := buf[i];  INC( i ) END;
          s[i] := 0X;  tail := 0;  res := Ok
  END Get;

  (** Return the contents of the string writer (not 0X-terminated).  The len parameters returns the string length. *)
  PROCEDURE GetRaw*( VAR s: ARRAY OF CHAR;  VAR len: LONGINT );
  VAR i, m: LONGINT;
  BEGIN
          m := LEN( s );  i := 0;
          WHILE (i # tail) & (i < m) DO s[i] := buf[i];  INC( i ) END;
          len := i;  tail := 0;  res := Ok
  END GetRaw;


  (** A special reader that buffers input set by SetString or SetRawString. *)


  PROCEDURE SRCanSetPos*( VAR SR: StringReader ): BOOLEAN;
  BEGIN
  RETURN TRUE
  END SRCanSetPos;

  (** Set the reader position *)
  PROCEDURE SRSetPos*( VAR SR: StringReader; pos: INTEGER );
  BEGIN
          IF pos > StreamBufferSize THEN pos := StreamBufferSize END;
          SR.head := pos;  SR.tail := StreamBufferSize;  SR.received := StreamBufferSize;  SR.res := Ok;
  END SRSetPos;

  PROCEDURE SRReceive( VAR SR: StringReader; VAR buf: ARRAY OF CHAR;  ofs, size, min: INTEGER;  VAR len, res: INTEGER );
  BEGIN
          IF min = 0 THEN res := Ok ELSE res := EOF END;
          len := 0;
  END SRReceive;

  (** Set the contents of the string buffer.  The s parameter is a 0X-terminated string. *)
  PROCEDURE SRSet*( VAR SR: StringReader; s: ARRAY OF CHAR );
  VAR len: INTEGER;
  BEGIN
          len := 0;
          WHILE s[len] # 0X DO INC( len ) END;
          IF len > StreamBufferSize THEN len := StreamBufferSize END;
          SR.head := 0;  SR.tail := len;  SR.received := len;  SR.res := Ok;
          IF len > 0 THEN
(*                SYSTEM.MOVE( SYSTEM.ADR( s[0] ), SYSTEM.ADR( buf[0] ), len ) *)
          END;
  END SRSet;

  (** Set the contents of the string buffer.  The len parameter specifies the size of the buffer s. *)
  PROCEDURE SRSetRaw*( VAR SR: StringReader; s: ARRAY OF CHAR;  ofs, len: INTEGER );
  BEGIN
          IF len > StreamBufferSize THEN len := StreamBufferSize END;
          SR.head := 0;  SR.tail := len;  SR.received := len;  SR.res := Ok;
          ASSERT ( (len >= 0) & (ofs + len <= LEN( s )) );   (* index check *)
          IF len > 0 THEN
(*                SYSTEM.MOVE( SYSTEM.ADR( s[ofs] ), SYSTEM.ADR( buf[0] ), len )  *)
          END;
  END SRSetRaw;

  PROCEDURE InitStringReader*( VAR SR: StringReader; size: INTEGER );
  BEGIN
          InitReader( SYSTEM.VAL(Reader,SR), SRReceive, size )
  END InitStringReader;


BEGIN
END Strings;

