MODULE Fonts; (*JG 18.11.90; PDR 8.6.12; NW 18.1.2019 CP 2018,2019*)
              (*MS 1.2019 adapted for Unicode*)

  IMPORT SYSTEM, Files;

  CONST FontFileId = 0DBH;
        PcfFileId = 01H;

  TYPE Font* = POINTER TO FontDesc;
    RasterBlock = POINTER TO RasterBlockDesc;
    FontDesc* = RECORD
      name*: ARRAY 32 OF CHAR;
      height*, minX*, maxX*, minY*, maxY*: INTEGER;
      next*: Font;
      T1: ARRAY 64 OF INTEGER;
      block: RasterBlock;
    END;

    RasterBlockDesc = RECORD
      next: RasterBlock;
      offs: INTEGER;
      raster: ARRAY 1000 OF BYTE;
    END;

    tocEntry = RECORD
        typ:    INTEGER;
        format: INTEGER;
        size:   INTEGER;
        offset: INTEGER
    END;

    tocTable = POINTER TO tocTableDesc;
    tocTableDesc = RECORD
      PROPERTIES:       POINTER TO tocEntry;
      ACCELERATORS:     POINTER TO tocEntry;
      METRICS:          POINTER TO tocEntry;
      BITMAPS:         POINTER TO tocEntry;
      INKMETRICS:      POINTER TO tocEntry;
      BDFENCODINGS:    POINTER TO tocEntry;
      SWIDTHS:         POINTER TO tocEntry;
      GLYPHNAMES:     POINTER TO tocEntry;
      BDFACCELERATORS:  POINTER TO tocEntry
    END;

    Metrics = RECORD
        l,r,w,a,d: INTEGER
    END;
    
VAR Default*, root*: Font;
  FallbackPat: ARRAY 35 OF BYTE;

PROCEDURE ReadInt16(VAR R: Files.Rider; VAR r: INTEGER);
  VAR b0, b1: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1); r := b1 * 100H + b0;
END ReadInt16;

PROCEDURE ReadBeInt16(VAR R: Files.Rider; VAR r: INTEGER);
  VAR b0, b1: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1); r := b0 * 100H + b1;
END ReadBeInt16; 

PROCEDURE ReadBeInt32(VAR R: Files.Rider; VAR r: INTEGER);
  VAR b0, b1, b2, b3: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1);
      Files.ReadByte(R, b2); Files.ReadByte(R, b3); r := b0 * 1000000H + b1 * 10000H + b2 * 100H + b3;
END ReadBeInt32;

PROCEDURE RdInt16(VAR R: Files.Rider; VAR b0: BYTE);
  VAR b1: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1)
END RdInt16;

PROCEDURE RdL32(VAR R: Files.Rider): INTEGER;
    VAR b0,b1,b2,b3: BYTE;
      x: INTEGER;
BEGIN
   Files.ReadByte(R, b0);
   Files.ReadByte(R, b1);
   Files.ReadByte(R, b2);
   Files.ReadByte(R, b3);
     x:= (1000000H * b3) + (10000H * b2) + (100H * b1) + b0;
    RETURN x
END RdL32;

PROCEDURE Reverse(b:BYTE): BYTE;
    VAR r: BYTE;
BEGIN
    r:=0;
    IF (b MOD 2) = 1 THEN r := r + 128 END;
    IF ((b DIV 2) MOD 2) = 1 THEN r := r + 64 END;
    IF ((b DIV 4) MOD 2) = 1 THEN r := r + 32 END;
    IF ((b DIV 8) MOD 2) = 1 THEN r := r + 16 END;
    IF ((b DIV 16) MOD 2) = 1 THEN r := r + 8 END;
    IF ((b DIV 32) MOD 2) = 1 THEN r := r + 4 END;
    IF ((b DIV 64) MOD 2) = 1 THEN r := r + 2 END;
    IF ((b DIV 128) MOD 2) = 1 THEN r := r + 1 END;
    RETURN r
END Reverse;

PROCEDURE FindSpace(B: RasterBlock; size, align: INTEGER): INTEGER;
VAR result: INTEGER;
BEGIN
  WHILE (B.offs + size + align - 1 > 1000) DO
    IF (B.next = NIL) THEN NEW(B.next) END;
    B := B.next
  END;
  WHILE (B.offs MOD align # 0) DO
    INC(B.offs);
  END;
  result := SYSTEM.ADR(B.raster[B.offs]);
  INC(B.offs, size);
  RETURN result
END FindSpace;

PROCEDURE OberonLoadRange(F: Font; rangeStart: INTEGER; f: Files.File);
TYPE RunRec = RECORD beg, end: INTEGER END;
VAR rangeEnd, skipBytes, skipBoxesBefore, skipBoxesAfter, usedRuns, totalRuns: INTEGER;
    beg, end, i, j, k, n, a, a1: INTEGER;
    R: Files.Rider; 
    b, dx, x, y, w, h: BYTE;
    run: ARRAY 32 OF RunRec;
BEGIN
  a := FindSpace(F.block, 256, 4);
  SYSTEM.PUT(F.T1[rangeStart DIV 1000H] + (rangeStart DIV 40H MOD 40H) * 4, a);
  rangeEnd := rangeStart + 64; skipBytes := 0; skipBoxesBefore := 0; skipBoxesAfter := 0;
  Files.Set(R, f, 14); ReadInt16(R, totalRuns);
  i := 0; usedRuns := 0;
  WHILE i # totalRuns DO
    ReadInt16(R, beg); ReadInt16(R, end);
    IF end > rangeEnd THEN 
       skipBoxesAfter := skipBoxesAfter + end - rangeEnd; end := rangeEnd 
    END;
    IF beg < rangeStart THEN 
       skipBoxesBefore := skipBoxesBefore + rangeStart - beg; beg := rangeStart 
    END;
    IF end <= rangeStart THEN
      skipBoxesBefore := skipBoxesBefore + end - beg;
    ELSIF beg >= rangeEnd THEN
      skipBoxesAfter := skipBoxesAfter + end - beg;
    ELSE
      run[usedRuns].beg := beg; run[usedRuns].end := end;
      INC(usedRuns);
    END;
    INC(i)
  END;
  i := 0;
  WHILE i # skipBoxesBefore DO
    RdInt16(R, dx); RdInt16(R, x); RdInt16(R, y);
    RdInt16(R, w); RdInt16(R, h);
    skipBytes := skipBytes + (w + 7) DIV 8 * h;
    INC(i)
  END;
  i := 0; j := 0;
  WHILE i < usedRuns DO
    j := run[i].beg;
    WHILE (j < run[i].end) DO
      RdInt16(R, dx); RdInt16(R, x); RdInt16(R, y);
      RdInt16(R, w); RdInt16(R, h);
      IF (dx # 0) OR (w # 0) OR (h # 0) THEN
        n := (w + 7) DIV 8 * h;
        a1 := FindSpace(F.block, n+5, 1);
        SYSTEM.PUT(a + (j - rangeStart) * 4, a1 + 3);
        SYSTEM.PUT(a1, dx); SYSTEM.PUT(a1+1, x); SYSTEM.PUT(a1+2, y);
        SYSTEM.PUT(a1+3, w); SYSTEM.PUT(a1+4, h);
      END;
      INC(j)
    END;
    INC(i)
  END;
  i := 0;
  WHILE i # skipBoxesAfter DO
    RdInt16(R, b); RdInt16(R, b); RdInt16(R, b);
    RdInt16(R, b); RdInt16(R, b);
    INC(i)
  END;
  i := 0;
  WHILE i < skipBytes DO Files.ReadByte(R, b); INC(i) END;
  i := 0; j := 0;
  WHILE i < usedRuns DO
    j := run[i].beg;
    WHILE (j < run[i].end) DO
      SYSTEM.GET(a + (j - rangeStart) * 4, a1);
      IF (a1 # 0) THEN
        SYSTEM.GET(a1, w); SYSTEM.GET(a1+1, h);
        n := (w + 7) DIV 8 * h;
        INC(a1, 2);
        WHILE n # 0 DO DEC(n); Files.ReadByte(R, b); SYSTEM.PUT(a1, b); INC(a1) END;
      END;
      INC(j)
    END;
    INC(i)
  END
END OberonLoadRange;

PROCEDURE PCFGetTable(f: Files.File): tocTable;
  VAR tt: tocTable; toc: POINTER TO tocEntry; R: Files.Rider; b: BYTE; t, tl, i: INTEGER;

BEGIN
  Files.Set(R, f, 4);
  tl := RdL32(R);
  t:=0;

  NEW(tt);

  tt.PROPERTIES:=NIL;
  tt.ACCELERATORS:=NIL;
  tt.METRICS:=NIL;
  tt.BITMAPS:=NIL;
  tt.INKMETRICS:=NIL;
  tt.BDFENCODINGS:=NIL;
  tt.SWIDTHS:=NIL;
  tt.GLYPHNAMES:=NIL;
  tt.BDFACCELERATORS:=NIL;

  WHILE ((tl # 0) & (t < 9)) DO
    NEW(toc);
    toc.typ := RdL32(R);
    toc.format := RdL32(R);
    toc.size := RdL32(R);
    toc.offset := RdL32(R);
    IF (toc.typ = 1) THEN tt.PROPERTIES := toc END;
    IF (toc.typ = 2) THEN tt.ACCELERATORS := toc END;
    IF (toc.typ = 4) THEN tt.METRICS := toc END;
    IF (toc.typ = 8) THEN tt.BITMAPS := toc END;
    IF (toc.typ = 16) THEN tt.INKMETRICS := toc END;
    IF (toc.typ = 32) THEN tt.BDFENCODINGS := toc END;
    IF (toc.typ = 64) THEN tt.SWIDTHS := toc END;
    IF (toc.typ = 128) THEN tt.GLYPHNAMES := toc END;
    IF (toc.typ = 256) THEN tt.BDFACCELERATORS := toc END;
    INC(t);DEC(tl)
  END;
  RETURN tt
END PCFGetTable;


PROCEDURE PCFLoadRange(F: Font; rangeStart: INTEGER; f: Files.File);
TYPE RunRec = RECORD beg, end: INTEGER END;
VAR rangeEnd, skipBytes, skipBoxesBefore, skipBoxesAfter, usedRuns, totalRuns: INTEGER;
    beg, end, i, j, k, n, a, a1: INTEGER;
    R: Files.Rider; 
    b, b0, b1, b2, b3, dx, x, y, w, h: BYTE; 
    tt: tocTable; 
    tm, bofs, fc, lc, fr, lr, df, cx, cc, ml, mr, mw, ma, md, mh, pw: INTEGER;
    run: ARRAY 32 OF RunRec;

BEGIN
  a := FindSpace(F.block, 256, 4);
  SYSTEM.PUT(F.T1[rangeStart DIV 1000H] + (rangeStart DIV 40H MOD 40H) * 4, a);
  rangeEnd := rangeStart + 64;
  dx:=8;x:=8;y:=8;w:=8;h:=8;
  beg:=rangeStart;
  end:=rangeEnd;
  i:=0;
  WHILE i < 64 DO
        n := (w + 7) DIV 8 * h;
        a1 := FindSpace(F.block, n+5, 1);
        SYSTEM.PUT(a + (i * 4), a1 + 3);
        SYSTEM.PUT(a1, dx); SYSTEM.PUT(a1+1, x); SYSTEM.PUT(a1+2, y);
        SYSTEM.PUT(a1+3, w); SYSTEM.PUT(a1+4, h);
	SYSTEM.PUT(a1+5, 1);
        SYSTEM.PUT(a1+6, 2);
        SYSTEM.PUT(a1+7, 4);
        SYSTEM.PUT(a1+8, 8);
        SYSTEM.PUT(a1+9, 16);
        SYSTEM.PUT(a1+10, 32);
        SYSTEM.PUT(a1+11, 64);
        SYSTEM.PUT(a1+12, 128);

    INC(i)
  END

(*
  tt := PCFGetTable(f);
  Files.Set(R, f, tt.BDFENCODINGS.offset+4);
  ReadBeInt16(R, fc); 
  ReadBeInt16(R, lc); 
  ReadBeInt16(R, fr); 
  ReadBeInt16(R, lr); 
  ReadBeInt16(R, df);
  cc := (lc - fc + 1) * (lr - fr + 1);
  beg := rangeStart; end := rangeStart + 40H; i:=beg;
  IF end > cc-1 THEN end := cc-1 END; 
  WHILE i < end DO
    tm:=i - fc;
    IF (i - fc > -1) THEN
      IF i > beg - 1 THEN
        Files.Set(R,f,tt.BDFENCODINGS.offset+14+(tm*2))
      END ;
      ReadBeInt16(R,tm)
    ELSE
      tm := df
    END;

    Files.Set(R, f, tt.BITMAPS.offset+4);  ReadBeInt32(R,n); 
    Files.Set(R, f, tt.BITMAPS.offset+8+(4*tm)); ReadBeInt32(R, bofs);
    (* Files.Set(R, f, METRICS.offset);  ReadBeInt32(R,m);  nn:= ReadBeInt16(R,nn); *)
    Files.Set(R, f, tt.METRICS.offset+6+(5*tm)); 
    Files.ReadByte(R, b); ml:=b-128;  
    Files.ReadByte(R, b); mr:=b-128;
    Files.ReadByte(R, b); mw:=b-128;
    Files.ReadByte(R, b); ma:=b-128;
    Files.ReadByte(R, b); md:=b-128;

    mh:=md+ma;
    IF mw < 9 THEN 
      pw := 8 
    ELSE IF mw < 17 THEN 
      pw:= 16 
    ELSE IF mw < 33 THEN 
      pw:= 32 
    ELSE IF mw < 97 THEN 
      pw:= 96 
    ELSE 
      pw := 128 
    END END END END;

    Files.Set(R, f, (8+(4*n) + 16) + tt.BITMAPS.offset+bofs);

    j:=mh; WHILE (j # 0) DO
        Files.ReadByte(R, b0); 
        Files.ReadByte(R, b1); 
        Files.ReadByte(R, b2); 
        Files.ReadByte(R, b3);

        IF pw = 8 THEN
(*          IF (a+j-1<2360) THEN C.raster[a+j-1]:=Reverse(b0) ELSE LC.ext[a+j-1-2360]:=Reverse(b0) END;                         *)
        END;
        IF pw = 16 THEN
(*          IF (a+((j-1)*2)<2360) THEN C.raster[a+((j-1)*2)]:=Reverse(b0) ELSE LC.ext[a+((j-1)*2)-2360]:=Reverse(b0) END;       *)
(*          IF (a+((j-1)*2)+1<2360) THEN C.raster[a+((j-1)*2)+1]:=Reverse(b1) ELSE LC.ext[a+((j-1)*2)+1-2360]:=Reverse(b1) END; *)
        END;


        DEC(j)

    END;

(*      INC(a,mh*(pw DIV 8))   *)

 END 
  
  (* skipBoxesBefore *)

  i := 0; j := 0;
  WHILE i < usedRuns DO
    j := run[i].beg;
    WHILE (j < run[i].end) DO
      RdInt16(R, dx); RdInt16(R, x); RdInt16(R, y);
      RdInt16(R, w); RdInt16(R, h);
      IF (dx # 0) OR (w # 0) OR (h # 0) THEN
        n := (w + 7) DIV 8 * h;
        a1 := FindSpace(F.block, n+5, 1);
        SYSTEM.PUT(a + (j - rangeStart) * 4, a1 + 3);
        SYSTEM.PUT(a1, dx); SYSTEM.PUT(a1+1, x); SYSTEM.PUT(a1+2, y);
        SYSTEM.PUT(a1+3, w); SYSTEM.PUT(a1+4, h);
      END;
      INC(j)
    END;
    INC(i)
  END;
  i := 0;
  WHILE i # skipBoxesAfter DO
    RdInt16(R, b); RdInt16(R, b); RdInt16(R, b);
    RdInt16(R, b); RdInt16(R, b);
    INC(i)
  END;
  i := 0;
  WHILE i < skipBytes DO Files.ReadByte(R, b); INC(i) END;
  i := 0; j := 0;
  WHILE i < usedRuns DO
    j := run[i].beg;
    WHILE (j < run[i].end) DO
      SYSTEM.GET(a + (j - rangeStart) * 4, a1);
      IF (a1 # 0) THEN
        SYSTEM.GET(a1, w); SYSTEM.GET(a1+1, h);
        n := (w + 7) DIV 8 * h;
        INC(a1, 2);
        WHILE n # 0 DO DEC(n); Files.ReadByte(R, b); SYSTEM.PUT(a1, b); INC(a1) END;
      END;
      INC(j)
    END;
    INC(i)
  END
*)
  
END PCFLoadRange;


PROCEDURE LoadRange(F: Font; rangeStart: INTEGER);
  VAR f: Files.File; R: Files.Rider;
      b, b2, b3: BYTE;
BEGIN
  f := Files.Old(F.name);
  Files.Set(R, f, 0); Files.ReadByte(R, b);
  IF b = FontFileId THEN
    OberonLoadRange(F,rangeStart,f)
  ELSE
    IF b = PcfFileId THEN
      Files.ReadByte(R, b); Files.ReadByte(R, b2); Files.ReadByte(R, b3);
      IF (b = 066H) & (b2 = 063H) & (b3 = 070H) THEN
        PCFLoadRange(F,rangeStart,f)
      END
    END
  END
END LoadRange;

PROCEDURE PatDot(x,y: INTEGER);
  VAR s : SET; i : INTEGER;
BEGIN
  i := FallbackPat[y * 3 + (x DIV 8) + 2];
  s := SYSTEM.VAL(SET, i);
  s := s + {x MOD 8};
  i := SYSTEM.VAL(INTEGER, s);
  FallbackPat[y * 3 + (x DIV 8) + 2] := i
END PatDot;

PROCEDURE GetUniPat*(fnt: Font; codepoint: INTEGER; VAR dx, x, y, w, h, patadr: INTEGER);
  VAR pa, i1, i2, i3: INTEGER;  dxb, xb, yb, wb, hb: BYTE;
BEGIN
  i1 := codepoint DIV 1000H;
  i2 := codepoint DIV 40H MOD 40H;
  i3 := codepoint MOD 40H;
  pa := fnt.T1[i1];
  IF pa # 0 THEN
    SYSTEM.GET(pa + i2 * 4, pa);
    IF pa = 1 THEN
      LoadRange(fnt, codepoint DIV 40H * 40H);
      SYSTEM.GET(fnt.T1[i1] + i2 * 4, pa)
    END
  END;
  IF pa # 0 THEN SYSTEM.GET(pa + i3 * 4, pa) END;
  IF pa # 0 THEN
    patadr := pa;
    SYSTEM.GET(pa-3, dxb); 
    SYSTEM.GET(pa-2, xb); 
    SYSTEM.GET(pa-1, yb); 
    SYSTEM.GET(pa, wb); 
    SYSTEM.GET(pa+1, hb);
    dx := dxb; x := xb; y := yb; w := wb; h := hb;
    IF yb < 128 THEN y := yb ELSE y := yb - 256 END
  ELSE
    FallbackPat[0] := 23; FallbackPat[1] := 11;
    FallbackPat[2] := 0FFH; FallbackPat[3] := 0FFH; FallbackPat[4] := 07FH;
    FOR y := 0 TO 8 DO FallbackPat[5+y*3] := 1; FallbackPat[6+y*3] := 0; FallbackPat[7+y*3] := 40H END;
    FallbackPat[32] := 0FFH; FallbackPat[33] := 0FFH; FallbackPat[34] := 07FH;
    w := codepoint;
    FOR x := 15 TO 0 BY -5 DO
      h := w MOD 16; w := w DIV 16;
      IF (h # 1) & (h # 4) & (h # 0BH) & (h # 0DH) THEN PatDot(x+3, 8); PatDot(x+4, 8) END;
      IF (h # 1) & (h # 2) & (h # 3) & (h # 7) & (h # 0DH) THEN PatDot(x+2, 7); PatDot(x+2, 6) END;
      IF (h # 5) & (h # 6) & (h # 0BH) & (h # 0CH) & (h # 0EH) & (h # 0FH) THEN PatDot(x+5, 7); PatDot(x+5, 6) END;
      IF (h # 0) & (h # 1) & (h # 7) & (h # 0CH) THEN PatDot(x+3, 5); PatDot(x+4, 5) END;
      IF (h = 0) OR (h = 2) OR (h = 6) OR (h = 8) OR (h > 9) THEN PatDot(x+2, 4); PatDot(x+2, 3) END;
      IF (h # 2) & (h # 0CH) & (h # 0EH) & (h # 0FH) THEN PatDot(x+5, 4); PatDot(x+5, 3) END;
      IF (h # 1) & (h # 4) & (h # 7) & (h # 0AH) & (h # 0FH) THEN PatDot(x+3, 2); PatDot(x+4, 2) END
    END;
    dx := 24; x := 0; y := fnt.minY; w := 23; h := 11;
    patadr := SYSTEM.ADR(FallbackPat)
  END
END GetUniPat;

PROCEDURE This*(name: ARRAY OF CHAR): Font;
  VAR F: Font;
    f: Files.File; R: Files.Rider;
    minY, b, b2, b3: BYTE;
    a, beg, end, i, i1, i2, NofRuns, k: INTEGER;
    tt: tocTable; fc, lc, fr, lr, df, cx, cc: INTEGER;
BEGIN F := root;
  WHILE (F # NIL) & (name # F.name) DO F := F.next END;
  IF F = NIL THEN
    f := Files.Old(name);
    IF f # NIL THEN
      Files.Set(R, f, 0); Files.ReadByte(R, b);
      IF b = FontFileId THEN
        Files.ReadByte(R, b); (*abstraction*)
        Files.ReadByte(R, b); (*family*)
        Files.ReadByte(R, b); (*variant*)
        NEW(F); NEW(F.block); F.name := name;
        ReadInt16(R, F.height); ReadInt16(R, F.minX); ReadInt16(R, F.maxX);
	RdInt16(R, minY); ReadInt16(R, F.maxY); ReadInt16(R, NofRuns);
        IF minY >= 80H THEN F.minY := minY - 100H ELSE F.minY := minY END;
        k := 0;
        WHILE k # NofRuns DO
          ReadInt16(R, beg); ReadInt16(R, end); i := beg;

	  WHILE i < end DO
	    i1 := i DIV 1000H;
	    i2 := i DIV 40H MOD 40H;
	    IF F.T1[i1] = 0 THEN
	      F.T1[i1] := FindSpace(F.block, 256, 4)
	    END;
	    SYSTEM.GET(F.T1[i1] + i2 * 4, a);
	    IF a = 0 THEN
	      a := 1;
	      SYSTEM.PUT(F.T1[i1] + i2 * 4, a)
	    END;
	    INC(i, 40H)
	  END;

          INC(k)
        END;
        F.next := root; root := F
      ELSE (* not a native Oberon font file... pcf?*)
        IF b = PcfFileId THEN
          Files.ReadByte(R, b); Files.ReadByte(R, b2); Files.ReadByte(R, b3);
          IF (b = 066H) & (b2 = 063H) & (b3 = 070H) THEN
            NEW(F); NEW(F.block); F.name := name;
            tt:=PCFGetTable(f);

            Files.Set(R, f, tt.BDFACCELERATORS.offset+24); 
                                  (* The following is probably not a correct mapping*)
            ReadBeInt16(R, i1); ReadBeInt16(R, i2); (*skip minlsb and minrsb*) 
            ReadBeInt16(R, i1); ReadBeInt16(R, i2); F.minY:=i1+i2; (*minasc + mindsc*)
            ReadBeInt16(R, i1); F.minY:=i1; (*minwidth*) 
            ReadBeInt16(R, i1); (*skip mincat*)
            ReadBeInt16(R, i1); ReadBeInt16(R, i2); (*skip maxlsb and maxrsb*) 
            ReadBeInt16(R, i1); ReadBeInt16(R, i2); F.maxY:=i1+i2; (*maxasc + maxdsc*)
            ReadBeInt16(R, i1); F.maxY:=i1; (*maxwidth*) 
            ReadBeInt16(R, i1); (*skip maxcat*)
            F.height:=F.maxY; 

            Files.Set(R, f, tt.BDFENCODINGS.offset+4);
            ReadBeInt16(R, fc); 
            ReadBeInt16(R, lc); 
            ReadBeInt16(R, fr); 
            ReadBeInt16(R, lr); 
            ReadBeInt16(R, df);
            cc := (lc - fc + 1) * (lr - fr + 1);
            beg := 0; end := cc-1; i:=beg;

            WHILE i < end DO
              ReadBeInt16(R, cx);
              IF cx # 65535 THEN 
                i1 := cx DIV 1000H;
                i2 := cx DIV 40H MOD 40H;
                IF F.T1[i1] = 0 THEN
                  F.T1[i1] := FindSpace(F.block, 256, 4)
                END;
                SYSTEM.GET(F.T1[i1] + i2 * 4, a);
                IF a = 0 THEN
                  a := 1;
                  SYSTEM.PUT(F.T1[i1] + i2 * 4, a)
                END
              END;
              INC(i, 1)  (* 40H *)
            END;

            F.next := root; root := F
          ELSE (* unrecognized font file *)
            F := Default
          END
        END
      END
    ELSE (*font file not available*) F := Default
    END
  END;
  RETURN F
END This;

PROCEDURE Free*;  (*remove all but first two from font list*)
BEGIN IF root.next # NIL THEN root.next.next := NIL END
END Free;

BEGIN root := NIL; Default := This("Syntax14.Scn.Fnt")
END Fonts.
