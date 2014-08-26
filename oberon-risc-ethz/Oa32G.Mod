MODULE Oa32G; (* NW  10.10.2013 CP 19.8.2014 RISC code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, O7X;
  (*Code generator for Oberon compiler for ARM 32-bit processor.
     Procedural interface to Parser O7P; result in array "code".
     Procedure Close writes code-files*)  CONST    StkOrg0 = -64; VarOrg0 = 0;  		(* Register Numbers *)    MT = 27; SB = 28; SP = 29; LNK = 30; PC* = 31;   (*dedicated registers*)
  (*  MT = 11; LNK = 14; PC* = 15; LR* = 14; SP* = 13; SB* = 12; FirstUniversalReg = 10; *)
  (*  MT = 12; SB = 13; SP = 14; LNK = 15; *)  (*dedicated registers*)

  (*frequently used opcodes -- abstract not machine values except for risc*)      U = 2000H;
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3;    And = 4; Ann = 5; Ior = 6; Xor = 7;
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11;
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15;
    Ldr = 0; Ldrb = 1; Str = 2; Strb = 3; 
    BR = 0; BLR = 1; BC = 2; BL = 3;

 

 (*   MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14; *)  (*opcode formats*)   DPfmt = 0; MULfmt = 1; MULLfmt = 2; SDSfmt = 3; BEfmt = 4; HDTRfmt = 5; HDTIfmt = 6;   SDTfmt = 7; UNDfmt = 8; BDTfmt = 9; BRfmt = 10; CDTfmt = 11; CDOfmt = 12; CRTfmt = 13; SWIfmt = 14;
		(* Conditions *)		EQ* = 0; NE* = 1; CS* = 2; CC* = 3;  MI* = 4; PL* = 5; VS* = 6; VC* = 7;		HI* = 8; LS* = 9; GE* = 10; LT* = 11;  GT* = 12; LE* = 13; AL* = 14; NV* = 15;  (*instruction disassemblers according to formats*)
  PROCEDURE opFormat*(w: LONGINT): LONGINT;		VAR fmt,cc, a, b, f: LONGINT; 	BEGIN        cc := w DIV 10000000H;        a  := w DIV 1000000H MOD 10H;        b  := w DIV 100000H MOD 10H;        f   := w DIV 10H MOD 10H;		        IF  (( a = 0 ) OR ( a = 1 ) OR ( a = 2 ) OR ( a = 3 )) THEN          IF (f = 9) & (a = 0) THEN (*mul / mull *)            IF ODD(b DIV 8) THEN fmt := MULLfmt	ELSE fmt := MULfmt END          ELSIF (f>9) & ODD(f) & (a<2) THEN (* ldrh/strh *)            IF ~ODD(b DIV 4) THEN fmt := HDTRfmt ELSE fmt := HDTIfmt END          ELSIF (f = 9) & (a=1) THEN (*single swap *)            fmt := SDSfmt          ELSIF (a = 1) & ((b = 2) OR (b = 6) OR (b = 0) OR (b = 4)) OR (a = 3)&((b = 2) OR (b = 6)) THEN(* msr /mrs *)            fmt :=  -1          ELSE            IF (b DIV 2 + a*8 MOD 10H = 0DH) OR (b DIV 2 + a*8 MOD 10H = 0FH) THEN (* Mov, Mvn*)              fmt := DPfmt            ELSIF (b DIV 2 + a*8 MOD 10H >= 8H) & (b DIV 2 + a*8 MOD 10H <=  0BH) THEN (* cmp, tst*)              fmt := DPfmt            ELSE               fmt := DPfmt            END;            IF ODD(a DIV 2) THEN (* Immidiate Data processing *)              fmt := DPfmt            ELSE (* Data processing *)              fmt :=  DPfmt            END          END        ELSIF ((a=4) OR (a=5) OR (a=6) OR (a=7)) THEN (* ldf, str *)          IF (a >= 6) & ODD(f) THEN 	(* undef *)            fmt := UNDfmt          ELSE	(*ldr, str *)            fmt := SDTfmt          END        ELSIF ((a=8) OR (a=9)) THEN (* ldm, stm *) fmt := BDTfmt        ELSIF a=0AH THEN (* Branch *) fmt := BRfmt        ELSIF a=0BH THEN (* Branch and Link *) fmt := BRfmt        ELSIF a=0CH THEN (* FP Push/Pop *) fmt := CDTfmt        ELSIF a=0DH THEN (* FP Ldc / Stc *) fmt := CDTfmt        ELSIF a=0EH THEN (* FP Operation *) fmt := CDOfmt        ELSIF a=0FH THEN (* SWI *) fmt := SWIfmt        END        RETURN fmt
  END opFormat;  PROCEDURE PutOpRRR(target: O7X.Target; u, op, a, b, c: LONGINT);
  BEGIN (*emit format-0 instruction*)
    IF u = 0 THEN      IF  (c >= -100H) & (c <= 0FFH) THEN        target.code[target.pc] := (AL * 10000000H) + (target.opRRmap[op]*200000H) + (b * 10000H) + (a * 1000H) + c       ELSE         O7S.Mark("PutOpRRR c overflow")      END;
    ELSE
      O7S.Mark("PutOpRRR u flag not handled")    END;    INC(target.pc)
  END PutOpRRR;
  PROCEDURE PutOpRRI(target: O7X.Target; u, op, a, b, im: LONGINT);
  BEGIN (*emit format-1 instruction,  -10000H <= im < 10000H*)    IF u = 0 THEN      IF (im >= -100H) & (im <= 0FFH) THEN        target.code[target.pc] := (AL * 10000000H) + 2000000H + (target.opRRmap[op]*200000H) + (b * 10000H) + (a * 1000H) + im      ELSE         target.code[target.pc] := (AL * 10000000H) + 2000000H + (target.opRRmap[op]*200000H) + (b * 10000H) + (a * 1000H) + 0BFH(*        O7S.Mark("PutOpRRI im overflow")*)       END    ELSE        target.code[target.pc] := (AL * 10000000H) + 2000000H + (target.opRRmap[op]*200000H) + (b * 10000H) + (a * 1000H) + 0BEH(*
      O7S.Mark("PutOpRRR u flag not handled")*)    END;    INC(target.pc)
  END PutOpRRI;

  PROCEDURE PutOpRRIa(target: O7X.Target; op, a, b, im: LONGINT);
  BEGIN (*same as Pu1, but with range test  -10000H <= im < 10000H*)
    IF (im >= -100H) & (im <= 0FFH) THEN PutOpRRI(target, 0, op, a, b, im)
    ELSE PutOpRRI(target, U, Mov, target.RH, 0, im DIV 100H);
      IF im MOD 100H # 0 THEN PutOpRRI(target, 0, target.opRRmap[Ior], target.RH, target.RH, im MOD 100H) END ;
      PutOpRRR(target, 0, target.opRRmap[op], a, b, target.RH)
    END
  END PutOpRRIa;


  PROCEDURE PutOpLS(target: O7X.Target; op, a, b, off: LONGINT);
  BEGIN (*emit load/store instruction*) 
    IF (off >= -1000H) & (off <= 0FFFH) THEN      IF ((op = Ldr) OR (op = Str)) THEN        IF off < 0 THEN          target.code[target.pc] := (AL * 10000000H) + (target.opLSmap[op] * 100000H) + (b *  10000H) + (a * 1000H) + (0- off )        ELSE          target.code[target.pc] := (AL * 10000000H) + (target.opLSmap[op] * 100000H) + 800000H + (b *  10000H) + (a * 1000H) + off        END      ELSE        O7S.Mark("load/store was not load or store")      END    ELSE      O7S.Mark("offset in ARM opcode too large")    END;    INC(target.pc)
  END PutOpLS;

  PROCEDURE PutOpBRR(target: O7X.Target; op, cond, imm, a: LONGINT);
  BEGIN (*emit branch instruction*)    IF op = BR THEN      IF cond = AL THEN         PutOpRRR(target,0,Mov,PC,0,LNK);         DEC(target.pc)      ELSE        target.code[target.pc] := 0E0000000H;      END    ELSIF op = BLR THEN     target.code[target.pc] := 0E0000001H;    ELSIF op = BC THEN     target.code[target.pc] := 0E0000002H;    ELSIF op = BL THEN     target.code[target.pc] := 0E0000003H;    ELSE      O7S.Mark("unknown branch opcode")    END;    INC(target.pc)
  END PutOpBRR;

  PROCEDURE PutOpBRI(target: O7X.Target; op, cond, off: LONGINT);
  BEGIN (*emit branch instruction*)    IF op = BR THEN      IF cond = AL THEN         PutOpRRR(target,0,Mov,PC,0,LNK);         DEC(target.pc)      ELSE        target.code[target.pc] := 0E0000000H;      END    ELSIF op = BLR THEN     target.code[target.pc] := 0E0000001H;    ELSIF op = BC THEN     target.code[target.pc] := 0E0000002H;    ELSIF op = BL THEN     target.code[target.pc] := 0E0000003H;    ELSE      O7S.Mark("unknown branch opcode")    END;    INC(target.pc)
  END PutOpBRI;

 
  PROCEDURE NofPtrs(typ: O7B.Type): LONGINT;
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
    O7B.MakeFileName(name, modid, ".a32"); (*write code file*)
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
    Files.WriteInt(R, target.varsize - target.tdx*4);  (*data*)    Files.WriteInt(R, target.strx);    FOR i := 0 TO target.strx-1 DO Files.Write(R, target.str[i]) END ;  (*strings*)    Files.WriteInt(R, target.pc);  (*code len*)    FOR i := 0 TO target.pc-1 DO Files.WriteInt(R, target.code[i]) END ;  (*program*)    obj := O7B.topScope.next;    WHILE obj # NIL DO  (*commands*)      IF (obj.exno # 0) & (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) &          (obj.type.nofpar = 0) & (obj.type.base = O7B.noType) THEN        Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val)      END ;      obj := obj.next    END ;    Files.Write(R, 0X);    Files.WriteInt(R, nofent); Files.WriteInt(R, target.entry);    obj := O7B.topScope.next;    WHILE obj # NIL DO  (*entries*)      IF obj.exno # 0 THEN        IF (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) OR (obj.class = O7B.Var) THEN          Files.WriteInt(R, obj.val)        ELSIF obj.class = O7B.Typ THEN          IF obj.type.form = O7B.Record THEN Files.WriteInt(R,  obj.type.len MOD 10000H)          ELSIF (obj.type.form = O7B.Pointer) & ((obj.type.base.typobj = NIL) OR (obj.type.base.typobj.exno = 0)) THEN            Files.WriteInt(R, obj.type.base.len MOD 10000H)          END        END      END;      obj := obj.next    END ;    obj := O7B.topScope.next;    WHILE obj # NIL DO  (*pointer variables*)      IF obj.class = O7B.Var THEN FindPtrs(R, obj.type, obj.val) END ;      obj := obj.next    END ;    Files.WriteInt(R, -1);    Files.WriteInt(R, target.fixorgP); Files.WriteInt(R, target.fixorgD); Files.WriteInt(R, target.fixorgT); Files.WriteInt(R, target.entry);    Files.Write(R, "O"); Files.Register(F)  END Close;  PROCEDURE SetArch*(VAR target: O7X.Target);  VAR i : INTEGER;  BEGIN    target.arch := 0X;
    target.RX := 11;    i:= 0; WHILE i < 11 DO target.regmap[i] := i; INC(i) END;  (* identity map RISC lower registers *)
    i:= 11; WHILE i < 27 DO target.regmap[i] := -1; INC(i) END;  (* unavailable registers *)
    i:= 27; WHILE i < 32 DO target.regmap[i] := i-16; INC(i) END;  (* MT SB SP LNK PC*)
    target.opRRmap[Mov] := 13; target.opRRmap[Lsl] := -1; target.opRRmap[Asr] := -1; target.opRRmap[Ror] := -1;    target.opRRmap[And] := 0; target.opRRmap[Ann] := -1; target.opRRmap[Ior] := -1; target.opRRmap[Xor] := -1;    target.opRRmap[Add] := 4; target.opRRmap[Sub] := 2; target.opRRmap[Mul] := -1; target.opRRmap[Div] := -1;     target.opRRmap[Fad] := -1; target.opRRmap[Fsb] := -1; target.opRRmap[Fml] := -1;  target.opRRmap[Fdv] := -1;    target.opLSmap[Ldr] := 8; target.opLSmap[Str] := 10; target.opLSmap[Ldrb] := 9; target.opLSmap[Strb] := 11;     target.opBRmap[BR] := 0; target.opBRmap[BLR] := 1; target.opBRmap[BC] := 2; target.opBRmap[BL] := 3;    target.relmap[0] := 1; target.relmap[1] := 9; target.relmap[2] := 5; target.relmap[3] := 6; target.relmap[4] := 14; target.relmap[5] := 13;     target.PutOpRRR := PutOpRRR;    target.PutOpRRI := PutOpRRI;    target.PutOpRRIa := PutOpRRIa;    target.PutOpLS := PutOpLS;    target.PutOpBRR := PutOpBRR;    target.PutOpBRI := PutOpBRI;    target.Close := Close;  END SetArch;BEGINEND Oa32G.