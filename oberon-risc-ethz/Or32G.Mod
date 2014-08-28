MODULE Or32G; (* NW  10.10.2013 CP 19.8.2014 RISC code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, O7X;
  (*Code generator for Oberon compiler for RISC processor.
     Procedural interface to Parser O7P; result in array "code".
     Procedure Close writes code-files*)  CONST
    MT = 27; SB = 28; SP = 29; LNK = 30; PC* = 31;   (*dedicated registers*)
  (*  MT = 12; SB = 13; SP = 14; LNK = 15; *)  (*dedicated registers*)
  (*frequently used opcodes -- abstract not machine values except for risc*)      U = 2000H;
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3;    And = 4; Ann = 5; Ior = 6; Xor = 7;
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11;
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15;
    Ldr = 0; Ldrb = 1; Str = 2; Strb = 3; 
    BR = 0; BLR = 1; BC = 2; BL = 3;

    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14; AL = 7;  PROCEDURE PutOpRRR(target: O7X.Target; u, op, a, b, c: LONGINT);
  BEGIN (*emit format-0 instruction*)
    target.code[target.pc] := ((target.regmap[a]*10H + target.regmap[b]) * 10H + (target.opRRmap[op]+u)) * 10000H + target.regmap[c]; INC(target.pc)
  END PutOpRRR;
  PROCEDURE PutOpRRI(target: O7X.Target; u, op, a, b, im: LONGINT);  VAR v : INTEGER;
  BEGIN (*emit format-1 instruction,  -10000H <= im < 10000H*)  (*  IF op > 15 THEN op := op MOD 16; u := U END; *)    v := 0; IF im < 0 THEN v:= 1000H END ;  (*set v-bit*)    target.code[target.pc] := (((target.regmap[a]+40H) * 10H + target.regmap[b]) * 10H + (target.opRRmap[op]+u+v )) * 10000H + (im MOD 10000H); INC(target.pc)
  END PutOpRRI;

  PROCEDURE PutOpRRIa(target: O7X.Target; op, a, b, im: LONGINT);
  BEGIN (*same as Pu1, but with range test  -10000H <= im < 10000H*)
    IF (im >= -10000H) & (im <= 0FFFFH) THEN PutOpRRI(target, 0, op, a, b, im)
    ELSE PutOpRRI(target, U, Mov, target.RH, 0, im DIV 10000H);
      IF im MOD 10000H # 0 THEN PutOpRRI(target, 0, target.opRRmap[Ior], target.RH, target.RH, im MOD 10000H) END ;
      PutOpRRR(target, 0, op, a, b, target.RH)
    END
  END PutOpRRIa;

  PROCEDURE PutOpLS(target: O7X.Target; op, a, b, off: LONGINT);
  BEGIN (*emit load/store instruction*)
    target.code[target.pc] := ((target.opLSmap[op] * 10H + target.regmap[a]) * 10H + target.regmap[b]) * 100000H + (off MOD 100000H); INC(target.pc)
  END PutOpLS;  PROCEDURE PutOpBRR(target: O7X.Target; op, cond, imm, a: LONGINT);
  BEGIN (*emit branch instruction*)
    target.code[target.pc] := ((target.opBRmap[op]+12) * 10H + cond) * 1000000H + imm + (target.regmap[a] MOD 10H); INC(target.pc)
  END PutOpBRR;  PROCEDURE PutOpBRI(target: O7X.Target; op, cond, off: LONGINT);
  BEGIN (*emit branch instruction*)
    target.code[target.pc] := ((target.opBRmap[op]+12) * 10H + cond) * 1000000H + (off MOD 1000000H); INC(target.pc)
  END PutOpBRI;  PROCEDURE NofPtrs(typ: O7B.Type): LONGINT;
    VAR fld: O7B.Object; n: LONGINT;
  BEGIN
    IF (typ.form = O7B.Pointer) OR (typ.form = O7B.NilTyp) THEN n := 1
    ELSIF typ.form = O7B.Record THEN
      fld := typ.dsc; n := 0;
      WHILE fld # NIL DO n := NofPtrs(fld.type) + n; fld := fld.next END
    ELSIF typ.form = O7B.Array THEN n := NofPtrs(typ.base) * typ.len
    ELSE n := 0
    END ;
    RETURN n
  END NofPtrs;

  PROCEDURE FindPtrs(VAR R: Files.Rider; typ: O7B.Type; adr: LONGINT);
    VAR fld: O7B.Object; i, s: LONGINT;
  BEGIN
    IF (typ.form = O7B.Pointer) OR (typ.form = O7B.NilTyp) THEN Files.WriteInt(R, adr)
    ELSIF typ.form = O7B.Record THEN
      fld := typ.dsc;
      WHILE fld # NIL DO FindPtrs(R, fld.type, fld.val + adr); fld := fld.next END
    ELSIF typ.form = O7B.Array THEN
      s := typ.base.size;
      FOR i := 0 TO typ.len-1 DO FindPtrs(R, typ.base, i*s + adr) END
    END
  END FindPtrs;  PROCEDURE Close (VAR target: O7X.Target; modid: O7S.Ident; key, nofent: LONGINT);
    VAR obj: O7B.Object;
      i, comsize, nofimps, nofptrs, size: LONGINT;
      name: O7S.Ident;
      F: Files.File; R: Files.Rider;
  BEGIN  (*exit code*)
    IF target.version = 0 THEN target.PutOpRRI(target, 0, Mov, 0, 0, 0); target.PutOpBRI(target, BR, AL, 0)  (*RISC-0*)
    ELSE target.PutOpLS(target, Ldr, LNK, SP, 0); target.PutOpRRI(target, 0, Add, SP, SP, 4); target.PutOpBRR(target, BR, AL, 0, LNK)
    END ;
    obj := O7B.topScope.next; nofimps := 0; comsize := 4; nofptrs := 0;
    WHILE obj # NIL DO
      IF (obj.class = O7B.Mod) & (obj.dsc # O7B.system) THEN INC(nofimps) (*count imports*)
      ELSIF (obj.exno # 0) & (obj.class = O7B.Const) & (obj.type.form = O7B.Proc)
          & (obj.type.nofpar = 0) & (obj.type.base = O7B.noType) THEN i := 0; (*count commands*)
        WHILE obj.name[i] # 0X DO INC(i) END ;
        i := (i+4) DIV 4 * 4; INC(comsize, i+4)
      ELSIF obj.class = O7B.Var THEN INC(nofptrs, NofPtrs(obj.type))  (*count pointers*)
      END ;
      obj := obj.next
    END ;
    size := target.varsize + target.strx + comsize + (target.pc + nofimps + nofent + nofptrs + 1)*4;  (*varsize includes type descriptors*)
    O7B.MakeFileName(name, modid, ".r32"); (*write code file*)
    F := Files.New(name); Files.Set(R, F, 0); Files.WriteString(R, modid); Files.WriteInt(R, key); Files.WriteByte(R, target.version);
    Files.WriteInt(R, size);
    obj := O7B.topScope.next;
    WHILE (obj # NIL) & (obj.class = O7B.Mod) DO  (*imports*)
      IF obj.dsc # O7B.system THEN Files.WriteString(R, obj(O7B.Module).orgname); Files.WriteInt(R, obj.val) END ;
      obj := obj.next
    END ;
    Files.Write(R, 0X);
    Files.WriteInt(R, target.tdx*4);
    i := 0;
    WHILE i < target.tdx DO Files.WriteInt(R, target.data[i]); INC(i) END ; (*type descriptors*)
    Files.WriteInt(R, target.varsize - target.tdx*4);  (*data*)
    Files.WriteInt(R, target.strx);
    FOR i := 0 TO target.strx-1 DO Files.Write(R, target.str[i]) END ;  (*strings*)
    Files.WriteInt(R, target.pc);  (*code len*)
    FOR i := 0 TO target.pc-1 DO Files.WriteInt(R, target.code[i]) END ;  (*program*)
    obj := O7B.topScope.next;
    WHILE obj # NIL DO  (*commands*)
      IF (obj.exno # 0) & (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) &
          (obj.type.nofpar = 0) & (obj.type.base = O7B.noType) THEN
        Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val)
      END ;
      obj := obj.next
    END ;
    Files.Write(R, 0X);
    Files.WriteInt(R, nofent); Files.WriteInt(R, target.entry);
    obj := O7B.topScope.next;
    WHILE obj # NIL DO  (*entries*)
      IF obj.exno # 0 THEN
        IF (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) OR (obj.class = O7B.Var) THEN
          Files.WriteInt(R, obj.val)
        ELSIF obj.class = O7B.Typ THEN
          IF obj.type.form = O7B.Record THEN Files.WriteInt(R,  obj.type.len MOD 10000H)
          ELSIF (obj.type.form = O7B.Pointer) & ((obj.type.base.typobj = NIL) OR (obj.type.base.typobj.exno = 0)) THEN
            Files.WriteInt(R, obj.type.base.len MOD 10000H)
          END
        END
      END;
      obj := obj.next
    END ;
    obj := O7B.topScope.next;
    WHILE obj # NIL DO  (*pointer variables*)
      IF obj.class = O7B.Var THEN FindPtrs(R, obj.type, obj.val) END ;
      obj := obj.next
    END ;
    Files.WriteInt(R, -1);
    Files.WriteInt(R, target.fixorgP); Files.WriteInt(R, target.fixorgD); Files.WriteInt(R, target.fixorgT); Files.WriteInt(R, target.entry);
    Files.Write(R, "O"); Files.Register(F)
  END Close;
  PROCEDURE SetArch*(VAR target: O7X.Target);
  VAR i : INTEGER;  BEGIN    target.arch := 0X;
    target.WordSize := 4;
    target.RX := 12;
    i:= 0; WHILE i < 12 DO target.regmap[i] := i; INC(i) END;  (* identity map RISC lower registers *)
    i:= 12; WHILE i < 28 DO target.regmap[i] := -1; INC(i) END;  (* unavailable registers *)
    i:= 27; WHILE i < 32 DO target.regmap[i] := i-15; INC(i) END;  (* MT SB SP LNK, no PC in lower 16 registers*)
    i:= 0; WHILE i < 16 DO target.opRRmap[i] := i; INC(i) END;  (* identity map RISC opcodes in opcode map *)    target.opLSmap[Ldr] := 8; target.opLSmap[Str] := 10; target.opLSmap[Ldrb] := 9; target.opLSmap[Strb] := 11;     target.opBRmap[BR] := 0; target.opBRmap[BLR] := 1; target.opBRmap[BC] := 2; target.opBRmap[BL] := 3;    target.relmap[0] := 1; target.relmap[1] := 9; target.relmap[2] := 5; target.relmap[3] := 6; target.relmap[4] := 14; target.relmap[5] := 13;     target.PutOpRRR := PutOpRRR;    target.PutOpRRI := PutOpRRI;    target.PutOpRRIa := PutOpRRIa;    target.PutOpLS := PutOpLS;    target.PutOpBRR := PutOpBRR;    target.PutOpBRI := PutOpBRI;    target.Close := Close;  END SetArch;
BEGIN
END Or32G.
