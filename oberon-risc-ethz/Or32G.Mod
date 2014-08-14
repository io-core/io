MODULE Or32G; (* NW  10.10.2013 CP 6.3.2014 RISC code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, O7X;
  (*Code generator for Oberon compiler for RISC processor.
     Procedural interface to Parser O7P; result in array "code".
     Procedure Close writes code-files*)  CONST
  (*frequently used opcodes -- abstract not machine values except for risc*)      U = 2000H;
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3; And = 4; Ann = 5; Ior = 6; Xor = 7;
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11;
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15;
    Ldr = 8; Str = 10;
    BR = 0; BLR = 1; BC = 2; BL = 3;
    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14;  PROCEDURE Put0(target: O7X.Target; u, op, a, b, c: LONGINT);
  BEGIN (*emit format-0 instruction*)
    target.code[target.pc] := ((a*10H + b) * 10H + (target.opmap[op]+u)) * 10000H + c; INC(target.pc)
  END Put0;
  PROCEDURE Put1(target: O7X.Target; u, op, a, b, im: LONGINT);
  BEGIN (*emit format-1 instruction,  -10000H <= im < 10000H*)
    IF im < 0 THEN INC(op, 1000H) END ;  (*set v-bit*)
    target.code[target.pc] := (((a+40H) * 10H + b) * 10H + (target.opmap[op]+u)) * 10000H + (im MOD 10000H); INC(target.pc)
  END Put1;

  PROCEDURE Put1a(target: O7X.Target; op, a, b, im: LONGINT);
  BEGIN (*same as Pu1, but with range test  -10000H <= im < 10000H*)
    IF (im >= -10000H) & (im <= 0FFFFH) THEN Put1(target, 0, op, a, b, im)
    ELSE Put1(target, U, Mov, target.RH, 0, im DIV 10000H);
      IF im MOD 10000H # 0 THEN Put1(target, 0, target.opmap[Ior], target.RH, target.RH, im MOD 10000H) END ;
      Put0(target, 0, op, a, b, target.RH)
    END
  END Put1a;

  PROCEDURE Put2(target: O7X.Target; op, a, b, off: LONGINT);
  BEGIN (*emit load/store instruction*)
    target.code[target.pc] := ((target.opmap[op] * 10H + a) * 10H + b) * 100000H + (off MOD 100000H); INC(target.pc)
  END Put2;  PROCEDURE Put3(target: O7X.Target; op, cond, off: LONGINT);
  BEGIN (*emit branch instruction*)
    target.code[target.pc] := ((target.opmap[op]+12) * 10H + cond) * 1000000H + (off MOD 1000000H); INC(target.pc)
  END Put3;  PROCEDURE SetArch*(VAR target: O7X.Target);
  BEGIN
    target.arch := 0X;    target.opmap[Mov] := 0; target.opmap[Lsl] := 1; target.opmap[Asr] := 2; target.opmap[Ror] := 3; target.opmap[And] := 4;     target.opmap[Ann] := 5; target.opmap[Ior] := 6; target.opmap[Xor] := 7; target.opmap[Add] := 8; target.opmap[Sub] := 9;     target.opmap[Mul] := 10; target.opmap[Div] := 11; target.opmap[Fad] := 12; target.opmap[Fsb] := 13; target.opmap[Fml] := 14;     target.opmap[Fdv] := 15;    target.relmap[0] := 1; target.relmap[1] := 9; target.relmap[2] := 5; target.relmap[3] := 6; target.relmap[4] := 14; target.relmap[5] := 13;     target.Put0 := Put0;    target.Put1 := Put1;    target.Put1a := Put1a;    target.Put2 := Put2;    target.Put3 := Put3;  END SetArch;
BEGIN
END Or32G.
