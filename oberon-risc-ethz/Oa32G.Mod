MODULE Oa32G; (* NW  10.10.2013 CP 19.8.2014 RISC code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, O7X;
  (*Code generator for Oberon compiler for ARM 32-bit processor.
     Procedural interface to Parser O7P; result in array "code".
     Procedure Close writes code-files*)  CONST    StkOrg0 = 8192; VarOrg0 = 8000H;  RaspberryKernelLoad = 8000H;		(* Register Numbers *)    MT = 27; SB = 28; SP = 29; LNK = 30; PC* = 31;   (*dedicated registers*)
  (*  MT = 11; LNK = 14; PC* = 15; LR* = 14; SP* = 13; SB* = 12; FirstUniversalReg = 10; *)
  (*  MT = 12; SB = 13; SP = 14; LNK = 15; *)  (*dedicated registers*)

  (*frequently used opcodes -- abstract not machine values except for risc*)      U = 2000H; C24 = 1000000H; 
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3;    And = 4; Ann = 5; Ior = 6; Xor = 7;
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11;
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15;
    Ldr = 0; Ldrb = 1; Str = 2; Strb = 3; 
    BR = 0; BLR = 1; BC = 2; BL = 3;

 

    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14; AL = 7;  (*opcode formats*)   DPfmt = 0; MULfmt = 1; MULLfmt = 2; SDSfmt = 3; BEfmt = 4; HDTRfmt = 5; HDTIfmt = 6;   SDTfmt = 7; UNDfmt = 8; BDTfmt = 9; BRfmt = 10; CDTfmt = 11; CDOfmt = 12; CRTfmt = 13; SWIfmt = 14;
		(* Conditions *)
(*		EQ* = 0; NE* = 1; CS* = 2; CC* = 3;  MI* = 4; PL* = 5; VS* = 6; VC* = 7;		HI* = 8; LS* = 9; GE* = 10; LT* = 11;  GT* = 12; LE* = 13; AL* = 14; NV* = 15;
*)  (*instruction disassemblers according to formats*)
  PROCEDURE opFormat*(w: LONGINT): LONGINT;		VAR fmt,cc, a, b, f: LONGINT; 	BEGIN        cc := w DIV 10000000H;        a  := w DIV 1000000H MOD 10H;        b  := w DIV 100000H MOD 10H;        f   := w DIV 10H MOD 10H;		        IF  (( a = 0 ) OR ( a = 1 ) OR ( a = 2 ) OR ( a = 3 )) THEN          IF (f = 9) & (a = 0) THEN (*mul / mull *)            IF ODD(b DIV 8) THEN fmt := MULLfmt	ELSE fmt := MULfmt END          ELSIF (f>9) & ODD(f) & (a<2) THEN (* ldrh/strh *)            IF ~ODD(b DIV 4) THEN fmt := HDTRfmt ELSE fmt := HDTIfmt END          ELSIF (f = 9) & (a=1) THEN (*single swap *)            fmt := SDSfmt          ELSIF (a = 1) & ((b = 2) OR (b = 6) OR (b = 0) OR (b = 4)) OR (a = 3)&((b = 2) OR (b = 6)) THEN(* msr /mrs *)            fmt :=  -1          ELSE            IF (b DIV 2 + a*8 MOD 10H = 0DH) OR (b DIV 2 + a*8 MOD 10H = 0FH) THEN (* Mov, Mvn*)              fmt := DPfmt            ELSIF (b DIV 2 + a*8 MOD 10H >= 8H) & (b DIV 2 + a*8 MOD 10H <=  0BH) THEN (* cmp, tst*)              fmt := DPfmt            ELSE               fmt := DPfmt            END;            IF ODD(a DIV 2) THEN (* Immidiate Data processing *)              fmt := DPfmt            ELSE (* Data processing *)              fmt :=  DPfmt            END          END        ELSIF ((a=4) OR (a=5) OR (a=6) OR (a=7)) THEN (* ldf, str *)          IF (a >= 6) & ODD(f) THEN 	(* undef *)            fmt := UNDfmt          ELSE	(*ldr, str *)            fmt := SDTfmt          END        ELSIF ((a=8) OR (a=9)) THEN (* ldm, stm *) fmt := BDTfmt        ELSIF a=0AH THEN (* Branch *) fmt := BRfmt        ELSIF a=0BH THEN (* Branch and Link *) fmt := BRfmt        ELSIF a=0CH THEN (* FP Push/Pop *) fmt := CDTfmt        ELSIF a=0DH THEN (* FP Ldc / Stc *) fmt := CDTfmt        ELSIF a=0EH THEN (* FP Operation *) fmt := CDOfmt        ELSIF a=0FH THEN (* SWI *) fmt := SWIfmt        END        RETURN fmt
  END opFormat;  PROCEDURE PutOpRRR(target: O7X.Target; u, op, a, b, c: LONGINT);
  BEGIN (*emit format-0 instruction*)
    IF u = 0 THEN      IF  (c >= -100H) & (c <= 0FFH) THEN        target.code[target.pc] := (target.condmap[AL] * 10000000H) + (target.opRRmap[op]*200000H) + 
        (target.regmap[b] * 10000H) + (target.regmap[a] * 1000H) + target.regmap[c]       ELSE         O7S.Mark("PutOpRRR c overflow")      END;
    ELSE
      O7S.Mark("PutOpRRR u flag not handled")    END;    INC(target.pc)
  END PutOpRRR;
  PROCEDURE PutOpRRI(target: O7X.Target; u, op, a, b, im: LONGINT);
  BEGIN (*emit format-1 instruction*)   IF op > -1 THEN IF op < 16  THEN    IF u = 0 THEN      IF (im >= -100H) & (im <= 0FFH) THEN        target.code[target.pc] := (target.condmap[AL] * 10000000H) + 2000000H + (target.opRRmap[op]*200000H) + 
        (target.regmap[b] * 10000H) + (target.regmap[a] * 1000H) + im      ELSE         O7S.Mark("PutOpRRI im overflow")       END    ELSE        target.code[target.pc] := (target.condmap[AL] * 10000000H) + 2000000H + (target.opRRmap[op]*200000H) + 
        (target.regmap[b] * 10000H) + (target.regmap[a] * 1000H) + (0CH * 100H) + im    END;
   ELSE
      O7S.Mark("PutOpRRR op out of range")   END END;   INC(target.pc)
  END PutOpRRI;

  PROCEDURE PutOpRRIa(target: O7X.Target; op, a, b, im: LONGINT);
  BEGIN (*same as Pu1, but with range test  -100H <= im < 100H*)
    IF (im >= -100H) & (im <= 0FFH) THEN PutOpRRI(target, 0, op, a, b, im)
    ELSE PutOpRRI(target, U, Mov, target.RH, 0, im DIV 100H);
      IF im MOD 100H # 0 THEN PutOpRRI(target, 0, Ior, target.RH, target.RH, im MOD 100H) END ;
      PutOpRRR(target, 0, op, a, b, target.RH)
    END
  END PutOpRRIa;


  PROCEDURE PutOpLS(target: O7X.Target; op, a, b, off: LONGINT);
  BEGIN (*emit load/store instruction*) 
    IF (off >= -1000H) & (off <= 0FFFH) THEN      IF ((op = Ldr) OR (op = Str)) THEN        IF off < 0 THEN          target.code[target.pc] := (target.condmap[AL] * 10000000H) + (target.opLSmap[op] * 100000H) + (target.regmap[b] *  10000H) + (target.regmap[a] * 1000H) + (0- off )        ELSE          target.code[target.pc] := (target.condmap[AL] * 10000000H) + (target.opLSmap[op] * 100000H) + 800000H + (target.regmap[b] *  10000H) + (target.regmap[a] * 1000H) + off        END      ELSE        O7S.Mark("load/store was not load or store")      END    ELSE      O7S.Mark("offset in ARM opcode too large")    END;    INC(target.pc)
  END PutOpLS;

  PROCEDURE PutOpBRR(target: O7X.Target; op, cond, imm, a: LONGINT);
  BEGIN (*emit branch instruction*)    IF op = BR THEN      IF  target.condmap[cond] > -1 THEN        target.code[target.pc] := (target.condmap[cond] * 10000000H) + (target.opRRmap[Mov]*200000H) + (target.regmap[0] * 10000H) + (target.regmap[PC] * 1000H) + target.regmap[LNK]       ELSE (*        O7S.Mark("PutOpBRR unknown condition"); *)        IF cond = 0 THEN O7S.Mark("cond = 0") END;        IF cond = 1 THEN O7S.Mark("cond = 1") END;        IF cond = 2 THEN O7S.Mark("cond = 2") END;        IF cond = 3 THEN O7S.Mark("cond = 3") END;        IF cond = 4 THEN O7S.Mark("cond = 4") END;        IF cond = 5 THEN O7S.Mark("cond = 5") END;        IF cond = 6 THEN O7S.Mark("cond = 6") END;        IF cond = 7 THEN O7S.Mark("cond = 7") END;        IF cond = 8 THEN O7S.Mark("cond = 8") END;        IF cond = 9 THEN O7S.Mark("cond = 9") END;        IF cond = 10 THEN O7S.Mark("cond = 10") END;        IF cond = 11 THEN O7S.Mark("cond = 11") END;        IF cond = 12 THEN O7S.Mark("cond = 12") END;        IF cond = 13 THEN O7S.Mark("cond = 13") END;        IF cond = 14 THEN O7S.Mark("cond = 14") END;        IF cond = 15 THEN O7S.Mark("cond = 15") END      END
    ELSIF op = BLR THEN     target.code[target.pc] := 0E0000001H;    ELSIF op = BC THEN     target.code[target.pc] := 0E0000002H;    ELSIF op = BL THEN     target.code[target.pc] := 0E0000003H;    ELSE      O7S.Mark("unknown branch opcode")    END;    INC(target.pc)
  END PutOpBRR;

  PROCEDURE PutOpBRI(target: O7X.Target; op, cond, off: LONGINT);
  BEGIN (*emit branch instruction*)    IF op = BR THEN      IF cond = AL THEN         PutOpRRR(target,0,Mov,PC,0,LNK);         DEC(target.pc)      ELSE        target.code[target.pc] := 0E0000000H;      END    ELSIF op = BLR THEN     target.code[target.pc] := 0E0000001H;    ELSIF op = BC THEN     target.code[target.pc] := (target.condmap[cond] * 10000000H) + (0AH * 1000000H) + (off - 2 );    ELSIF op = BL THEN     target.code[target.pc] := (target.condmap[cond] * 10000000H) + (0BH * 1000000H) + (off - 2 );    ELSE      O7S.Mark("unknown branch opcode")    END;    INC(target.pc)
  END PutOpBRI;

  PROCEDURE fix*(target: O7X.Target; at, with: LONGINT); 
  BEGIN target.code[at] := target.code[at] DIV C24 * C24 + (with MOD C24) 
  END fix; 
 
  PROCEDURE FixLink*(target: O7X.Target; L: LONGINT); 
    VAR L1: LONGINT; 
  BEGIN target.invalSB(target); 
    WHILE L # 0 DO
    IF L > -1 THEN
      IF L < O7X.maxCode THEN
(*        L1 := target.code[L] MOD 40000H; fix(target, L, target.pc-L-target.pcl); L := L1 *)
        L1 := target.code[L] MOD 1000H; fix(target, L, target.pc-L-target.pcl); L := L1 
      ELSE
        O7S.Mark("FixLink offset beyond code space");
        L:=0      END
    ELSE
      O7S.Mark("FixLink offset is negative");
      L:=0    END
    END
  END FixLink; 
 
  PROCEDURE FixLinkWith*(target: O7X.Target; L0, dst: LONGINT); 
    VAR L1: LONGINT; 
  BEGIN 
    WHILE L0 # 0 DO 
      L1 := target.code[L0] MOD C24; 
      target.code[L0] := target.code[L0] DIV C24 * C24 + ((dst - L0 - 1) MOD C24); L0 := L1 
    END 
  END FixLinkWith; 
 
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
  END FindPtrs;  PROCEDURE invalSB(VAR target: O7X.Target); 
  BEGIN target.curSB := 1 
  END invalSB; 
  PROCEDURE Open*(VAR target: O7X.Target; v: INTEGER); 
  BEGIN target.pc := 0; target.tdx := 0; target.strx := 0; target.RH := 0; target.fixorgP := 0; target.fixorgD := 0; target.fixorgT := 0; 
    target.check := v # 0; target.version := v; target.inhibitCalls := FALSE; 
    IF v = 0 THEN target.pc := 9 END 
  END Open; 
 
  PROCEDURE Header*(VAR target: O7X.Target); 
  BEGIN target.entry := target.pc*4; 
    IF target.version = 0 THEN 
      target.code[0] := 0EA000000H -2 + target.pc; 
      target.PutOpRRIa(target, Mov, SB, 0, 16); 
      target.PutOpRRIa(target, Mov, SP, 0, StkOrg0)  (*RISC-0*) 
    ELSE 
      target.PutOpRRIa(target, Sub, SP, SP, 4); 
      target.PutOpLS(target, Str, LNK, SP, 0); 
      target.invalSB(target) 
    END 
  END Header;

  PROCEDURE Close (VAR target: O7X.Target; modid: O7S.Ident; key, nofent: LONGINT);
    VAR obj: O7B.Object;
      i, comsize, nofimps, nofptrs, size: LONGINT;
      name: O7S.Ident;
      F: Files.File; R: Files.Rider;
  BEGIN  (*exit code*)
    IF target.version = 0 THEN target.PutOpRRIa(target, Mov, 0, 0, 0); target.PutOpBRI(target, BR, AL, 0)  (*RISC-0*)
    ELSE target.PutOpLS(target, Ldr, LNK, SP, 0); target.PutOpRRIa(target, Add, SP, SP, 4); target.PutOpBRR(target, BR, AL, 0, LNK)
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
    Files.WriteInt(R, target.varsize - target.tdx*4);  (*data*)    Files.WriteInt(R, target.strx);    FOR i := 0 TO target.strx-1 DO Files.Write(R, target.str[i]) END ;  (*strings*)    Files.WriteInt(R, target.pc);  (*code len*)    FOR i := 0 TO target.pc-target.pcl DO Files.WriteInt(R, target.code[i]) END ;  (*program*)    obj := O7B.topScope.next;    WHILE obj # NIL DO  (*commands*)      IF (obj.exno # 0) & (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) &          (obj.type.nofpar = 0) & (obj.type.base = O7B.noType) THEN        Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val)      END ;      obj := obj.next    END ;    Files.Write(R, 0X);    Files.WriteInt(R, nofent); Files.WriteInt(R, target.entry);    obj := O7B.topScope.next;    WHILE obj # NIL DO  (*entries*)      IF obj.exno # 0 THEN        IF (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) OR (obj.class = O7B.Var) THEN          Files.WriteInt(R, obj.val)        ELSIF obj.class = O7B.Typ THEN          IF obj.type.form = O7B.Record THEN Files.WriteInt(R,  obj.type.len MOD 10000H)          ELSIF (obj.type.form = O7B.Pointer) & ((obj.type.base.typobj = NIL) OR (obj.type.base.typobj.exno = 0)) THEN            Files.WriteInt(R, obj.type.base.len MOD 10000H)          END        END      END;      obj := obj.next    END ;    obj := O7B.topScope.next;    WHILE obj # NIL DO  (*pointer variables*)      IF obj.class = O7B.Var THEN FindPtrs(R, obj.type, obj.val) END ;      obj := obj.next    END ;    Files.WriteInt(R, -1);    Files.WriteInt(R, target.fixorgP); Files.WriteInt(R, target.fixorgD); Files.WriteInt(R, target.fixorgT); Files.WriteInt(R, target.entry);    Files.Write(R, "O"); Files.Register(F)  END Close;  PROCEDURE SetArch*(VAR target: O7X.Target);  VAR i : INTEGER;  BEGIN    target.arch := 1X;
    target.pcl := 1;
    target.WordSize := 4;
    target.RX := 11;
(* ARM:
		EQ* = 0; NE* = 1; CS* = 2; CC* = 3;  MI* = 4; PL* = 5; VS* = 6; VC* = 7;		HI* = 8; LS* = 9; GE* = 10; LT* = 11;  GT* = 12; LE* = 13; AL* = 14; NV* = 15;   RISC:    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14; AL = 7; *)

(*
  a32mnemo0[0] := "and";
  a32mnemo0[1] := "eor";
  a32mnemo0[2] := "sub";
  a32mnemo0[3] := "rsb";
  a32mnemo0[4] := "add";
  a32mnemo0[5] := "adc";
  a32mnemo0[6] := "sbc";
  a32mnemo0[7] := "rsc";
  a32mnemo0[8] := "tst";
  a32mnemo0[9] := "teq";
  a32mnemo0[10] := "cmp";
  a32mnemo0[11] := "cmn";
  a32mnemo0[12] := "orr";
  a32mnemo0[13] := "mov";
  a32mnemo0[14] := "bic";
  a32mnemo0[15] := "mvn"; *)

    i:= 0; WHILE i < 16 DO target.condmap[i] := -1; INC(i) END;
    target.condmap[MI] := -1; target.condmap[PL] := 5; target.condmap[EQ] := 0; target.condmap[NE] := 1; target.condmap[LT] := 11;    target.condmap[GT] := 12; target.condmap[AL] := 14;    i:= 0; WHILE i < 11 DO target.regmap[i] := i; INC(i) END;  (* identity map RISC lower registers *)
    i:= 11; WHILE i < 27 DO target.regmap[i] := -1; INC(i) END;  (* unavailable registers *)
    i:= 27; WHILE i < 32 DO target.regmap[i] := i-16; INC(i) END;  (* MT SB SP LNK PC*)
    target.opRRmap[Mov] := 13; target.opRRmap[Lsl] := -1; target.opRRmap[Asr] := -1; target.opRRmap[Ror] := -1;    target.opRRmap[And] := 0; target.opRRmap[Ann] := -1; target.opRRmap[Ior] := 12; target.opRRmap[Xor] := 1;    target.opRRmap[Add] := 4; target.opRRmap[Sub] := 2; target.opRRmap[Mul] := -1; target.opRRmap[Div] := -1;     target.opRRmap[Fad] := -1; target.opRRmap[Fsb] := -1; target.opRRmap[Fml] := -1;  target.opRRmap[Fdv] := -1;    target.opLSmap[Ldr] := 51H; target.opLSmap[Str] := 50H; target.opLSmap[Ldrb] := 59H; target.opLSmap[Strb] := 58H;     target.opBRmap[BR] := 0; target.opBRmap[BLR] := 1; target.opBRmap[BC] := 2; target.opBRmap[BL] := 3;    target.relmap[0] := 1; target.relmap[1] := 9; target.relmap[2] := 5; target.relmap[3] := 6; 
    target.relmap[4] := 14; target.relmap[5] := 13;      target.PutOpRRR := PutOpRRR;    target.PutOpRRI := PutOpRRI;    target.PutOpRRIa := PutOpRRIa;    target.PutOpLS := PutOpLS;    target.PutOpBRR := PutOpBRR;    target.PutOpBRI := PutOpBRI;    target.fix := fix;    target.FixLink := FixLink;    target.FixLinkWith := FixLinkWith;    target.invalSB := invalSB;    target.Open := Open;    target.Header := Header;    target.Close := Close;  END SetArch;BEGINEND Oa32G.