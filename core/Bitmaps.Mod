MODULE Bitmaps; (*TK 8.10.2017 / 7.9.2018 / CP 2.2019*)
IMPORT SYSTEM, Kernel, Oberon;

TYPE
  Bitmap* = POINTER TO BitmapDesc;
  BitmapDesc* = RECORD
    width*, height*, depth*: INTEGER;
    base*, size* : INTEGER
  END;

PROCEDURE New*(B: Bitmap; w, h, dpt: INTEGER) : Bitmap;
BEGIN (*
  IF B = NIL THEN NEW(B) END;
  IF B # NIL THEN
      B.width := w; B.height := h; B.depth := dpt;
      B.size := (w+31) DIV 32 * 4 * h; (*bitmap size in bytes, word aligned*)
      Memory.New(SYSTEM.VAL(Memory.Pointer, B.base), B.size);
      IF B.base = 0 THEN B := NIL END
  END *)
  RETURN B 
END New;

PROCEDURE Get*(B: Bitmap; x, y: INTEGER): INTEGER;
  VAR ofs, wd: INTEGER; bt: BYTE;
BEGIN (*
  ofs := y*B.width + x; SYSTEM.GET(B.base + ofs, bt);
  wd :=  bt; *)
  RETURN wd 
END Get;

PROCEDURE Clear*(B: Bitmap);
 VAR adr, size: INTEGER;
BEGIN (*
  size := B.size;  adr := B.base;
  WHILE size > 0 DO
    (* 0101.. bit pattern for tests *)
    SYSTEM.PUT(adr, SYSTEM.VAL(INTEGER, 0AAAAAAAAH));
    (*SYSTEM.PUT(adr, SYSTEM.VAL(INTEGER, 0));*)
    INC(adr, 4);  DEC(size, 4)
  END *)
END Clear;

PROCEDURE Dot*(B: Bitmap; col, x, y, mode: INTEGER);
  VAR a, w, bw: INTEGER; u, s: SET;
BEGIN (* w := B.width;
    bw := (w+31) DIV 32 * 4;   (* number of bytes on bitmap line, word aligned *)
    a := B.base + y*bw + (x DIV 32)*4;        (* address of bitmap word *)
    s := {x MOD 32}; SYSTEM.GET(a, u);

    IF mode = Display.paint THEN SYSTEM.PUT(a, u + s)
    ELSIF mode = Display.invert THEN SYSTEM.PUT(a, u / s)
    ELSE (*mode = replace*)
      IF col = Display.black THEN SYSTEM.PUT(a, u + s) ELSE SYSTEM.PUT(a, u - s) END
    END
    *)
END Dot;

(* Shift & clip source word into pix sets according to x coordinate and w width *)

PROCEDURE Src2Pix(x, w, src: INTEGER; VAR pix1, pix2: SET);
  VAR x0, w0: INTEGER;
BEGIN

  (* (pix * {maskleft*8..31} * {0..maskright*8-1}) *)
(*
  w0 :=  w MOD 32; x0 := x MOD 32;

  SYSTEM.GET(src, pix2);
  IF w < 0 THEN pix2 := pix2*{0..w0} END;
  pix1 := LSL(pix2, x0);

  IF x0 > 0 THEN pix2 := ASR(pix2, -x0)*{0..x0-1}
  ELSE pix2 := {}
  END
*)
END Src2Pix;

(* Shift & clip constant word into pix sets according to x coordinate and w width *)

PROCEDURE Const2Pix(x, w, con: INTEGER; VAR pix1, pix2: SET);
  VAR x0, w0: INTEGER;
BEGIN

  (* (pix * {maskleft*8..31} * {0..maskright*8-1}) *)
(*
  w0 :=  w MOD 32; x0 := x MOD 32;

  pix2 := SYSTEM.VAL(SET, con);
  IF w < 0 THEN pix2 := pix2*{0..w0} END;
  pix1 := LSL(pix2, x0);

  IF x0 > 0 THEN pix2 := ASR(pix2, -x0)*{0..x0-1}
  ELSE pix2 := {}
  END
*)
END Const2Pix;

(* CopyPLine - Copy pattern line in paint mode *)

PROCEDURE CopyPLine(x, src, dst, w: INTEGER);
  VAR bt: BYTE; wd: INTEGER; pix1, pix2, pix: SET;
BEGIN
(*
  (*build pattern line; w < 32*)
  SYSTEM.GET(src, bt); INC(src); wd := bt;
  IF w > 8 THEN SYSTEM.GET(src, bt); INC(src); wd := bt*100H + wd;
    IF w > 16 THEN SYSTEM.GET(src, bt); INC(src); wd := bt*10000H + wd;
      IF w > 24 THEN SYSTEM.GET(src, bt); INC(src); wd := bt*1000000H + wd END
    END
  END;

  Const2Pix(x, w, wd, pix1, pix2);
  SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix1+pix);
  SYSTEM.GET(dst+4, pix); SYSTEM.PUT(dst+4, pix2+pix)
*)
END CopyPLine;

(* ReplBLine0 - Replicate bitmap line in replace mode *)

PROCEDURE ReplBLine0(col, x, dst, w: INTEGER);
  VAR pix1, pix2, pix: SET;
BEGIN
(*
  WHILE w > 0 DO

    DEC(w, 32); Const2Pix(x, w, -1, pix1, pix2);

    IF col = Display.black THEN (* paint black *)
      SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix1+pix);
      SYSTEM.GET(dst+4, pix); SYSTEM.PUT(dst+4, pix2+pix);
    ELSE (* erase white *)
      SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix-pix1);
      SYSTEM.GET(dst+4, pix); SYSTEM.PUT(dst+4, pix-pix2)
    END; INC(dst, 4)

  END
*)
END ReplBLine0;


(* CopyBLine1 - Copy bitmap line in paint mode *)

PROCEDURE CopyBLine1(x, src, dst, w: INTEGER);
  VAR pix1, pix2, pix: SET;
BEGIN
(*
  WHILE w > 0 DO

    DEC(w, 32); Src2Pix(x, w, src, pix1, pix2); INC(src, 4);
    SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix1+pix);
    INC(dst, 4); SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix2+pix)

  END
*)
END CopyBLine1;

(* CopyBLine0 - Copy bitmap line in replace mode *)

PROCEDURE CopyBLine0(x, src, dst, w: INTEGER);
BEGIN
(*
  ReplBLine0(Display.white, x, dst, w);  (*clear*)
  CopyBLine1(x, src, dst, w)                    (*paint*)
*)
END CopyBLine0;

(* CopyBLine2 - Copy bitmap line in invert mode *)

PROCEDURE CopyBLine2(x, src, dst, w: INTEGER);
  VAR pix1, pix2, pix: SET;
BEGIN
(*
  WHILE w > 0 DO

    DEC(w, 32); Src2Pix(x, w, src, pix1, pix2); INC(src, 4);
    SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix1/pix);
    INC(dst, 4); SYSTEM.GET(dst, pix); SYSTEM.PUT(dst, pix2/pix)

  END
*)
END CopyBLine2;

PROCEDURE CopyBlock*(sB, dB: Bitmap; sx, sy, w, h, dx, dy, mode: INTEGER);
  VAR w0, bw, src, dst: INTEGER;
BEGIN (* w0 := sB.width;
  bw := (w0+31) DIV 32 * 4;   (* number of bytes on bitmap line, word aligned *)
  src := sB.base + sy*bw + (sx DIV 32)*4;     (* source bottom left bitmap byte *);
  dst := dB.base + dy*bw + (dx DIV 32)*4;   (* destination *)

    IF mode = Display.invert THEN
      REPEAT
        CopyBLine2(dx, src, dst, w);
        DEC(h);  INC(src, bw);  INC(dst, bw)
      UNTIL h = 0
    ELSIF mode = Display.paint THEN
      REPEAT
        CopyBLine1(dx, src, dst, w);
        DEC(h);  INC(src, bw);  INC(dst, bw)
      UNTIL h = 0
    ELSIF mode = Display.replace THEN
      REPEAT
        CopyBLine0(dx, src, dst, w);
        DEC(h);  INC(src, bw);  INC(dst, bw)
      UNTIL h = 0
    END
*)
END CopyBlock;

PROCEDURE CopyPattern*(B: Bitmap; col, pat, x, y, mode: INTEGER);
  VAR dst: INTEGER; w, h, pw, bw: BYTE;
BEGIN (*
  SYSTEM.GET(pat, w); SYSTEM.GET(pat+1, h); INC(pat, 2);

  pw := (w+7) DIV 8;  (* bytes in pattern line *)
  bw := (B.width+31) DIV 32 *4;             (* bytes in bitmap line, word aligned *)
  dst := B.base + y*bw + (x DIV 32)*4;  (* bottom left address of bitmap raster *)

  REPEAT  (* loop over h lines *)
    CopyPLine(x, pat, dst, w (*, col, mode*));
    DEC(h);  INC(dst, bw);  INC(pat, pw)
  UNTIL h = 0
*)
END CopyPattern;

PROCEDURE ReplPattern*(B: Bitmap; col, pat, X, Y, W, H, mode: INTEGER);
  VAR x, y, pat0, dst: INTEGER; w, h, h0, nx, ny, pw, bw: BYTE;
BEGIN (*
  SYSTEM.GET(pat, w); SYSTEM.GET(pat+1, h); INC(pat, 2);
  h0 := h; pat0 := pat;

  pw := (w+7) DIV 8;  (* bytes in pattern line *)
  bw := (B.width+31) DIV 32 *4;     (* bytes in bitmap line, word aligned *)
  ny := Y+((B.height-Y) DIV H)*H;    (* number of patterns to fit vertically in bitmap*)
  nx := X+((B.width-X) DIV W)*W; (* number of patterns to fit horizontally in bitmap*)

  y := Y; WHILE y < ny DO        (* copy `ny' rows of patterns upwards, spanned by H pixels *)
    x := X; WHILE x < nx DO    (* copy `nx' patterns horizontally rightwards, spanned by W pixels*)
      dst := B.base + y*bw + (x DIV 32)*4;    (* bottom left address of bitmap raster, shifted by W pixels each step*)
    REPEAT  (* loop over h lines *)
      CopyPLine(x, pat, dst, w (*, col, mode*));
      DEC(h);  INC(dst, bw);  INC(pat, pw)
      UNTIL h = 0;
      h := h0; pat := pat0; INC(x, W)
    END; INC(y, H)
  END
*)
END ReplPattern;

PROCEDURE ReplConst*(B: Bitmap; col, x, y, w, h, mode: INTEGER);
  VAR w0, bw, dst: INTEGER;
BEGIN (*
  w0 := B.width;
  bw := (w0+31) DIV 32 * 4;        (* number of bytes on bitmap line, word aligned *)
  dst := B.base + y*bw + (x DIV 32)*4;        (* bottom left address of bitmap raster *)
  IF mode = Display.replace THEN
    REPEAT
      ReplBLine0(col, x, dst, w);
      DEC(h);  INC(dst, bw)
    UNTIL h = 0
  END
*)
END ReplConst;

PROCEDURE DisplayBlock*(B: Bitmap; sx, sy, w, h, dx, dy, mode: INTEGER);
  VAR bw, src, dst: INTEGER;
BEGIN (*
  bw := (w+31) DIV 32 * 4;         (* number of bytes on bitmap line, word aligned *)
  src := B.base;
  dy := Display.Height-dy-h;  (* convert dy to screen coordinate 0,0 = bottom,left *)
  dst := Display.Base + dy*dbw + (dx DIV 32)*4;               (* addr bottom left byte *)

  IF mode = Display.invert THEN
    REPEAT
      CopyBLine2(dx, src, dst, w);
      DEC(h);  INC(src, bw);  INC(dst, dbw)
    UNTIL h = 0
  ELSIF mode = Display.paint THEN
    REPEAT
      CopyBLine1(dx, src, dst, w);
      DEC(h);  INC(src, bw);  INC(dst, dbw)
    UNTIL h = 0
  ELSIF mode = Display.replace THEN
    REPEAT
      CopyBLine0(dx, src, dst, w);
      DEC(h);  INC(src, bw);  INC(dst, dbw)
    UNTIL h = 0
  END
*)
END DisplayBlock;

PROCEDURE GetPix*(VAR a: INTEGER; VAR bt: BYTE; depth: INTEGER);
BEGIN
(*
  SYSTEM.GET(a, bt); INC(a)
*)
END GetPix;

(*PROCEDURE PutPix*(a: INTEGER; VAR x: INTEGER; bt: BYTE; depth: INTEGER);
  VAR i: BYTE; u, s: SET;
BEGIN 
  FOR i := 0 TO 7 DO
    s := {x MOD 32}; SYSTEM.GET(a, u);
    IF ODD(bt) THEN SYSTEM.PUT(a, u + s) ELSE SYSTEM.PUT(a, u - s) END;
    INC(x); bt := bt DIV 2
  END
END PutPix;*)

PROCEDURE PutPix*(VAR a, x: INTEGER; bt: BYTE; depth: INTEGER);
  VAR wd: INTEGER; u, s: SET;
BEGIN (*
  wd := bt; s := SYSTEM.VAL(SET, LSL(wd, x MOD 32));
  SYSTEM.GET(a, u); SYSTEM.PUT(a, u + s);
  INC(a); INC(x, 8)
*)
END PutPix;

PROCEDURE Copy*(sB, dB: Bitmap; sx, sy, w, h, dx, dy, mode: INTEGER);
BEGIN (*
  CopyBlock(sB, dB, sx, sy, w, h, dx, dy, mode)
*)
END Copy;

PROCEDURE PutLine*(B: Bitmap; VAR data: ARRAY OF INTEGER; x, y, w: INTEGER);
  VAR dst, src, i: INTEGER; bt: BYTE;
BEGIN (*
  src := SYSTEM.ADR(data[0]); dst := B.base + y*B.width + x; i := w;
  WHILE i > 0 DO
    SYSTEM.GET(src, bt); SYSTEM.PUT(dst, bt);
    INC(src, 2); INC(dst);
    DEC(i)
  END
*)
END PutLine;

PROCEDURE GetLine*(B: Bitmap; VAR data: ARRAY OF INTEGER; x, y, w: INTEGER);
  VAR dst, src, i: INTEGER; bt: BYTE;
BEGIN (*
  dst := SYSTEM.ADR(data[0]); src := B.base + y*B.width + x; i := w;
  WHILE i > 0 DO
    SYSTEM.GET(src, bt); SYSTEM.PUT(dst, bt);
    INC(src); INC(dst, 2);
    DEC(i)
  END
*)
END GetLine;



BEGIN
END Bitmaps.
