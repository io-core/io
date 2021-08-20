(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)
(* Adapted for Oberon-07 Copyright 2021 Charles Perkins *)

(* ETH Bluebottle/Aos/A2
Copyright (c) 2002-2016, Computer Systems Institute, ETH Zurich
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met: 

    * Redistributions of source code must retain the above copyright notice, 
      this list of conditions and the following disclaimer. 
    * Redistributions in binary form must reproduce the above copyright notice, 
      this list of conditions and the following disclaimer in the documentation 
      and/or other materials provided with the distribution. 
    * Neither the name of the ETH Zurich nor the names of its contributors may 
      be used to endorse or promote products derived from this software without 
      specific prior written permission. 

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.                                            *)



MODULE Streams;   (** AUTHOR "pjm/be/cp"; PURPOSE "I/O buffering and formatted writing and reading"; *)

IMPORT SYSTEM;

CONST
	Ok* = 0;   (** zero result code means no error occurred *)
	EOF* = 4201;   (** error returned when Receive reads past end of file or stream *)
	EOT* = 1AX;   (** EOT character *)
	StringFull = 4202;
	FormatError* = 4203;   (** error returned when ReadInt fails *)
        StreamBufferSize* = 4096;
	DefaultWriterSize* = StreamBufferSize;
	DefaultReaderSize* = StreamBufferSize;
	CR = 0DX;  LF = 0AX;  TAB = 9X;  SP = 20X;
	MINSETVAL = 1;
	MAXSETVAL = 32;

TYPE
	HUGEINT = RECORD low,high: INTEGER END;
	Bytes2 = ARRAY 2 OF CHAR;
	Bytes4 = ARRAY 4 OF CHAR;
	Bytes8 = ARRAY 8 OF CHAR;

        StreamBuffer = POINTER TO StreamBufferDesc;
        StreamBufferDesc = RECORD
        	data: ARRAY StreamBufferSize OF CHAR
        END;

	(** Any stream output procedure or method. *)
	Sender* = PROCEDURE ( VAR buf: StreamBuffer;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );

	(** Any stream input procedure or method. *)
	Receiver* = PROCEDURE ( VAR buf: StreamBuffer;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );

	Connection = POINTER TO ConnectionDesc;
	ConnectionDesc* = RECORD
		Send*: PROCEDURE ( VAR data: StreamBuffer;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
		Receive*: PROCEDURE ( VAR data: StreamBuffer;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
		Close*: PROCEDURE;
	END;


	(** A writer buffers output before it is sent to a Sender.  Must not be shared between processes. *)
        Writer* = POINTER TO WriterDesc;
	WriterDesc* = RECORD
		tail: LONGINT;
		buf: StreamBuffer;
		res*: LONGINT; (** result of last output operation. *)
		send: Sender;
		sent*: LONGINT;  (** count of sent bytes *)
		(* buf.data[0..tail-1] contains data to write. *)
        END;

	StringWriter* = POINTER TO StringWriterDesc;
	StringWriterDesc* = RECORD (WriterDesc) END;

	(** A reader buffers input received from a Receiver.  Must not be shared between processes. *)
	Reader* = POINTER TO ReaderDesc;
	ReaderDesc* = RECORD
		head, tail: LONGINT;
		buf: StreamBuffer;
		res*: LONGINT;   (** result of last input operation. *)
		receive: Receiver;
		received*: LONGINT;   (** count of received bytes *)
		(* buf.data[buf.head..buf.tail-1] contains data to read. *)
        END;
(*
	StringReader* = POINTER TO StringReaderDesc;
	StringReaderDesc* = RECORD (ReaderDesc) END;
*)

VAR
	H, L: INTEGER;
	months: ARRAY 12 * 4 + 1 OF CHAR;

	PROCEDURE ResetWriter*(VAR W: Writer);
	BEGIN
		W.tail := 0;  W.res := Ok;  W.sent := 0
	END ResetWriter;

	PROCEDURE InitWriter*(VAR W: Writer; send: Sender );
	BEGIN
		ASSERT ( send # NIL );
		NEW( W ); NEW( W.buf );  W.send := send;  ResetWriter(W)
	END InitWriter;


	PROCEDURE WCanSetPos*(VAR W: Writer ): BOOLEAN;
	BEGIN
		RETURN FALSE
	END WCanSetPos;

	PROCEDURE WSetPos*(VAR W: Writer; pos: LONGINT );
	BEGIN
(*		HALT( W, 1234 )  *)
	END WSetPos;

	PROCEDURE Update*(VAR W: Writer);
	BEGIN
		IF (W.res = Ok) THEN
			W.send( W.buf, 0, W.tail, TRUE , W.res );
			IF W.res = Ok THEN INC( W.sent, W.tail );  W.tail := 0 END
		END
	END Update;

	(** Current write position. *)
	PROCEDURE WPos*(W: Writer): LONGINT;
	BEGIN
	RETURN W.sent + W.tail
	END WPos;

	(** -- Write raw binary data -- *)

	(** Write one byte. *)
	PROCEDURE WChar*( VAR W: Writer; x: CHAR );
	BEGIN
		IF (W.tail = StreamBufferSize) & (W.res = Ok) THEN
			W.send( W.buf, 0, W.tail, FALSE , W.res );
			IF W.res = Ok THEN INC( W.sent, W.tail );  W.tail := 0 END
		END;
		IF W.res = Ok THEN W.buf.data[W.tail] := x;  INC( W.tail ) END
	END WChar;

	(** Write len bytes from x, starting at ofs. *)
	PROCEDURE WBytes*(VAR W: Writer; x: ARRAY OF CHAR;  ofs, len: LONGINT );
	VAR n: LONGINT; done: BOOLEAN;
	BEGIN
		ASSERT ( len >= 0 ); done:=FALSE;
		WHILE ~done DO
			n := StreamBufferSize - W.tail;   (* space available *)
			IF n = 0 THEN
				IF W.res = Ok THEN  (* send current buffer *)
					W.send( W.buf, 0, W.tail, FALSE , W.res );
					IF W.res = Ok THEN 
						INC( W.sent, W.tail );  W.tail := 0 ;
						n := StreamBufferSize
					ELSE 
						done := TRUE
					END
				ELSE
					done := TRUE  (* should not be writing on an erroneous rider *)
				END;
			ELSE
				IF n > len THEN n := len END;
				ASSERT ( W.tail + n <= StreamBufferSize );   (* index check *)
				(* SYSTEM.MOVE( SYSTEM.ADR( x[ofs] ), SYSTEM.ADR( W.buf[W.tail] ), n );  *)  INC( W.tail, n );
				IF len = n THEN done := TRUE
				ELSE INC( ofs, n );  DEC( len, n )
				END
			END
		END
	END WBytes;

	(** Write an INT8. *)
	PROCEDURE WRawInt8*( VAR W: Writer; x: INTEGER );
	BEGIN
		WChar( W, SYSTEM.VAL( CHAR, x ) )
	END WRawInt8;

	(** Write an INT16. *)
	PROCEDURE WRawInt16*( VAR W: Writer; x: INTEGER );
	BEGIN
		WBytes( W, SYSTEM.VAL( Bytes2, x ), 0, 2 )
	END WRawInt16;

	(** Write an INT32. *)
	PROCEDURE WRawInt32*( VAR W: Writer; x: INTEGER );
	BEGIN
		WBytes( W, SYSTEM.VAL( Bytes4, x ), 0, 4 )
	END WRawInt32;

	(** Write a HUGEINT. *)
	PROCEDURE WRawInt64*( VAR W: Writer; x: HUGEINT );
	BEGIN
		WBytes( W, SYSTEM.VAL( Bytes8, x ), 0, 8 )
	END WRawInt64;

	(** Write a 32 bit value in network byte order (most significant byte first) *)
	PROCEDURE WNet32*( VAR W: Writer; x: INTEGER );
	BEGIN
		WChar( W, CHR( x DIV 1000000H MOD 100H ) );  
		WChar( W, CHR( x DIV 10000H MOD 100H ) );
                WChar( W, CHR( x DIV 100H MOD 100H ) );
		WChar( W, CHR( x MOD 100H ) )
	END WNet32;

	(** Write a 64 bit value in network byte order (most significant byte first) *)
	PROCEDURE WNet64*( VAR W: Writer; x: HUGEINT );
	BEGIN
		WNet32( W, x.high);
		WNet32( W, x.low);
	END WNet64;

	(** Write a 16 bit value in network byte order (most significant byte first) *)
	PROCEDURE WNet16*( VAR W: Writer; x: INTEGER );
	BEGIN
		WChar( W, CHR( x DIV 100H MOD 100H ) );  WChar( W, CHR( x MOD 100H ) )
	END WNet16;

	(** write unsigned byte *)
	PROCEDURE WNet8*( VAR W: Writer; x: INTEGER );
	BEGIN
		WChar( W, CHR( x MOD 100H ) )
	END WNet8;

	(** Write a SET. *)
	PROCEDURE WRawSet*( VAR W: Writer; x: SET );
	BEGIN
		WBytes( W, SYSTEM.VAL( Bytes4, x ), 0, 4 )
	END WRawSet;

	(** Write a BOOLEAN. *)
	PROCEDURE WRawBool*( VAR W: Writer; x: BOOLEAN );
	BEGIN
		IF x THEN WChar( W, 1X ) ELSE WChar( W, 0X ) END
	END WRawBool;

	(** Write a REAL. *)
	PROCEDURE WRawReal*( VAR W: Writer; x: REAL );
	BEGIN
		WBytes( W, SYSTEM.VAL( Bytes4, x ), 0, 4 )
	END WRawReal;
(*
	(** Write a LONGREAL. *)
	PROCEDURE WRawLReal*( VAR W: Writer; x: LONGREAL );
	BEGIN
		Bytes( SYSTEM.VAL( Bytes8, x ), 0, 8 )
	END WRawLReal;
*)
	(** Write a 0X-terminated string, including the 0X terminator. *)
	PROCEDURE WRawString*(VAR W: Writer; x: ARRAY OF CHAR );
	VAR i: INTEGER;
	BEGIN
		i := 0;
		WHILE x[i] # 0X DO WChar( W, x[i] );  INC( i ) END;
		WChar( W, 0X )
	END WRawString;

	(** Write a number in a compressed format. *)
	PROCEDURE WRawNum*( VAR W: Writer; x: INTEGER );
	BEGIN
		WHILE (x < -64) OR (x > 63) DO WChar( W, CHR( x MOD 128 + 128 ) );  x := x DIV 128 END;
		WChar( W, CHR( x MOD 128 ) )
	END WRawNum;

	(** -- Write formatted data -- *)

	(** Write an ASCII end-of-line (CR/LF). *)
	PROCEDURE WLn*(W: Writer);
	BEGIN
		WChar( W, CR );  WChar( W, LF )
	END WLn;

	(** Write a 0X-terminated string, excluding the 0X terminator. *)
	PROCEDURE WString*(VAR W: Writer;  x: ARRAY OF CHAR );
	VAR i: INTEGER;
	BEGIN
		i := 0;
		WHILE x[i] # 0X DO WChar( W, x[i] );  INC( i ) END
	END WString;

	(** Write an integer in decimal right-justified in a field of at least w characters. *)
	PROCEDURE WIntJ*( VAR W: Writer; x: INTEGER; w: INTEGER );
	VAR i: INTEGER; x0: INTEGER;
		a: ARRAY 21 OF CHAR;
		done: BOOLEAN;
	BEGIN   done:= FALSE;
		IF x < 0 THEN
			IF x = SYSTEM.VAL( INTEGER, 80000000H) THEN (*minimum 32-bit integer *)
				DEC( w, 11 );
				WHILE w > 0 DO WChar( W, " " );  DEC( w ) END;
				WString( W, "-2147483648" );  done:=TRUE
			ELSE DEC( w );  x0 := -x
			END
		ELSE x0 := x
		END;
		IF ~done THEN
			i := 0;
			REPEAT a[i] := CHR( x0 MOD 10 + 30H );  x0 := x0 DIV 10;  INC( i ) UNTIL x0 = 0;
			WHILE w > i DO WChar( W, " " );  DEC( w ) END;
			IF x < 0 THEN WChar( W, "-" ) END;
			REPEAT DEC( i );  WChar( W, a[i] ) UNTIL i = 0
		END
	END WIntJ;

	(** Write a SET in Oberon notation. *)
	PROCEDURE WSet*( VAR W: Writer; s: SET );   (* from P. Saladin *)
	VAR i, last: LONGINT;  dots: BOOLEAN;
	BEGIN
		WChar( W, "{" );  last := SYSTEM.VAL( INTEGER, 80000000H );  dots := FALSE;
		FOR i := MINSETVAL TO MAXSETVAL DO
			IF i IN s THEN
				IF last = (i - 1) THEN
					IF dots THEN WString( W, ".." );  dots := FALSE END;
					IF (i = MAXSETVAL) OR ~((i + 1) IN s) THEN WIntJ( W, i, 1 ) END
				ELSE
					IF last >= MINSETVAL THEN WString( W, ", " ) END;
					WIntJ( W, i, 1 );  dots := TRUE
				END;
				last := i
			END
		END;
		WChar( W, "}" )
	END WSet;

	(**
		Write an integer in hexadecimal right-justified in a field of at least ABS(w) characters.
		If w < 0 THEN w least significant hex digits of x are written (potentially including leading zeros)
	*)
	PROCEDURE WHex*(VAR W: Writer; x: INTEGER; w: INTEGER);
	VAR filler: CHAR; i,maxw: LONGINT; a: ARRAY 20 OF CHAR; y: INTEGER;
	BEGIN
		IF w < 0 THEN filler := "0"; w := -w; maxw := w ELSE filler := " "; maxw := 16 END;
		i := 0;
		REPEAT
			y := x MOD 10H;
			IF y < 10 THEN a[i] := CHR(y+ORD("0")) ELSE a[i] := CHR(y-10+ORD("A")) END;
			x := x DIV 10H;
			INC(i);
		UNTIL (x=0) OR (i=maxw);
		WHILE w > i DO WChar( W, filler );  DEC( w ) END;
		REPEAT DEC( i ); WChar( W, a[i] ) UNTIL i = 0
	END WHex;

	(** Write "x" as a hexadecimal address. Do not use Hex because of arithmetic shift of the sign !*)
	PROCEDURE WAddress* (VAR W: Writer; x: INTEGER);
	BEGIN
		WHex(W, x,-8);
	END WAddress;

	PROCEDURE WPair( VAR W: Writer; ch: CHAR;  x: LONGINT );
	BEGIN
		IF ch # 0X THEN WChar( W, ch ) END;
		WChar( W, CHR( ORD( "0" ) + x DIV 10 MOD 10 ) );  WChar( W, CHR( ORD( "0" ) + x MOD 10 ) )
	END WPair;

	(** Write the date and time in ISO format (yyyy-mm-dd hh:mm:ss).  The t and d parameters are in Oberon time and date format.
		If all parameters are within range, the output string is exactly 19 characters wide.  The t or d parameter can be -1, in which
		case the time or date respectively are left out. *)
	PROCEDURE WDate*( VAR W: Writer; t, d: LONGINT );
	VAR ch: CHAR;
	BEGIN
		IF d # -1 THEN
			WIntJ( W, 1900 + d DIV 512, 4 );   (* year *)
			WPair( W, "-", d DIV 32 MOD 16 );   (* month *)
			WPair( W, "-", d MOD 32 );   (* day *)
			ch := " " (* space between date and time *)
		ELSE
			ch := 0X (* no space before time *)
		END;
		IF t # -1 THEN
			WPair( W, ch, t DIV 4096 MOD 32 );   (* hour *)
			WPair( W, ":", t DIV 64 MOD 64 );   (* min *)
			WPair( W, ":", t MOD 64 ) (* sec *)
		END
	END WDate;

	(** Write the date and time in RFC 822/1123 format without the optional day of the week (dd mmm yyyy hh:mm:ss SZZZZ) .
		The t and d parameters are in Oberon time and date format.  The tz parameter specifies the time zone offset in minutes
		(from -720 to 720 in steps of 30).  If all parameters are within range, the output string is exactly 26 characters wide.
		The t, d or tz parameter can be -1, in which case the time, date or timezone respectively are left out. *)
	PROCEDURE WDate822*( VAR W: Writer; t, d, tz: LONGINT );
	VAR i, m: LONGINT;  ch: CHAR;
	BEGIN
		IF d # -1 THEN
			WIntJ( W, d MOD 32, 2 );   (* day *)
			m := (d DIV 32 MOD 16 - 1) * 4;   (* month *)
			FOR i := m TO m + 3 DO WChar( W, months[i] ) END;
			WIntJ( W, 1900 + d DIV 512, 5 );   (* year *)
			ch := " " (* space *)
		ELSE
			ch := 0X (* no space *)
		END;
		IF t # -1 THEN
			WPair( W, ch, t DIV 4096 MOD 32 );   (* hour *)
			WPair( W, ":", t DIV 64 MOD 64 );   (* min *)
			WPair( W, ":", t MOD 64 );   (* sec *)
			ch := " " (* space *)
		ELSE
			(* leave ch as before *)
		END;
		IF tz # -1 THEN
			IF ch # 0X THEN WChar( W, ch ) END;
			IF tz >= 0 THEN WPair( W, "+", tz DIV 60 ) ELSE WPair( W, "-", (-tz) DIV 60 ) END;
			WPair( W, 0X, ABS( tz ) MOD 60 )
		END
	END WDate822;

(*
	(** Write LONGREAL x  using n character positions. *)
	PROCEDURE WFloat*( VAR W: Writer; x: LONGREAL;  n: LONGINT );
	(* BM 1993.4.22. Do not simplify rounding! *)
	VAR e, h, l, i: LONGINT;  z: LONGREAL;
		d: ARRAY 16 OF CHAR;
	BEGIN
		e := ExpoL( x );
		IF e = 2047 THEN
			WHILE n > 9 DO WChar( " " );  DEC( n ) END;
			NaNCodeL( x, h, l );
			IF (h # 0) OR (l # 0) THEN String( "      NaN" )
			ELSIF x < 0 THEN String( "     -INF" )
			ELSE String( "      INF" )
			END
		ELSE
			IF n <= 9 THEN n := 1 ELSE DEC( n, 8 ) END;
			REPEAT WChar( " " );  DEC( n ) UNTIL n <= 15;   (* 0 <= n <= 15 fraction digits *)
			IF (e # 0) & (x < 0) THEN WChar( "-" );  x := -x ELSE WChar( " " ) END;
			IF e = 0 THEN
				h := 0;  l := 0 (* no denormals *)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
				z := Ten( e + 1 );
				IF x >= z THEN x := x / z;  INC( e ) ELSE x := x * Ten( -e ) END;
				IF x >= 10 THEN x := x * Ten( -1 ) + 0.5D0 / Ten( n );  INC( e )
				ELSE
					x := x + 0.5D0 / Ten( n );
					IF x >= 10 THEN x := x * Ten( -1 );  INC( e ) END
				END;
				x := x * Ten( 7 );  h := ENTIER( x );  x := (x - h) * Ten( 8 );  l := ENTIER( x )
			END;
			i := 15;
			WHILE i > 7 DO d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i ) END;
			WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
			WChar( d[0] );  WChar( "." );  i := 1;
			WHILE i <= n DO WChar( d[i] );  INC( i ) END;
			IF e < 0 THEN String( "E-" );  e := -e ELSE String( "E+" ) END;
			WChar( CHR( e DIV 100 + ORD( "0" ) ) );  e := e MOD 100;  WChar( CHR( e DIV 10 + ORD( "0" ) ) );  WChar( CHR( e MOD 10 + ORD( "0" ) ) )
		END
	END WFloat;

	(** Write LONGREAL x in a fixed point notation. n is the overall minimal length for the output field, f the number of fraction digits following the decimal point, D the fixed exponent (printed only when D # 0). *)
	PROCEDURE WFloatFix*( VAR W: Writer; x: LONGREAL;  n, f, D: LONGINT );
	(* BM 1993.4.22. Do not simplify rounding! / JG formatting adjusted *)
	VAR e, h, l, i: LONGINT;  r, z: LONGREAL;
		d: ARRAY 16 OF CHAR;
		s: CHAR;  dot: BOOLEAN;
	BEGIN
		e := ExpoL( x );
		IF (e = 2047) OR (ABS( D ) > 308) THEN
			WHILE n > 9 DO WChar( " " );  DEC( n ) END;
			NaNCodeL( x, h, l );
			IF (h # 0) OR (l # 0) THEN String( "      NaN" )
			ELSIF x < 0 THEN String( "     -INF" )
			ELSE String( "      INF" )
			END
		ELSE
			IF D = 0 THEN IF (f=0) THEN dot := FALSE; DEC( n, 1 ) ELSE dot := TRUE; DEC(n,2);  END;  ELSE dot := TRUE; DEC( n, 7 ) END;
			IF n < 2 THEN n := 2 END;
			IF f < 0 THEN f := 0 END;
			IF n < f + 2 THEN n := f + 2 END;
			DEC( n, f );
			IF (e # 0) & (x < 0) THEN s := "-";  x := -x ELSE s := " " END;
			IF e = 0 THEN
				h := 0;  l := 0;  DEC( e, D - 1 ) (* no denormals *)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
				z := Ten( e + 1 );
				IF x >= z THEN x := x / z;  INC( e ) ELSE x := x * Ten( -e ) END;
				DEC( e, D - 1 );  i := -(e + f);
				IF i <= 0 THEN r := 5 * Ten( i ) ELSE r := 0 END;
				IF x >= 10 THEN x := x * Ten( -1 ) + r;  INC( e )
				ELSE
					x := x + r;
					IF x >= 10 THEN x := x * Ten( -1 );  INC( e ) END
				END;
				x := x * Ten( 7 );  h := ENTIER( x );  x := (x - h) * Ten( 8 );  l := ENTIER( x )
			END;
			i := 15;
			WHILE i > 7 DO d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i ) END;
			WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
			IF n <= e THEN n := e + 1 END;
			IF e > 0 THEN
				WHILE n > e DO WChar( " " );  DEC( n ) END;
				WChar( s );  e := 0;
				WHILE n > 0 DO
					DEC( n );
					IF e < 16 THEN WChar( d[e] );  INC( e ) ELSE WChar( "0" ) END
				END;
				IF dot THEN
				WChar( "." )
				END;
			ELSE
				WHILE n > 1 DO WChar( " " );  DEC( n ) END;
				WChar( s );  WChar( "0" );  IF dot THEN WChar( "." );  END;
				WHILE (0 < f) & (e < 0) DO WChar( "0" );  DEC( f );  INC( e ) END
			END;
			WHILE f > 0 DO
				DEC( f );
				IF e < 16 THEN WChar( d[e] );  INC( e ) ELSE WChar( "0" ) END
			END;
			IF D # 0 THEN
				IF D < 0 THEN String( "E-" );  D := -D ELSE String( "E+" ) END;
				WChar( CHR( D DIV 100 + ORD( "0" ) ) );  D := D MOD 100;  WChar( CHR( D DIV 10 + ORD( "0" ) ) );  WChar( CHR( D MOD 10 + ORD( "0" ) ) )
			END
		END
	END WFloatFix;

*)

(*
	(** A special writer that buffers output to be fetched by GetString or GetRawString. *)
	StringWriter* = OBJECT (Writer)

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
			RETURN TRUE;
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

	END StringWriter;
*)


	(** reset the reader by dropping the bytes in the buffer, resetting the result code and setting received to 0.
		This is used by seekable extensions of the reader *)
	PROCEDURE ResetReader*(VAR R: Reader);
	BEGIN
		R.head := 0;  R.tail := 0;  R.res := Ok;  R.received := 0
	END ResetReader;

	PROCEDURE InitReader*(VAR R: Reader; receive: Receiver );
	BEGIN
		ASSERT ( receive # NIL );
                NEW( R ); NEW( R.buf ); R.receive := receive;  ResetReader(R)
	END InitReader;



	PROCEDURE RCanSetPos*(VAR R: Reader): BOOLEAN;
	BEGIN
		RETURN FALSE
	END RCanSetPos;

	PROCEDURE RSetPos*( VAR R: Reader; pos: LONGINT );
	BEGIN
(*		HALT( 1234 ) *)
	END RSetPos;

	(** Return bytes currently available in input buffer. *)
	PROCEDURE RAvailable*( VAR R: Reader): LONGINT;
	VAR n: LONGINT;
	BEGIN
		IF (R.res = Ok) THEN
			IF (R.head = R.tail) THEN R.head := 0;  R.receive( R.buf, 0, StreamBufferSize, 0, R.tail, R.res );  INC( R.received, R.tail );
			ELSIF (R.tail # StreamBufferSize) THEN
				R.receive( R.buf, R.tail, StreamBufferSize - R.tail, 0, n, R.res );   (* poll *)
				INC( R.tail, n );  INC( R.received, n )
			END;
			IF R.res = EOF THEN R.res := Ok END  (* ignore EOF here *)
		END;
		RETURN R.tail - R.head
	END RAvailable;

	(** Current read position. *)
	PROCEDURE RPos*( VAR R: Reader ): LONGINT;
	BEGIN
		RETURN R.received - (R.tail - R.head)
	END RPos;

	(** -- Read raw binary data -- *)

	(** Read one byte. x=0X if no success (e.g. file ended) *)
	PROCEDURE RChar*( VAR R: Reader; VAR x: CHAR );
	BEGIN
		IF (R.head = R.tail) & (R.res = Ok) THEN R.head := 0;  R.receive( R.buf, 0, StreamBufferSize, 1, R.tail, R.res );  INC( R.received, R.tail ) END;
		IF R.res = Ok THEN x := R.buf.data[R.head];  INC( R.head ) ELSE x := 0X END
	END RChar;

	(** Like Read, but return result. Return 0X if no success (e.g. file ended) *)
	PROCEDURE Get*( VAR R: Reader): CHAR;
	  VAR rv: CHAR;
	BEGIN
		IF (R.head = R.tail) & (R.res = Ok) THEN R.head := 0;  R.receive( R.buf, 0, StreamBufferSize, 1, R.tail, R.res );  INC( R.received, R.tail ) END;
		IF R.res = Ok THEN INC( R.head );  rv := R.buf.data[R.head - 1] ELSE rv := 0X END
	RETURN rv
	END Get;

	(** Like Get, but leave the byte in the input buffer. *)
	PROCEDURE Peek*( VAR R: Reader): CHAR;
	  VAR rv: CHAR;
	BEGIN
		IF (R.head = R.tail) & (R.res = Ok) THEN
			R.head := 0;  R.receive( R.buf, 0, StreamBufferSize, 1, R.tail, R.res );  INC( R.received, R.tail );
			IF R.res = EOF THEN  (* ignore EOF here *)
				R.res := Ok;  R.tail := 0; rv:= 0X (* Peek returns 0X at eof *)
			ELSE
				IF R.res = Ok THEN rv:= R.buf.data[R.head] ELSE rv:= 0X END
			END
		ELSE
			IF R.res = Ok THEN rv:= R.buf.data[R.head] ELSE rv:= 0X END
		END;
	RETURN rv
	END Peek;

	(** Read size bytes into x, starting at ofs.  The len parameter returns the number of bytes that were actually read. *)
	PROCEDURE RBytes*( VAR R: Reader; VAR x: ARRAY OF CHAR;  ofs, size: LONGINT;  VAR len: LONGINT );
	VAR n: LONGINT; done: BOOLEAN;
	BEGIN
		ASSERT ( size >= 0 );
		len := 0; done := FALSE;
		WHILE ~done DO
			n := R.tail - R.head;   (* bytes available *)
			IF n = 0 THEN  (* no data available *)
				R.head := 0;
				IF R.res = Ok THEN  (* fill buffer *)
					R.receive( R.buf, 0, StreamBufferSize, 1, R.tail, R.res );  INC( R.received, R.tail )
				END;
				IF R.res # Ok THEN  (* should not be reading from erroneous rider *)
					WHILE size # 0 DO x[ofs] := 0X;  INC( ofs );  DEC( size ) END;   (* clear rest of buffer *)
					IF (R.res = EOF) & (len # 0) THEN R.res := Ok END;   (* ignore EOF if some data being returned *)
					done := TRUE
				ELSE
					n := R.tail
				END
			END;
			IF ~done THEN
				IF n > size THEN n := size END;
				ASSERT ( ofs + n <= LEN( x ) );   (* index check *)
(*				SYSTEM.MOVE( SYSTEM.ADR( R.buf.data[head] ), SYSTEM.ADR( x[ofs] ), n );  *)  INC( R.head, n );  INC( len, n );
				IF size = n THEN 
					done := TRUE   
				ELSE
					INC( ofs, n );  DEC( size, n )
				END
			END
		END
	END RBytes;

	(** Skip n bytes on the reader. *)
	PROCEDURE RSkipBytes*( VAR R: Reader; n: LONGINT );
	VAR ch: CHAR;
	BEGIN
		WHILE n > 0 DO ch := Get(R);  DEC( n ) END
	END RSkipBytes;

	(** Read a SHORTINT. *)
	PROCEDURE RRawInt8*( VAR R: Reader; VAR x: BYTE );
	BEGIN
		x := SYSTEM.VAL( BYTE, Get(R) )
	END RRawInt8;

	(** Read an INTEGER. *)
	PROCEDURE RRawInt16*( VAR R: Reader; VAR x: INTEGER );
	VAR x0, x1: CHAR;
	BEGIN
		x0 := Get(R);  x1 := Get(R);   (* defined order *)
		x := ORD( x1 ) * 100H + ORD( x0 )
	END RRawInt16;

	(** Read a LONGINT. *)
	PROCEDURE RRawInt32*( VAR R: Reader; VAR x: INTEGER );
	VAR ignore: INTEGER;
	BEGIN
		RBytes( R, SYSTEM.VAL( Bytes4, x ), 0, 4, ignore )
	END RRawInt32;

	(** Read a HUGEINT. *)
	PROCEDURE RRawInt64*( VAR R: Reader; VAR x: HUGEINT );
	VAR ignore: LONGINT;
	BEGIN
		RBytes( R, SYSTEM.VAL( Bytes8, x ), 0, 8, ignore )
	END RRawInt64;

	(** Read a 32 bit value in network byte order (most significant byte first) *)
	PROCEDURE RNet32*( VAR R: Reader): INTEGER;
	BEGIN
		RETURN ORD( Get(R) )  * 1000000H + ORD( Get(R) )  * 10000H + ORD( Get(R) )  * 100H + ORD( Get(R)  )
	END RNet32;

	(** Read a 64 bit value in network byte order (most significant byte first) *)
	PROCEDURE RNet64*(VAR R: Reader; VAR h: HUGEINT);
	BEGIN
		h.high := RNet32(R); h.low := RNet32(R)
	END RNet64;

	(** Read an unsigned 16bit value in network byte order (most significant byte first) *)
	PROCEDURE RNet16*( VAR R: Reader): INTEGER;
	BEGIN
		RETURN ORD( Get(R) )  * 100H + ORD( Get(R) ) 
	END RNet16;

	(** Read an unsigned byte *)
	PROCEDURE RNet8*( VAR R: Reader): INTEGER;
	BEGIN
		RETURN ORD( Get(R) ) 
	END RNet8;

	(** Read a SET. *)
	PROCEDURE RRawSet*( VAR R: Reader; VAR x: SET );
	VAR ignore: INTEGER;
	BEGIN
		RBytes( R, SYSTEM.VAL( Bytes4, x ), 0, 4, ignore )
	END RRawSet;

	(** Read a BOOLEAN. *)
	PROCEDURE RRawBool*( VAR R: Reader; VAR x: BOOLEAN );
	BEGIN
		x := (Get(R) # 0X)
	END RRawBool;

	(** Read a REAL. *)
	PROCEDURE RRawReal*( VAR R: Reader; VAR x: REAL );
	VAR ignore: INTEGER;
	BEGIN
		RBytes( R, SYSTEM.VAL( Bytes4, x ), 0, 4, ignore )
	END RRawReal;
(*
	(** Read a LONGREAL. *)
	PROCEDURE RRawLReal*( VAR R: Reader; VAR x: LONGREAL );
	VAR ignore: LONGINT;
	BEGIN
		Bytes( SYSTEM.VAL( Bytes8, x ), 0, 8, ignore )
	END RRawLReal;
*)
	(** Read a 0X-terminated string.  If the input string is larger than x, read the full string and assign the truncated 0X-terminated value to x. *)
	PROCEDURE RRawString*( VAR R: Reader; VAR x: ARRAY OF CHAR );
	VAR i, m: LONGINT;  ch: CHAR; done: BOOLEAN;
	BEGIN
		i := 0;  m := LEN( x ) - 1; done := FALSE;
		WHILE ~done DO
			ch := Get(R);   (* also returns 0X on error *)
			IF ch = 0X THEN done := TRUE
			ELSE
				IF i < m THEN x[i] := ch;  INC( i ) END
			END
		END;
		x[i] := 0X
	END RRawString;
(*
	(** Read a number in a compressed format. *)
	PROCEDURE RRawNum*( VAR R: Reader; VAR x: INTEGER );
	VAR ch: CHAR;  n, y: INTEGER;
	BEGIN
		n := 0;  y := 0;  ch := Get(R);
		WHILE ch >= 80X DO INC( y, LSH( ORD( ch )  - 128, n ) );  INC( n, 7 );  ch := Get(R) END;
		x := ASH( LSH( ORD( ch ) , 25 ), n - 25 ) + y
	END RRawNum;
*)
	(** -- Read formatted data (uses Peek for one character lookahead) -- *)

	 (** Read an integer value in decimal or hexadecimal.  If hex = TRUE, recognize the "H" postfix for hexadecimal numbers. *)

        (** Capitalize a character. *)
        PROCEDURE CAP( ch: CHAR): CHAR;
        VAR rv: CHAR;
        BEGIN
                IF (ch >= "a") & (ch <="z") THEN rv := CHR( ORD(ch) - (ORD("z") - ORD("Z")))
		ELSE rv := ch END 
        RETURN rv
        END CAP;

	PROCEDURE RInt*( VAR R: Reader; VAR x: INTEGER;  hex: BOOLEAN );
	VAR vd, vh, sgn, d: INTEGER;  ch: CHAR;  ok, done: BOOLEAN;
	BEGIN   done := FALSE;
		vd := 0;  vh := 0;  sgn := 1;  ok := FALSE;
		IF Peek(R) = "-" THEN sgn := -1;  ch := Get(R) END;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch >= "0") & (ch <= "9") THEN d := ORD( ch ) - ORD( "0" )
			ELSIF hex & (CAP( ch ) >= "A") & (CAP( ch ) <= "F") THEN d := ORD( CAP( ch ) ) - ORD( "A" ) + 10
			ELSE done := TRUE
			END;
			IF ~done THEN
				vd := 10 * vd + d;  vh := 16 * vh + d;   (* ignore overflow *)
				ch := Get(R);  ok := TRUE
			END
		END;
		IF hex & (CAP( ch ) = "H") THEN  (* optional "H" present *)
			vd := vh;   (* use the hex value *)
			ch := Get(R)
		END;
		x := sgn * vd;
		IF (R.res = 0) & ~ok THEN R.res := FormatError END
	END RInt;

	(** Return TRUE iff at the end of a line (or file). *)
	PROCEDURE REOLN*( VAR R: Reader): BOOLEAN;
	VAR ch: CHAR;
	BEGIN
		ch := Peek(R);  
	RETURN (ch = CR) OR (ch = LF) OR (R.res # Ok)
	END REOLN;

	(** Read all characters until the end of the line (inclusive).  If the input string is larger than x, read the full string and assign
		the truncated 0X-terminated value to x. *)
	PROCEDURE RLn*( VAR R: Reader; VAR x: ARRAY OF CHAR );
	VAR i, m: LONGINT;  ch: CHAR; done: BOOLEAN;
	BEGIN
		i := 0;  m := LEN( x ) - 1; done := FALSE;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch = CR) OR (ch = LF) OR (R.res # Ok) THEN done := TRUE
			ELSE
				IF i < m THEN x[i] := ch;  INC( i ) END;
				ch := Get(R)
			END
		END;
		x[i] := 0X;
		IF ch = CR THEN ch := Get(R) END;
		IF Peek(R) = LF THEN ch := Get(R) END
	END RLn;

	(** Read all characters until the end of the line (inclusive) or an <EOT> character.
		If the input string is larger than x, read the full string and assign the truncated 0X-terminated
		value to x. *)
	PROCEDURE RLnEOT*( VAR R: Reader; VAR x: ARRAY OF CHAR );
	VAR i, m: LONGINT;  ch: CHAR; done: BOOLEAN;
	BEGIN
		i := 0;  m := LEN( x ) - 1; done:= FALSE;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch = CR) OR (ch = LF) OR (ch = EOT) OR (R.res # Ok) THEN done := TRUE
			ELSE
				IF i < m THEN x[i] := ch;  INC( i ) END;
				ch := Get(R)
			END
		END;
		x[i] := 0X;
		IF ch = CR THEN ch := Get(R) END;
		IF Peek(R) = LF THEN ch := Get(R) END;
		IF ch = EOT THEN ch := Get(R) END
	END RLnEOT;

	(** Skip over all characters until the end of the line (inclusive). *)
	PROCEDURE SkipLn*(VAR R: Reader);
	VAR ch: CHAR; done: BOOLEAN;
	BEGIN   done:=FALSE;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch = CR) OR (ch = LF) OR (R.res # Ok) THEN done:=TRUE
			ELSE
				ch := Get(R)
			END
		END;
		IF ch = CR THEN ch := Get(R) END;
		IF Peek(R) = LF THEN ch := Get(R) END
	END SkipLn;

	(** Skip over space and TAB characters. *)
	PROCEDURE SkipSpaces*(VAR R: Reader);
	VAR ch: CHAR; done: BOOLEAN;
	BEGIN   done:=FALSE;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch # TAB) & (ch # SP) THEN done:=TRUE
			ELSE
				ch := Get(R)
			END
		END
	END SkipSpaces;

	(** Skip over space, TAB and EOLN characters. *)
	PROCEDURE SkipWhitespace*(VAR R: Reader);
	VAR ch: CHAR; done: BOOLEAN;
	BEGIN   done:=FALSE;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch # SP) & (ch # CR) & (ch # LF) & (ch # TAB) THEN done:=TRUE
			ELSE
				ch := Get(R)
			END
		END
	END SkipWhitespace;

	(** Read a token, consisting of any string of characters terminated by space, TAB or EOLN. *)
	PROCEDURE Token*( VAR R: Reader; VAR token: ARRAY OF CHAR );
	VAR j, max: LONGINT;  ch: CHAR; done: BOOLEAN;
	BEGIN   done:=FALSE;
		j := 0;  max := LEN( token ) - 1;
		WHILE ~done DO
			ch := Peek(R);
			IF (ch = SP) OR (ch = CR) OR (ch = LF) OR (ch = TAB) OR (R.res # Ok) THEN done:=TRUE
			ELSE
				IF j < max THEN token[j] := ch;  INC( j ) END;
				ch := Get(R)
			END
		END;
		token[j] := 0X
	END Token;

	(** Read an optionally "" or '' enquoted string.  Will not read past the end of a line. *)
	PROCEDURE RString*( VAR R: Reader; VAR string: ARRAY OF CHAR );
	VAR c, delimiter: CHAR;  i, len: LONGINT;
	BEGIN
		c := Peek(R);
		IF (c # "'") & (c # 22X) THEN Token( R, string )
		ELSE
			delimiter := Get(R);  c := Peek(R);  i := 0;  len := LEN( string ) - 1;
			WHILE (i < len) & (c # delimiter) & (c # CR) & (c # LF) & (R.res = Ok) DO string[i] := Get(R);  INC( i );  c := Peek(R) END;
			IF (c = delimiter) THEN c := Get(R) END;
			string[i] := 0X
		END
	END RString;

	(** First skip whitespace, then read string *)
	PROCEDURE GetString*(VAR R: Reader; VAR string : ARRAY OF CHAR): BOOLEAN;
	VAR c: CHAR;
	BEGIN
		SkipWhitespace(R);
		c := Peek(R);
		RString(R,string);
		RETURN (string[0] # 0X) OR (c = "'") OR (c = 22X)
	END GetString;

	(** First skip whitespace, then read integer *)
	PROCEDURE GetInteger*(VAR R: Reader; VAR integer : LONGINT; isHexadecimal : BOOLEAN): BOOLEAN;
	BEGIN
		SkipWhitespace(R);
		RInt(R,integer, isHexadecimal);
	RETURN R.res = Ok
	END GetInteger;

	(** First skip whitespace, then read 1 byte character *)
	PROCEDURE GetChar*(VAR R: Reader; VAR ch : CHAR): BOOLEAN;
	BEGIN
		SkipWhitespace(R);
		RChar(R,ch);
	RETURN ch # 0X
	END GetChar;


(*

	(** A StringReader is a special reader that buffers input set by SetString or SetRawString. *)
	

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
(*			SYSTEM.MOVE( SYSTEM.ADR( s[0] ), SYSTEM.ADR( buf[0] ), len ) *)
		END;
	END SRSet;

	(** Set the contents of the string buffer.  The len parameter specifies the size of the buffer s. *)
	PROCEDURE SRSetRaw*( VAR SR: StringReader; s: ARRAY OF CHAR;  ofs, len: INTEGER );
	BEGIN
		IF len > StreamBufferSize THEN len := StreamBufferSize END;
		SR.head := 0;  SR.tail := len;  SR.received := len;  SR.res := Ok;
		ASSERT ( (len >= 0) & (ofs + len <= LEN( s )) );   (* index check *)
		IF len > 0 THEN
(*			SYSTEM.MOVE( SYSTEM.ADR( s[ofs] ), SYSTEM.ADR( buf[0] ), len )  *)
		END;
	END SRSetRaw;

	PROCEDURE InitStringReader*( VAR SR: StringReader; size: INTEGER );
	BEGIN
		InitReader( SYSTEM.VAL(Reader,SR), SRReceive, size )
	END InitStringReader;

*)
	(** Open a writer to the specified stream sender.  Update must be called after writing to ensure the buffer is written to the stream. *)
	PROCEDURE OpenWriter*( VAR b: Writer;  send: Sender );
	BEGIN
		
                InitWriter( b, send )
	END OpenWriter;

	(** Open a reader from the specified stream receiver. *)
	PROCEDURE OpenReader*( VAR b: Reader;  receive: Receiver );
	BEGIN
		
                InitReader( b, receive )
	END OpenReader;

(*
	(** Copy the contents of a reader to a writer *)
	PROCEDURE Copy* (r: Reader; w: Writer);
	VAR char: CHAR;
	BEGIN
		WHILE r.res = Ok DO
			RChar (R,char);
			IF r.res = Ok THEN WChar (W,char) END
		END;
	END Copy;

	(** from module Reals.Mod *)


	(*** the following procedures stem from Reals.Mod and are needed for Writer.Float and Writer.FloatFix *)

	(** Returns the NaN code (0 <= h < 1048576, MIN(LONGINT) <= l <= MAX(LONGINT)) or (-1,-1) if not NaN/Infinite. *)
	PROCEDURE NaNCodeL( x: LONGREAL;  VAR h, l: LONGINT );
	BEGIN
		SYSTEM.GET( ADDRESSOF( x ) + H, h );  SYSTEM.GET( ADDRESSOF( x ) + L, l );
		IF ASH( h, -20 ) MOD 2048 = 2047 THEN  (* Infinite or NaN *)
			h := h MOD 100000H (* lowest 20 bits *)
		ELSE h := -1;  l := -1
		END
	END NaNCodeL;

	(** Returns the shifted binary exponent (0 <= e < 2048). *)
	PROCEDURE ExpoL( x: LONGREAL ): LONGINT;
	VAR i: LONGINT;
	BEGIN
		SYSTEM.GET( ADDRESSOF( x ) + H, i );  RETURN ASH( i, -20 ) MOD 2048
	END ExpoL;

	(** Convert hexadecimal to LONGREAL. h and l are the high and low parts.*)
	PROCEDURE RealL( h, l: LONGINT ): LONGREAL;
	VAR x: LONGREAL;
	BEGIN
		SYSTEM.PUT( ADDRESSOF( x ) + H, h );  SYSTEM.PUT( ADDRESSOF( x ) + L, l );  RETURN x
	END RealL;

	(** Returns 10^e (e <= 308, 308 < e delivers IEEE-code +INF). *)
	PROCEDURE Ten( e: LONGINT ): LONGREAL;   (* naiive version *)
	VAR r: LONGREAL;
	BEGIN
		IF e < -307 THEN RETURN 0
		ELSIF 308 < e THEN RETURN RealL( 2146435072, 0 )
		END;
		r := 1;
		WHILE (e > 0) DO r := r * 10;  DEC( e );  END;
		WHILE (e < 0) DO r := r / 10;  INC( e );  END;
		RETURN r;
	END Ten;

	PROCEDURE InitHL;
	VAR i: ADDRESS;  dmy: INTEGER;  littleEndian: BOOLEAN;
	BEGIN
		dmy := 1;  i := ADDRESSOF( dmy );
		SYSTEM.GET( i, littleEndian );   (* indirection via i avoids warning on SUN cc -O *)
		IF littleEndian THEN H := 4;  L := 0 ELSE H := 0;  L := 4 END
	END InitHL;
*)

BEGIN
	months := " Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"; (*  InitHL; *)
END Streams.

(**
Notes:
o	Any single buffer instance must not be accessed by more than one process concurrently.
o 	The interface is blocking (synchronous).  If an output buffer is full, it is written with a synchronous write, which returns
	only when all the data has been written.   If an input buffer is empty, it is read with a synchronous read, which only returns
	once some data has been read.  The only exception is the Available() procedure, which "peeks" at the input stream
	and returns 0 if no data is currently available.
o 	All procedures set res to the error code reported by the lower-level I/O operation (non-zero indicates error).
	 E.g. closing an underlying TCP connection will result in the Read* procedures returning a non-zero error code.
o 	res is sticky.  Once it becomes non-zero, it remains non-zero.
o 	The only way to detect end of file is to attempt to read past the end of file, which returns a non-zero error code.
o 	All output written to an erroneous buffer is ignored.
o 	The value returned when reading from an erroneous buffer is undefined, except for the Read procedure, which returns 0X.
o 	ReadBytes sets the len parameter to the number of bytes that were actually read, e.g. if size = 10, and only 8 bytes are read, len is 8.
o 	Raw format is little-endian 2's complement integers, IEEE reals and 0X-terminated strings.
o 	Syntax for ReadInt with hex = FALSE: num = ["-"] digit {digit}. digit = "0".."9".
o 	Syntax for ReadInt with hex = TRUE: ["-"] hexdigit {hexdigit} ["H"|"h"]. hexdigit = digit | "A".."F" | "a".."f".
o 	ReadInt with hex = TRUE allows "A".."F" as digits, and looks for a "H" character after the number.
	If present, the number is interpreted as hexadecimal.  If hexadecimal digits are present, but no "H" flag,
	the resulting decimal value is undefined.
o 	ReadInt ignores overflow.
o 	A Sender sends len bytes from buf at ofs to output and returns res non-zero on error.  It waits until all the data is written,
	or an error occurs.
o 	A Receiver receives up to size bytes from input into buf at ofs and returns the number of bytes read in len.
	It returns res non-zero on error.  It waits until at least min bytes (possibly zero) are available, or an error occurs.
o 	EOLN and ReadLn recognize the following end-of-line characters: CR, LF and CR/LF.
o 	To read an unstructured file token-by-token: WHILE (r.res = 0) DO SkipWhitespace; ReadToken END
o 	To read a line structured file token-by-token: WHILE r.res = 0 DO SkipSpaces; WHILE ~EOLN DO ReadToken; SkipSpaces END END
o 	A string writer is not flushed when it becomes full, but res is set to a non-zero value.
o 	Update has no effect on a string writer.
o 	GetString can be called on a string writer to return the buffer contents and reset it to empty.
o 	GetString always appends a 0X character to the buffer, but returns the true length (excluding the added 0X) in the len parameter,
	so it can also be used for binary data that includes 0X characters.
o 	Receive procedure should set res to EOF when attempting to read past the end of file.
*)


(*
to do:
o stream byte count
o read formatted data
o reads for all formatted writes
o write reals
o low-level version that can be used in kernel (below KernelLog)
*)
