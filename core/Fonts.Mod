MODULE Fonts; (*JG 18.11.90; PDR 8.6.12; NW 25.3.2013; CP 12.2018,1.2019*)
  IMPORT SYSTEM, Files;  

  CONST FontFileId = 0DBH;
        PcfFileId = 01H; 

  TYPE
    Font* = POINTER TO FontDesc;
    FontDesc* = RECORD
      name*: ARRAY 32 OF CHAR;
      height*, minX*, maxX*, minY*, maxY*: INTEGER;
      next*: Font;
      spani: INTEGER;
      spane: INTEGER;
      T: ARRAY 128 OF INTEGER;
      raster: ARRAY 2360 OF BYTE
    END ;

    LargeFontDesc = RECORD (FontDesc) ext: ARRAY 6656 OF BYTE END ; (* 2560 *)
    LargeFont = POINTER TO LargeFontDesc;

  (* raster sizes: Syntax8 1367, Syntax10 1628, Syntax12 1688, Syntax14 1843, Syntax14b 1983,
      Syntax16 2271, Syntax20 3034, Syntac24 4274, Syntax24b 4302  *)
    
    tocEntry = RECORD
        typ:    INTEGER;
        format: INTEGER;
        size:   INTEGER;
        offset: INTEGER
    END;

    Metrics = RECORD
	l,r,w,a,d: INTEGER
    END;

VAR Default*, root*: Font;
   
PROCEDURE GetWPat*(fnt: Font; ch: CHAR; pg: CHAR; VAR dx, x, y, w, h, patadr: INTEGER);
  VAR pa: INTEGER;  dxb, xb, yb, wb, hb: BYTE;
BEGIN pa := fnt.T[ORD(ch) MOD 80H]; patadr := pa;
  SYSTEM.GET(pa-3, dxb); SYSTEM.GET(pa-2, xb); SYSTEM.GET(pa-1, yb); SYSTEM.GET(pa, wb); SYSTEM.GET(pa+1, hb);
  dx := dxb; x := xb; y := yb; w := wb; h := hb;
  IF yb < 128 THEN y := yb ELSE y := yb - 256 END
END GetWPat;

PROCEDURE GetPat*(fnt: Font; ch: CHAR; VAR dx, x, y, w, h, patadr: INTEGER);
BEGIN
  GetWPat(fnt, ch, ch, dx, x, y, w, h, patadr)
END GetPat;

PROCEDURE RdInt16(VAR R: Files.Rider; VAR b0: BYTE);
    VAR b1: BYTE;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1)
END RdInt16;

PROCEDURE RdL16(VAR R: Files.Rider): INTEGER;
    VAR b0,b1: BYTE;
      x: INTEGER;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1); x:= (100H * b1) + b0 ; RETURN x
END RdL16;

PROCEDURE RdB16(VAR R: Files.Rider): INTEGER;
    VAR b0,b1: BYTE;
      x: INTEGER;
BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1); x:= (100H * b0) + b1 ; RETURN x
END RdB16;


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

PROCEDURE RdB32(VAR R: Files.Rider): INTEGER;
    VAR b0,b1,b2,b3: BYTE;
      x: INTEGER;
BEGIN
   Files.ReadByte(R, b0);
   Files.ReadByte(R, b1);
   Files.ReadByte(R, b2);
   Files.ReadByte(R, b3);
     x:= (1000000H * b0) + (10000H * b1) + (100H * b2) + b3;
    RETURN x
END RdB32;


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

PROCEDURE RdL32p(VAR R: Files.Rider): INTEGER;
    VAR b0,b1,b2,b3: BYTE;
      x: INTEGER;
BEGIN
   Files.ReadByte(R, b0); LED(b0);
   Files.ReadByte(R, b1); LED(b1);
   Files.ReadByte(R, b2); LED(b2);
   Files.ReadByte(R, b3); LED(b3);
     x:= (1000000H * b3) + (10000H * b2) + (100H * b1) + b0;
    RETURN x
END RdL32p;

PROCEDURE RdB32p(VAR R: Files.Rider): INTEGER;
    VAR b0,b1,b2,b3: BYTE;
      x: INTEGER;
BEGIN
   Files.ReadByte(R, b0); LED(b0);
   Files.ReadByte(R, b1); LED(b1);
   Files.ReadByte(R, b2); LED(b2);
   Files.ReadByte(R, b3); LED(b3);
     x:= (1000000H * b0) + (10000H * b1) + (100H * b2) + b3;
    RETURN x
END RdB32p;



PROCEDURE LoadOberonFont(VAR R: Files.Rider): Font;

  TYPE RunRec = RECORD beg, end: BYTE END ;
    BoxRec = RECORD dx, x, y, w, h: BYTE END ;

  VAR F: Font; LF: LargeFont;
    NofRuns, NofBoxes: BYTE;
    NofBytes: INTEGER;
    height, minX, maxX, minY, maxY: BYTE;
    i, j, k, l, m, n, nn: INTEGER;
    a, a0: INTEGER;
    b, beg, end: BYTE;
    run: ARRAY 16 OF RunRec;
    box: ARRAY 512 OF BoxRec;

BEGIN

    Files.ReadByte(R, b); (*abstraction*)
    Files.ReadByte(R, b); (*family*)
    Files.ReadByte(R, b); (*variant*)
        
    RdInt16(R, height); RdInt16(R, minX); RdInt16(R, maxX); RdInt16(R, minY); RdInt16(R, maxY); RdInt16(R, NofRuns);
    NofBoxes := 0; k := 0;
    WHILE k # NofRuns DO
      RdInt16(R, beg);
      run[k].beg := beg; RdInt16(R, end);
      run[k].end := end; NofBoxes := NofBoxes + end - beg; INC(k)
    END;
    NofBytes := 5; j := 0;
    WHILE j # NofBoxes DO
      RdInt16(R, box[j].dx); RdInt16(R, box[j].x); RdInt16(R, box[j].y);
      RdInt16(R, box[j].w); RdInt16(R, box[j].h);
      NofBytes := NofBytes + 5 + (box[j].w + 7) DIV 8 * box[j].h;
      INC(j)
    END;
    IF NofBytes < 2300 THEN NEW(F) ELSE NEW(LF); F := LF END ;
        
    F.height := height; F.minX := minX; F.maxX := maxX; F.maxY := maxY;
    IF minY >= 80H THEN F.minY := minY - 100H ELSE F.minY := minY END ;
    a0 := SYSTEM.ADR(F.raster[0]);
    SYSTEM.PUT(a0, 0X); SYSTEM.PUT(a0+1, 0X); SYSTEM.PUT(a0+2, 0X); SYSTEM.PUT(a0+3, 0X); SYSTEM.PUT(a0+4, 0X);
    (*null pattern for characters not in a run*)
    INC(a0, 2); a := a0+3; j := 0; k := 0; m := 0;
    WHILE k < NofRuns DO
      WHILE (m < run[k].beg) & (m < 128) DO F.T[m] := a0; INC(m) END;
      WHILE (m < run[k].end) & (m < 128) DO 
        F.T[m] := a+3;
        SYSTEM.PUT(a, box[j].dx); SYSTEM.PUT(a+1, box[j].x); SYSTEM.PUT(a+2, box[j].y);
        SYSTEM.PUT(a+3, box[j].w); SYSTEM.PUT(a+4, box[j].h); INC(a, 5);
        n := (box[j].w + 7) DIV 8 * box[j].h;
        WHILE n # 0 DO DEC(n); Files.ReadByte(R, b); SYSTEM.PUT(a, b); INC(a) END ;
        INC(j); INC(m) 
      END;
      INC(k)
    END;
    WHILE m < 128 DO F.T[m] := a0; INC(m) END ;

  RETURN F
END LoadOberonFont;

PROCEDURE LoadPcfFont(VAR R: Files.Rider): Font;
  VAR F: Font; LF: LargeFont;
    M,C,T: Files.Rider;
    i, j, k, l, m, tm, n, nn, oo: INTEGER;
    fc,lc,fr,lr,td,tc: INTEGER;
    a, t, tl, pw, ph: INTEGER;
    b,bx,b0,b1,b2,b3: BYTE;
    mt:  Metrics;
    mo: ARRAY 128 OF INTEGER;

    toc: POINTER TO tocEntry;
    pcfPROPERTIES:       POINTER TO tocEntry;
    pcfACCELERATORS:     POINTER TO tocEntry;
    pcfMETRICS:          POINTER TO tocEntry;
    pcfBITMAPS:         POINTER TO tocEntry;
    pcfINKMETRICS:      POINTER TO tocEntry;
    pcfBDFENCODINGS:    POINTER TO tocEntry;
    pcfSWIDTHS:         POINTER TO tocEntry;
    pcfGLYPHNAMES:     POINTER TO tocEntry;
    pcfBDFACCELERATORS:  POINTER TO tocEntry;

BEGIN

    pcfPROPERTIES:=NIL;
    pcfACCELERATORS:=NIL;
    pcfMETRICS:=NIL;
    pcfBITMAPS:=NIL;
    pcfINKMETRICS:=NIL;
    pcfBDFENCODINGS:=NIL;
    pcfSWIDTHS:=NIL;
    pcfGLYPHNAMES:=NIL;
    pcfBDFACCELERATORS:=NIL;

  tl := RdL32(R);
  t:=0;

  WHILE ((tl # 0) & (t < 9)) DO
    NEW(toc);
    toc.typ := RdL32(R);
    toc.format := RdL32(R);
    toc.size := RdL32(R);
    toc.offset := RdL32(R);
    IF (toc.typ = 1) THEN pcfPROPERTIES := toc END;
    IF (toc.typ = 2) THEN pcfACCELERATORS := toc END;
    IF (toc.typ = 4) THEN pcfMETRICS := toc END;
    IF (toc.typ = 8) THEN pcfBITMAPS := toc END;
    IF (toc.typ = 16) THEN pcfINKMETRICS := toc END;
    IF (toc.typ = 32) THEN pcfBDFENCODINGS := toc END;
    IF (toc.typ = 64) THEN pcfSWIDTHS := toc END;
    IF (toc.typ = 128) THEN pcfGLYPHNAMES := toc END;
    IF (toc.typ = 256) THEN pcfBDFACCELERATORS := toc END;
    INC(t);DEC(tl)
  END; 

  Files.Set(T,Files.Base(R),pcfBDFENCODINGS.offset);  m:= RdL32(T);  
  fc:= RdB16(T);LED(55);LED(55);LED(pcfBDFENCODINGS.offset);LED(m);
  lc:= RdB16(T);
  fr:= RdB16(T);
  lr:= RdB16(T);
  td:= RdB16(T);LED(fc);LED(lc);LED(fr);LED(lr);LED(td);LED(55);LED(55);
  tc:= (lc - fc + 1) * (lr - fr + 1);


  Files.Set(C,Files.Base(R),pcfBITMAPS.offset);  oo:= RdL32(C);  n:= RdB32p(C); 
  Files.Set(M,Files.Base(R),pcfMETRICS.offset);  m:= RdL32(M);  nn:= RdL16(M);
  
  NEW(LF); F := LF;

  m:=0;
  a:=0;
  WHILE m # 128 DO 
   IF m < n THEN
    tm:=m - fc;

(*
    IF (m - fc > -1) THEN
      tm:= m - fc;   (* +((m DIV 256)*(fc+(255-lc)))+(fr*256); *)
      Files.Set(T,Files.Base(R),pcfBDFENCODINGS.offset+14+(tm*2));  tm:= RdL16(T)
    ELSE
      tm := 3
    END;
*)
    IF (tm = 65535) THEN tm := td END;

    IF (tm < 0) THEN tm := 0 END;



    IF ((a+3)<2360) THEN  F.T[m] := SYSTEM.ADR(F.raster[a+3])
                     ELSE F.T[m] := SYSTEM.ADR(LF.ext[(a+3)-2360]) END;

    Files.Set(C,Files.Base(R),pcfBITMAPS.offset+8+(4*tm));
    l:=RdB32(C);

    Files.Set(M,Files.Base(R),pcfMETRICS.offset+6+(5*tm));
    Files.ReadByte(M, b); mt.l:=b - 128;
    Files.ReadByte(M, b); mt.r:=b - 128;
    Files.ReadByte(M, b); mt.w:=b - 128;
    Files.ReadByte(M, b); mt.a:=b - 128;
    Files.ReadByte(M, b); mt.d:=b - 128;
    ph := mt.d + mt.a;

    IF mt.w < 9 THEN pw := 8 ELSE IF mt.w < 17 THEN pw:= 16 ELSE IF mt.w < 33 THEN pw:= 32 ELSE IF mt.w < 97 THEN pw:= 96 ELSE pw := 128 END END END END;

    Files.Set(R,Files.Base(R),(8+(4*n) + 16) + pcfBITMAPS.offset+l);

 
    
    
    
    IF (a<2360) THEN F.raster[a] := pw     ELSE LF.ext[a    -2360]:=pw END;
    IF ((a+1)<2360) THEN F.raster[a+1]:=0  ELSE LF.ext[(a+1)-2360]:=0 END;
    IF ((a+2)<2360) THEN F.raster[a+2]:=0  ELSE LF.ext[(a+2)-2360]:=0 END;
    IF ((a+2)<2360) THEN F.raster[a+3]:=pw ELSE LF.ext[(a+3)-2360]:=pw END;
    IF ((a+2)<2360) THEN F.raster[a+4]:=ph ELSE LF.ext[(a+4)-2360]:=ph END;
    INC(a, 5);


    j:=ph; 
    WHILE (j # 0) DO   
       
      Files.ReadByte(R, b0); 
      Files.ReadByte(R, b1); 
      Files.ReadByte(R, b2); 
      Files.ReadByte(R, b3); 

      IF pw = 8 THEN
        IF (a+j-1<2360) THEN F.raster[a+j-1]:=Reverse(b0) ELSE LF.ext[a+j-1-2360]:=Reverse(b0) END;
      END;
      IF pw = 16 THEN
        IF (a+((j-1)*2)<2360) THEN F.raster[a+((j-1)*2)]:=Reverse(b0) ELSE LF.ext[a+((j-1)*2)-2360]:=Reverse(b0) END;
        IF (a+((j-1)*2)+1<2360) THEN F.raster[a+((j-1)*2)+1]:=Reverse(b1) ELSE LF.ext[a+((j-1)*2)+1-2360]:=Reverse(b1) END;
      END;


      DEC(j)
      
    END;
    INC(a,ph*(pw DIV 8))
   ELSE
    F.T[m] := SYSTEM.ADR(F.raster[3])
   END;
   INC(m)
  END;
  F.height := ph; F.minX := 0; F.maxX := pw; F.maxY := ph; F.minY := 0;

  RETURN F
END LoadPcfFont;

PROCEDURE This*(name: ARRAY OF CHAR): Font;

  TYPE RunRec = RECORD beg, end: BYTE END ;
    BoxRec = RECORD dx, x, y, w, h: BYTE END ;
    
  VAR F: Font;
    f: Files.File; R: Files.Rider;
    b,b2,b3: BYTE;

BEGIN F := root;
  WHILE (F # NIL) & (name # F.name) DO F := F.next END;
  IF F = NIL THEN
    f := Files.Old(name);
    IF f # NIL THEN
      Files.Set(R, f, 0); Files.ReadByte(R, b);
      IF b = FontFileId THEN

        F := LoadOberonFont(R);        
        F.name := name;
        F.next := root; 
        root := F

      ELSE (* not a native Oberon font file... pcf?*) 
        IF b = PcfFileId THEN 
          Files.ReadByte(R, b); Files.ReadByte(R, b2); Files.ReadByte(R, b3);
          IF (b = 066H) & (b2 = 063H) & (b3 = 070H) THEN 

            F := LoadPcfFont(R)

          ELSE (*font file format not pcf *) F := Default
          END
        ELSE (*font file format unknown *) F := Default
        END
      END
    ELSE (*font file not available*) F := Default
    END
  END;
  RETURN F
END This;

PROCEDURE Free*;  (*remove all but first two from font list*)
  VAR f: Font;
BEGIN f := root.next;
  IF f # NIL THEN f := f.next END ;
  f.next := NIL
END Free;

BEGIN root := NIL; Default := This("Syntax14.Scn.Fnt")
END Fonts.




