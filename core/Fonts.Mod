MODULE Fonts; (*JG 18.11.90; PDR 8.6.12; NW 18.1.2019 CP 12.2018,1.2019*)
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
      T1: ARRAY 16 OF INTEGER;
      block: RasterBlock;
    END;

    RasterBlockDesc = RECORD
      next: RasterBlock;
      offs: INTEGER;
      raster: ARRAY 1000 OF BYTE;
    END;
    
VAR Default*, root*: Font;
  FallbackPat: ARRAY 35 OF BYTE;

PROCEDURE ReadInt16(VAR R: Files.Rider; VAR r: INTEGER);
  VAR b0, b1: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1); r := b1 * 100H + b0;
END ReadInt16;

PROCEDURE RdInt16(VAR R: Files.Rider; VAR b0: BYTE);
  VAR b1: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1)
END RdInt16;

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

PROCEDURE LoadRange(F: Font; rangeStart: INTEGER);
TYPE RunRec = RECORD beg, end: INTEGER END;
VAR rangeEnd, skipBytes, skipBoxesBefore, skipBoxesAfter, usedRuns, totalRuns, beg, end, i, j, k, n, a, a1: INTEGER;
  f: Files.File; R: Files.Rider;
  b, dx, x, y, w, h: BYTE;
  run: ARRAY 32 OF RunRec;
BEGIN
  a := FindSpace(F.block, 256, 4);
  SYSTEM.PUT(F.T1[rangeStart DIV 1000H] + (rangeStart DIV 40H MOD 40H) * 4, a);
  rangeEnd := rangeStart + 64; skipBytes := 0; skipBoxesBefore := 0; skipBoxesAfter := 0;
  f := Files.Old(F.name);
  Files.Set(R, f, 14); ReadInt16(R, totalRuns);
  i := 0; usedRuns := 0;
  WHILE i # totalRuns DO
    ReadInt16(R, beg); ReadInt16(R, end);
    IF end > rangeEnd THEN skipBoxesAfter := skipBoxesAfter + end - rangeEnd; end := rangeEnd END;
    IF beg < rangeStart THEN skipBoxesBefore := skipBoxesBefore + rangeStart - beg; beg := rangeStart END;
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
    SYSTEM.GET(pa-3, dxb); SYSTEM.GET(pa-2, xb); SYSTEM.GET(pa-1, yb); SYSTEM.GET(pa, wb); SYSTEM.GET(pa+1, hb);
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
            F.height:=8; F.minX:=8; F.maxX:=8; F.minY:=8; F.maxY:=8;        
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
