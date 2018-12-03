MODULE Oa32G; (* NW  10.10.2013 CP 2014,2018 arm 32-bit code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, OXG;
  (*Code generator for Oberon compiler for arm 32-bit processor.
     Procedural interface to Parser O7P; result in array "code".
     Procedure Close writes code-files*)

  CONST WordSize* = 4;
		ObjMark = 0F5X; 
		CodeLength = 32768; (* 128K Code. Don't make it bigger (because of fixup list limits! *)
		ConstLength = 1024; (* in Words *)
		StrConstLength = 4096; (* in Bytes, ziemlich willkrlich, kann ruhig VIEL groesser sein *)
		MaxConstDist = ConstLength-15; (* in Words including a safety range *)
		MaxUnknownProcs = 128;
		MaxPtrs = 512; MaxRecs = 128; MaxComs = 40; MaxExts = 15;

		(* Constants for Bit x set *)
		C22 = 400000H; C23 = 800000H; C24 = 1000000H; C25 = 2000000H;

		(* Op-Codes Single Data Transfer (SDT) *)
		LDR* = 51H; (* LDR, pre-indexed, no write-back *)
		STR* = 50H; (* STR, pre-indexed, no write-back *)
		LDRB* = 55H; (* LDRB, pre-indexed, no write-back *)
		STRB* = 54H; (* STRB, pre-indexed, no write-back *)
			LDRpost* = 41H; (* LDR, post-indexed, no write-back-bit *)
		STRpost* = 40H; (* STR, post-indexed, no write-back-bit *)
		LDRBpost* = 45H; (* LDRB, post-indexed, no write-back-bit *)
		STRBpost* = 44H; (* STRB, post-indexed, no write-back-bit *)
			(* Op-Codes Halfword Data Transfer (HDT) *)
		LDRSH* = 11000F0H; (* LDRSH, pre-indexed, no write-back *)
		STRH* = 10000B0H; (* STRH, pre-indexed, no write-back *)
		LDRSB* = 11000D0H; (* LDRSB, pre-indexed, no write-back *)

		(* Op-Codes Block Data Transfer (BDT) *)
		LDMIA* = 89H; STMIA* = 88H; STMDB* = 90H;
		
		(* Op-Codes Data Processing: S-Bit is always set (except for MOV and RSBnoflags ) ! *)
		AND* = 1; EOR* = 3; SUB* = 5; RSBnoflags* = 6; RSB* = 7; ADD* = 9; ADCop = 11; SBCop = 13; RSC = 15; TST* = 17;
		TEQ = 19;
		CMP* = 21; CMN* = 23;  ORR* = 25; MOV* = 26; MOVS* = 27; BIC* = 29; MVN* = 30; MVNS = 31;

		(* Op-Codes Branch Instructions *)
		(* B* = 10; BL* = 11; *)		

		(* Op-Codes Multiplication *)
		MUL* = 0; MLA* = 200000H;
		
		(* Op-Codes Long Multiplication *)
		SMULL* = 00C00090H; 
		
		(* Conditions *)
		EQ* = 0; NE* = 1; CS* = 2; CC* = 3;  MI* = 4; PL* = 5; VS* = 6; VC* = 7;
		HI* = 8; LS* = 9; GE* = 10; LT* = 11;  GT* = 12; LE* = 13; AL* = 14; NV* = 15;
		 
		(* Register Numbers *)
		PC* = 15; LR* = 14; SP* = 13; FP* = 12; FirstUniversalReg = 9;

		(* Const Types *)
		Constant = 0; StringAddr = 1; ProcAddr = 2; ExtAddr = 3; 
		
    StkOrg0 = -64; VarOrg0 = 0;  

    MT = 10; SB = 11; (*SP = 13; *) LNK = 14;   (*dedicated registers*)
(*    MT = 12; SB = 13; SP = 14; LNK = 15;  *) (*dedicated registers - RISC*)
    maxCode = 8000; maxStrx = 2400; maxTD = 120; (*C24 = 1000000H; *)
    Reg = 10; RegI = 11; Cond = 12;  (*internal item modes*)

  (*opcode formats*)
   DPfmt = 0; MULfmt = 1; MULLfmt = 2; SDSfmt = 3; BEfmt = 4; HDTRfmt = 5; HDTIfmt = 6;   SDTfmt = 7; UNDfmt = 8; BDTfmt = 9; BRfmt = 10; CDTfmt = 11; CDOfmt = 12; CRTfmt = 13; SWIfmt = 14;

  (*frequently used opcodes*)  U = 2000H;    And = 0; Eor = 1; Sub = 2; Rsb = 3; Add = 4; Adc = 5; Sbc = 6; Rsc = 7;    Tst = 8; Teq = 9; Cmp = 10; Cmn = 11; Orr = 12; Mov = 13; Bic = 14; Mvn = 15;
    Lsl = 1; Asr = 2; Ror= 3;  Ann = 5; Ior = 6; Xor = 7;
    Mul = 10; Div = 11;
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15;
    Ldr = 51H; Str = 50H;
 (*   Ldr = 8; Str = 10; *)
    BR = 0; BLR = 1; BC = 2;  BL = 3; 
  (*  MI = 0;  PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14; *)


  (* Item forms and meaning of fields:
    mode    r      a       b
    --------------------------------
    Const   -     value (proc adr)   (immediate value)
    Var     base   off     -               (direct adr)
    Par      -     off0     off1         (indirect adr)
    Reg    regno
    RegI   regno   off     -
    Cond  cond   Fchain  Tchain  *)

  VAR pc, varsize: LONGINT;   (*program counter, data index*)
    tdx, strx: LONGINT;
    entry: LONGINT;   (*main entry point*)
    RH: LONGINT;  (*available registers R[0] ... R[H-1]*)
    curSB: LONGINT;  (*current static base in SB*)
    fixorgP, fixorgD, fixorgT: LONGINT;   (*origins of lists of locations to be fixed up by loader*)
    check, inhibitCalls: BOOLEAN;  (*emit run-time checks*)
    version: INTEGER;  (* 0 = RISC-0, 1 = RISC-5 *)
    
    relmap: ARRAY 6 OF INTEGER;  (*condition codes for relations*)
    code: ARRAY maxCode OF LONGINT;
    data: ARRAY maxTD OF LONGINT;  (*type descriptors*)
    str: ARRAY maxStrx OF CHAR;

  (*instruction disassemblers according to formats*)


  PROCEDURE opFormat*(w: LONGINT): LONGINT;
		VAR fmt,cc, a, b, f: LONGINT; 
	BEGIN
        cc := w DIV 10000000H;
        a  := w DIV 1000000H MOD 10H;
        b  := w DIV 100000H MOD 10H;
        f   := w DIV 10H MOD 10H;
		
		IF  (( a = 0 ) OR ( a = 1 ) OR ( a = 2 ) OR ( a = 3 )) THEN
				IF (f = 9) & (a = 0) THEN (*mul / mull *)
					IF ODD(b DIV 8) THEN   fmt := MULLfmt	ELSE  fmt := MULfmt	END
				ELSIF (f>9) & ODD(f) & (a<2) THEN (* ldrh/strh *)
					IF ~ODD(b DIV 4) THEN     fmt :=   HDTRfmt  ELSE     fmt :=   HDTIfmt    END
				ELSIF (f = 9) & (a=1) THEN (*single swap *)
                      fmt := SDSfmt
				ELSIF (a = 1) & ((b = 2) OR (b = 6) OR (b = 0) OR (b = 4)) OR (a = 3)&((b = 2) OR (b = 6)) THEN(* msr /mrs *)
                      fmt :=  -1
				ELSE
					IF (b DIV 2 + a*8 MOD 10H = 0DH) OR (b DIV 2 + a*8 MOD 10H = 0FH) THEN (* Mov, Mvn*)
				        fmt := DPfmt
					ELSIF (b DIV 2 + a*8 MOD 10H >= 8H) & (b DIV 2 + a*8 MOD 10H <=  0BH) THEN (* cmp, tst*)
			            fmt := DPfmt
					ELSE 
				        fmt := DPfmt
					END;
					IF ODD(a DIV 2) THEN 	(* Immidiate Data processing *)
					    fmt := DPfmt
					ELSE 	(* Data processing *)
					    fmt :=  DPfmt
					END
                END
        ELSIF ((a=4) OR (a=5) OR (a=6) OR (a=7)) THEN (* ldf, str *)
				IF (a >= 6) & ODD(f) THEN 	(* undef *)
					   fmt := UNDfmt
				ELSE	(*ldr, str *)
					   fmt := SDTfmt
				END
        ELSIF ((a=8) OR (a=9)) THEN (* ldm, stm *)	fmt := BDTfmt
        ELSIF a=0AH THEN (* Branch *)					   fmt := BRfmt
        ELSIF a=0BH THEN (* Branch and Link *)	     fmt := BRfmt
        ELSIF a=0CH THEN (* FP Push/Pop *)			   fmt := CDTfmt
        ELSIF a=0DH THEN (* FP Ldc / Stc *)			   fmt := CDTfmt
        ELSIF a=0EH THEN (* FP Operation *)			  fmt := CDOfmt
        ELSIF a=0FH THEN (* SWI *)      					   fmt := SWIfmt
        END
        RETURN fmt
  END opFormat;

(*  From OSAG.Mod:

PROCEDURE Put0(op, dst, src0, src1: LONGINT); (*register operation*)
PROCEDURE Put0a(op, dst, src0, src1, shmd, shcnt: LONGINT); (*register operation with shift*) 
PROCEDURE Put0b(op, dst, src0, src1, shmd, shreg: LONGINT); (*register operation with shift cnt from reg*) 
PROCEDURE Put0c(op, dst, src0, src1, src2: LONGINT); (*multiply*)
PROCEDURE Put1(op, dst, src, imm: LONGINT); (*register operation with immediate*)
PROCEDURE Put2(op, reg, base, offset: LONGINT); (*Load/store with offset literal*)
PROCEDURE Put3(op, reg, base, offreg, shift: LONGINT); (*Load/store with offset from register*) 
PROCEDURE Put4(op, base: LONGINT; regs: SET); (*Load/Store multiple*)
PROCEDURE Put5(cond, offset: LONGINT); (*Branch conditional*)
PROCEDURE Put5a(offset: LONGINT); (*Branch and Link*)
PROCEDURE Put6(cond, num: LONGINT); (*SWI conditional*)

*)

  (*instruction assemblers according to formats*)

  PROCEDURE GetPC*(): LONGINT;
  BEGIN
    RETURN pc
  END GetPC;


  PROCEDURE Put0(op, a, b, c: LONGINT);
  BEGIN (*emit format-0 instruction*)
    IF  (c >= -100H) & (c <= 0FFH) THEN
      code[pc] := (AL * 10000000H) + (op*200000H) + (b * 10000H) + (a * 1000H) + c 
    ELSE 
      O7S.Mark("Put0 c overflow")
    END;
    INC(pc)
  END Put0;

  PROCEDURE Put1(op, a, b, im: LONGINT);
  BEGIN (*emit format-1 instruction,  -10000H <= im < 10000H*)
    IF (im >= -100H) & (im <= 0FFH) THEN
      code[pc] := (AL * 10000000H) + 2000000H + (op*200000H) + (b * 10000H) + (a * 1000H) + im
    ELSE 
      code[pc] := (AL * 10000000H) + 2000000H + (op*200000H) + (b * 10000H) + (a * 1000H) + 0BFH
(*
      O7S.Mark("Put1 im overflow")
*)
    END;
(*
    IF im < 0 THEN INC(op, 1000H) END ;  (*set v-bit*)
    code[pc] := (((a+40H) * 10H + b) * 10H + op) * 10000H + (im MOD 10000H);
*)
    INC(pc)
  END Put1;

  PROCEDURE Put1a(op, a, b, im: LONGINT);
  BEGIN (*same as Pu1, but with range test  -100H <= im < 100H*)
    IF (im >= -100H) & (im <= 0FFH) THEN Put1(op, a, b, im)
    ELSE Put1(Mov+U, RH, 0, im DIV 100H);
      IF im MOD 100H # 0 THEN Put1(Ior, RH, RH, im MOD 100H) END ;
      Put0(op, a, b, RH)
    END
  END Put1a;

  PROCEDURE Put2(op, a, b, off: LONGINT);
  BEGIN (*emit load/store instruction*) 
    IF (off >= -1000H) & (off <= 0FFFH) THEN
      IF ((op = Ldr) OR (op = Str)) THEN
        IF off < 0 THEN
          code[pc] := (AL * 10000000H) + (op * 100000H) + (b *  10000H) + (a * 1000H) + (0- off )
        ELSE
          code[pc] := (AL * 10000000H) + (op * 100000H) + 800000H + (b *  10000H) + (a * 1000H) + off
        END
      ELSE
        O7S.Mark("load/store was not load or store")
      END
    ELSE
      O7S.Mark("offset in ARM opcode too large")
    END;

   
(*
    code[pc] := ((op * 10H + a) * 10H + b) * 100000H + (off MOD 100000H); *)
    INC(pc)
  END Put2;

  PROCEDURE Put3(op, cond, off: LONGINT);
  BEGIN (*emit branch instruction*)
    IF op = BR THEN
      IF cond = 7 THEN
         Put0(Mov,PC,0,LR);
         DEC(pc)
      ELSE
        code[pc] := 0E0000000H;
      END
(*     code[pc] := ( AL * 10000000H ) + (5 * 2000000H) + (off MOD 1000000H); *)
    ELSIF op = BLR THEN
     code[pc] := 0E0000001H;
    ELSIF op = BC THEN
     code[pc] := 0E0000002H;
 (*     code[pc] := ( cond * 10000000H ) + (5 * 2000000H) + (off MOD 1000000H);*)
    ELSIF op = BL THEN
     code[pc] := 0E0000003H;
    ELSE
      O7S.Mark("unknown branch opcode")
    END;
(*
    code[pc] := cond * 10000000H + 0A000000H + off;
*)
(*
    code[pc] := ((op+12) * 10H + cond) * 1000000H + (off MOD 1000000H);
*)
    INC(pc)
  END Put3;

  PROCEDURE incR;
  BEGIN
    IF RH < MT THEN INC(RH) ELSE O7S.Mark("register stack overflow") END
  END incR;

  PROCEDURE CheckRegs*;
  BEGIN
    IF RH # 0 THEN O7S.Mark("Reg Stack"); RH := 0 END ;
    IF pc >= maxCode - 40 THEN O7S.Mark("Program too long"); END
  END CheckRegs;

  PROCEDURE SaveRegs(r: LONGINT); (* R[0 .. r-1] to be saved; R[r .. RH-1] to be moved down*)
    VAR rs, rd: LONGINT;  (*r > 0*)
  BEGIN rs := r; rd := 0;
    REPEAT DEC(rs); Put1(Sub, SP, SP, 4); Put2(Str, rs, SP, 0) UNTIL rs = 0;
    rs := r; rd := 0;
    WHILE rs < RH DO Put0(Mov, rd, 0, rs); INC(rs); INC(rd) END ;
    RH := rd
  END SaveRegs;

  PROCEDURE RestoreRegs(r: LONGINT; VAR x: OXG.Item); (*R[0 .. r-1] to be restored*)
    VAR rd: LONGINT;  (*r > 0*)
  BEGIN Put0(Mov, r, 0, 0); rd := 0;
    REPEAT Put2(Ldr, rd, SP, 0); Put1(Add, SP, SP, 4); INC(rd) UNTIL rd = r
  END RestoreRegs;

  PROCEDURE SetCC(VAR x: OXG.Item; n: LONGINT);
  BEGIN x.mode := Cond; x.a := 0; x.b := 0; x.r := n
  END SetCC;

  PROCEDURE Trap(cond, num: LONGINT);
  BEGIN Put3(BLR, cond, O7S.Pos()*100H + num*10H + MT)
  END Trap;

  (*handling of forward reference, fixups of branch addresses and constant tables*)

  PROCEDURE negated(cond: LONGINT): LONGINT;
  BEGIN
    IF cond < 8 THEN cond := cond+8 ELSE cond := cond-8 END ;
    RETURN cond
  END negated;

  PROCEDURE invalSB;
  BEGIN curSB := 1
  END invalSB;

  PROCEDURE fix(at, with: LONGINT);
  BEGIN (* code[at] := code[at] DIV C24 * C24 + (with MOD C24) *)
  END fix;

  PROCEDURE FixLink*(L: LONGINT);
    VAR L1: LONGINT;
  BEGIN  (*invalSB;*)(*
    WHILE L # 0 DO L1 := code[L] MOD 40000H; fix(L, pc-L-1); L := L1 END*)
  END FixLink;

  PROCEDURE FixLinkWith(L0, dst: LONGINT);
    VAR L1: LONGINT;
  BEGIN(*
    WHILE L0 # 0 DO
      L1 := code[L0] MOD C24;
      code[L0] := code[L0] DIV C24 * C24 + ((dst - L0 - 1) MOD C24); L0 := L1
    END*)
  END FixLinkWith;

  PROCEDURE merged(L0, L1: LONGINT): LONGINT;
    VAR L2, L3: LONGINT;
  BEGIN 
    IF L0 # 0 THEN L3 := L0;
      REPEAT L2 := L3; L3 := code[L2] MOD 40000H UNTIL L3 = 0;
      code[L2] := code[L2] + L1; L1 := L0
    END ;
    RETURN L1
  END merged;

  (* loading of operands and addresses into registers *)

  PROCEDURE GetSB(base: LONGINT);
  BEGIN
    IF (version # 0) & ((base # curSB) OR (base # 0)) THEN
      Put2(Ldr, SB, -base, pc-fixorgD); fixorgD := pc-1; curSB := base
    END
  END GetSB;

  PROCEDURE NilCheck;
  BEGIN IF check THEN Trap(EQ, 4) END
  END NilCheck;

  PROCEDURE load(VAR x: OXG.Item);
    VAR op: LONGINT;
  BEGIN
    IF x.type.size = 1 THEN op := Ldr+1 ELSE op := Ldr END ;
    IF x.mode # Reg THEN
      IF x.mode = O7B.Var THEN
        IF x.r > 0 THEN (*local*) Put2(op, RH, SP, x.a)
        ELSE GetSB(x.r); Put2(op, RH, SB, x.a)
        END ;
        x.r := RH; incR
      ELSIF x.mode = O7B.Par THEN Put2(Ldr, RH, SP, x.a); Put2(op, RH, RH, x.b); x.r := RH; incR
      ELSIF x.mode = O7B.Const THEN
        IF x.type.form = O7B.Proc THEN
          IF x.r > 0 THEN O7S.Mark("not allowed")
          ELSIF x.r = 0 THEN Put3(BL, 7, 0); Put1a(Sub, RH, LNK, pc*4 - x.a)
          ELSE GetSB(x.r); Put1(Add, RH, SB, x.a + 100H) (*mark as progbase-relative*)
          END
        ELSIF (x.a <= 0FFH) & (x.a >= -100H) THEN Put1(Mov, RH, 0, x.a)    (* FIXME load immediate in parts *)
        ELSE Put1(Mov+U, RH, 0, x.a DIV 100H MOD 100H);
          IF x.a MOD 100H # 0 THEN Put1(Ior, RH, RH, x.a MOD 100H) END
        END ;
        x.r := RH; incR
      ELSIF x.mode = RegI THEN Put2(op, x.r, x.r, x.a)
      ELSIF x.mode = Cond THEN
        Put3(BC, negated(x.r), 2);
        FixLink(x.b); Put1(Mov, RH, 0, 1); Put3(BC, 7, 1);
        FixLink(x.a); Put1(Mov, RH, 0, 0); x.r := RH; incR
      END ;
      x.mode := Reg
    END
  END load;

  PROCEDURE loadAdr(VAR x: OXG.Item);
  BEGIN
    IF x.mode = O7B.Var THEN
      IF x.r > 0 THEN (*local*) Put1a(Add, RH, SP, x.a)
      ELSE GetSB(x.r); Put1a(Add, RH, SB, x.a)
      END ;
      x.r := RH; incR
    ELSIF x.mode = O7B.Par THEN Put2(Ldr, RH, SP, x.a);
      IF x.b # 0 THEN Put1a(Add, RH, RH, x.b) END ;
      x.r := RH; incR
    ELSIF x.mode = RegI THEN
      IF x.a # 0 THEN Put1a(Add, x.r, x.r, x.a) END
    ELSE O7S.Mark("address error") 
    END ;
    x.mode := Reg
  END loadAdr;

  PROCEDURE loadCond(VAR x: OXG.Item);
  BEGIN
    IF x.type.form = O7B.Bool THEN
      IF x.mode = O7B.Const THEN x.r := 15 - x.a*8
      ELSE load(x);
        IF code[pc-1] DIV 40000000H # -2 THEN Put1(Cmp, x.r, x.r, 0) END ;
        x.r := NE; DEC(RH)
      END ;
      x.mode := Cond; x.a := 0; x.b := 0
    ELSE O7S.Mark("not Boolean?")
    END
  END loadCond;

  PROCEDURE loadTypTagAdr(T: O7B.Type);
    VAR x: OXG.Item;
  BEGIN x.mode := O7B.Var; x.a := T.len; x.r := -T.mno; loadAdr(x)
  END loadTypTagAdr;

  PROCEDURE loadStringAdr(VAR x: OXG.Item);
  BEGIN GetSB(0); Put1a(Add, RH, SB, varsize+x.a); x.mode := Reg; x.r := RH; incR
  END loadStringAdr;

  (* Items: Conversion from constants or from Objects on the Heap to Items on the Stack*)

  PROCEDURE MakeConstItem*(VAR x: OXG.Item; typ: O7B.Type; val: LONGINT);
  BEGIN x.mode := O7B.Const; x.type := typ; x.a := val
  END MakeConstItem;

  PROCEDURE MakeRealItem*(VAR x: OXG.Item; val: REAL);
  BEGIN x.mode := O7B.Const; x.type := O7B.realType; x.a := SYSTEM.VAL(LONGINT, val)
  END MakeRealItem;

  PROCEDURE MakeStringItem*(VAR x: OXG.Item; len: LONGINT); (*copies string from O7S-buffer to ORG-string array*)
    VAR i: LONGINT;
  BEGIN x.mode := O7B.Const; x.type := O7B.strType; x.a := strx; x.b := len; i := 0;
    IF strx + len + 4 < maxStrx THEN
      WHILE len > 0 DO str[strx] := O7S.str[i]; INC(strx); INC(i); DEC(len) END ;
      WHILE strx MOD 4 # 0 DO str[strx] := 0X; INC(strx) END
    ELSE O7S.Mark("too many strings")
    END
  END MakeStringItem;

  PROCEDURE MakeItem*(VAR x: OXG.Item; y: O7B.Object; curlev: LONGINT);
  BEGIN x.mode := y.class; x.type := y.type; x.a := y.val; x.rdo := y.rdo;
    IF y.class = O7B.Par THEN x.b := 0
    ELSIF y.class = O7B.Typ THEN x.a := y.type.len; x.r := -y.lev
    ELSIF (y.class = O7B.Const) & (y.type.form = O7B.String) THEN x.b := y.lev  (*len*)
    ELSE x.r := y.lev
    END ;
    IF (y.lev > 0) & (y.lev # curlev) & (y.class # O7B.Const) THEN O7S.Mark("level error, not accessible") END
  END MakeItem;

  (* Code generation for Selectors, Variables, Constants *)

  PROCEDURE Field*(VAR x: OXG.Item; y: O7B.Object);   (* x := x.y *)
  BEGIN;
    IF x.mode = O7B.Var THEN
      IF x.r >= 0 THEN x.a := x.a + y.val
      ELSE loadAdr(x); x.mode := RegI; x.a := y.val
      END
    ELSIF x.mode = RegI THEN x.a := x.a + y.val
    ELSIF x.mode = O7B.Par THEN x.b := x.b + y.val
    END
  END Field;

  PROCEDURE Index*(VAR x, y: OXG.Item);   (* x := x[y] *)
    VAR s, lim: LONGINT;
  BEGIN s := x.type.base.size; lim := x.type.len;
    IF (y.mode = O7B.Const) & (lim >= 0) THEN
      IF (y.a < 0) OR (y.a >= lim) THEN O7S.Mark("bad index") END ;
      IF x.mode IN {O7B.Var, RegI} THEN x.a := y.a * s + x.a
      ELSIF x.mode = O7B.Par THEN x.b := y.a * s + x.b
      END
    ELSE load(y);
      IF check THEN  (*check array bounds*)
        IF lim >= 0 THEN Put1a(Cmp, RH, y.r, lim)
        ELSE (*open array*)
          IF x.mode IN {O7B.Var, O7B.Par} THEN Put2(Ldr, RH, SP, x.a+4); Put0(Cmp, RH, y.r, RH)
          ELSE O7S.Mark("error in Index")
          END
        END ;
        Trap(10, 1)
      END ;
      IF s = 4 THEN Put1(Lsl, y.r, y.r, 2) ELSIF s > 1 THEN Put1(Mul, y.r, y.r, s) END ;
      IF x.mode = O7B.Var THEN
        IF x.r > 0 THEN Put0(Add, y.r, SP, y.r)
        ELSE GetSB(x.r);
          IF x.r = 0 THEN Put0(Add, y.r, SB, y.r)
          ELSE Put1a(Add, RH, SB, x.a); Put0(Add, y.r, RH, y.r); x.a := 0
          END
        END ;
        x.r := y.r; x.mode := RegI
      ELSIF x.mode = O7B.Par THEN
        Put2(Ldr, RH, SP, x.a);
        Put0(Add, y.r, RH, y.r); x.mode := RegI; x.r := y.r; x.a := x.b
      ELSIF x.mode = RegI THEN Put0(Add, x.r, x.r, y.r); DEC(RH)
      END
    END
  END Index;

  PROCEDURE DeRef*(VAR x: OXG.Item);
  BEGIN
    IF x.mode = O7B.Var THEN
      IF x.r > 0 THEN (*local*) Put2(Ldr, RH, SP, x.a) ELSE GetSB(x.r); Put2(Ldr, RH, SB, x.a) END ;
      NilCheck; x.r := RH; incR
    ELSIF x.mode = O7B.Par THEN
      Put2(Ldr, RH, SP, x.a); Put2(Ldr, RH, RH, x.b); NilCheck; x.r := RH; incR
    ELSIF x.mode = RegI THEN Put2(Ldr, x.r, x.r, x.a); NilCheck
    ELSIF x.mode # Reg THEN O7S.Mark("bad mode in DeRef")
    END ;
    x.mode := RegI; x.a := 0; x.b := 0
  END DeRef;

  PROCEDURE Q(T: O7B.Type; VAR dcw: LONGINT);
  BEGIN (*one entry of type descriptor extension table*)
    IF T.base # NIL THEN
      Q(T.base, dcw); data[dcw] := (T.mno*1000H + T.len) * 1000H + dcw - fixorgT;
      fixorgT := dcw; INC(dcw)
    END
  END Q;

  PROCEDURE FindPtrFlds(typ: O7B.Type; off: LONGINT; VAR dcw: LONGINT);
    VAR fld: O7B.Object; i, s: LONGINT;
  BEGIN
    IF (typ.form = O7B.Pointer) OR (typ.form = O7B.NilTyp) THEN data[dcw] := off; INC(dcw)
    ELSIF typ.form = O7B.Record THEN
      fld := typ.dsc;
      WHILE fld # NIL DO FindPtrFlds(fld.type, fld.val + off, dcw); fld := fld.next END
    ELSIF typ.form = O7B.Array THEN
      s := typ.base.size;
      FOR i := 0 TO typ.len-1 DO FindPtrFlds(typ.base, i*s + off, dcw) END
    END
  END FindPtrFlds;

  PROCEDURE BuildTD*(T: O7B.Type; VAR dc: LONGINT);
    VAR dcw, k, s: LONGINT;  (*dcw = word address*)
  BEGIN dcw := dc DIV 4; s := T.size; (*convert size for heap allocation*)
    IF s <= 24 THEN s := 32 ELSIF s <= 56 THEN s := 64 ELSIF s <= 120 THEN s := 128
    ELSE s := (s+263) DIV 256 * 256
    END ;
    data[dcw] := s; INC(dcw);
    k := T.nofpar;   (*extension level!*)
    IF k > 3 THEN O7S.Mark("ext level too large")
    ELSE Q(T, dcw);
      WHILE k < 3 DO data[dcw] := -1; INC(dcw); INC(k) END
    END ;
    FindPtrFlds(T, 0, dcw); data[dcw] := -1; INC(dcw); tdx := dcw; dc := dcw*4;
    IF tdx >= maxTD THEN O7S.Mark("too many record types"); tdx := 0 END
  END BuildTD;

  PROCEDURE TypeTest*(VAR x: OXG.Item; T: O7B.Type; varpar, isguard: BOOLEAN);
  BEGIN (*fetch tag into RH*)
    IF varpar THEN Put2(Ldr, RH, SP, x.a+4)
    ELSE load(x); NilCheck; Put2(Ldr, RH, x.r, -8)
    END ;
    Put2(Ldr, RH, RH, T.nofpar*4); incR;
    loadTypTagAdr(T);  (*tag of T*)
    Put0(Cmp, RH, RH-1, RH-2); DEC(RH, 2);
    IF isguard THEN
      IF check THEN Trap(NE, 2) END
    ELSE SetCC(x, EQ);
      IF ~varpar THEN DEC(RH) END
    END
  END TypeTest;

  (* Code generation for Boolean operators *)

  PROCEDURE Not*(VAR x: OXG.Item);   (* x := ~x *)
    VAR t: LONGINT;
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    x.r := negated(x.r); t := x.a; x.a := x.b; x.b := t
  END Not;

  PROCEDURE And1*(VAR x: OXG.Item);   (* x := x & *)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(BC, negated(x.r), x.a); x.a := pc-1; FixLink(x.b); x.b := 0
  END And1;

  PROCEDURE And2*(VAR x, y: OXG.Item);
  BEGIN
    IF y.mode # Cond THEN loadCond(y) END ;
    x.a := merged(y.a, x.a); x.b := y.b; x.r := y.r
  END And2;

  PROCEDURE Or1*(VAR x: OXG.Item);   (* x := x OR *)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(BC, x.r, x.b);  x.b := pc-1; FixLink(x.a); x.a := 0
  END Or1;

  PROCEDURE Or2*(VAR x, y: OXG.Item);
  BEGIN
    IF y.mode # Cond THEN loadCond(y) END ;
    x.a := y.a; x.b := merged(y.b, x.b); x.r := y.r
  END Or2;

  (* Code generation for arithmetic operators *)

  PROCEDURE Neg*(VAR x: OXG.Item);   (* x := -x *)
  BEGIN
    IF x.type.form = O7B.Int THEN
      IF x.mode = O7B.Const THEN x.a := -x.a
      ELSE load(x); Put1(Mov, RH, 0, 0); Put0(Sub, x.r, RH, x.r)
      END
    ELSIF x.type.form = O7B.Real THEN
      IF x.mode = O7B.Const THEN x.a := x.a + 7FFFFFFFH + 1
      ELSE load(x); Put1(Mov, RH, 0, 0); Put0(Fsb, x.r, RH, x.r)
      END
    ELSE (*form = Set*)
      IF x.mode = O7B.Const THEN x.a := -x.a-1 
      ELSE load(x); Put1(Xor, x.r, x.r, -1)
      END
    END
  END Neg;

  PROCEDURE AddOp*(op: LONGINT; VAR x, y: OXG.Item);   (* x := x +- y *)
  BEGIN
    IF op = O7S.plus THEN
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN x.a := x.a + y.a
      ELSIF y.mode = O7B.Const THEN load(x);
        IF y.a # 0 THEN Put1a(Add, x.r, x.r, y.a) END
      ELSE load(x); load(y); Put0(Add, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = O7S.minus*)
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN x.a := x.a - y.a
      ELSIF y.mode = O7B.Const THEN load(x);
        IF y.a # 0 THEN Put1a(Sub, x.r, x.r, y.a) END
      ELSE load(x); load(y); Put0(Sub, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    END
  END AddOp;

  PROCEDURE log2(m: LONGINT; VAR e: LONGINT): LONGINT;
  BEGIN e := 0;
    WHILE ~ODD(m) DO m := m DIV 2; INC(e) END ;
    RETURN m
  END log2;
  
  PROCEDURE MulOp*(VAR x, y: OXG.Item);   (* x := x * y *)
    VAR e: LONGINT;
  BEGIN
    IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN x.a := x.a * y.a
    ELSIF (y.mode = O7B.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); Put1(Lsl, x.r, x.r, e)
    ELSIF y.mode = O7B.Const THEN load(x); Put1a(Mul, x.r, x.r, y.a)
    ELSIF (x.mode = O7B.Const) & (x.a >= 2) & (log2(x.a, e) = 1) THEN load(y); Put1(Lsl, y.r, y.r, e); x.mode := Reg; x.r := y.r
    ELSIF x.mode = O7B.Const THEN load(y); Put1a(Mul, y.r, y.r, x.a); x.mode := Reg; x.r := y.r
    ELSE load(x); load(y); Put0(Mul, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
    END
  END MulOp;

  PROCEDURE DivOp*(op: LONGINT; VAR x, y: OXG.Item);   (* x := x op y *)
    VAR e: LONGINT;
  BEGIN
    IF op = O7S.div THEN
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN
        IF y.a > 0 THEN x.a := x.a DIV y.a ELSE O7S.Mark("bad divisor") END
      ELSIF (y.mode = O7B.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); Put1(Asr, x.r, x.r, e)
      ELSIF y.mode = O7B.Const THEN
        IF y.a > 0 THEN load(x); Put1a(Div, x.r, x.r, y.a) ELSE O7S.Mark("bad divisor") END
      ELSE load(y);
        IF check THEN Trap(LE, 6) END ;
        load(x); Put0(Div, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = O7S.mod*)
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN
        IF y.a > 0 THEN x.a := x.a MOD y.a ELSE O7S.Mark("bad modulus") END
      ELSIF (y.mode = O7B.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x);
        IF e <= 16 THEN Put1(And, x.r, x.r, y.a-1) ELSE Put1(Lsl, x.r, x.r, 32-e); Put1(Ror, x.r, x.r, 32-e) END
      ELSIF y.mode = O7B.Const THEN
        IF y.a > 0 THEN load(x); Put1a(Div, x.r, x.r, y.a); Put0(Mov+U, x.r, 0, 0) ELSE O7S.Mark("bad modulus") END
      ELSE load(y);
        IF check THEN Trap(LE, 6) END ;
        load(x); Put0(Div, RH-2, x.r, y.r); Put0(Mov+U, RH-2, 0, 0); DEC(RH); x.r := RH-1
      END
    END
  END DivOp;

  (* Code generation for REAL operators *)

  PROCEDURE RealOp*(op: INTEGER; VAR x, y: OXG.Item);   (* x := x op y *)
  BEGIN load(x); load(y);
    IF op = O7S.plus THEN Put0(Fad, RH-2, x.r, y.r)
    ELSIF op = O7S.minus THEN Put0(Fsb, RH-2, x.r, y.r)
    ELSIF op = O7S.times THEN Put0(Fml, RH-2, x.r, y.r)
    ELSIF op = O7S.rdiv THEN Put0(Fdv, RH-2, x.r, y.r)
    END ;
    DEC(RH); x.r := RH-1
  END RealOp;

  (* Code generation for set operators *)

  PROCEDURE Singleton*(VAR x: OXG.Item);  (* x := {x} *)
  BEGIN
    IF x.mode = O7B.Const THEN x.a := LSL(1, x.a)
    ELSE load(x); Put1(Mov, RH, 0, 1); Put0(Lsl, x.r, RH,  x.r)
    END
  END Singleton;

  PROCEDURE Set*(VAR x, y: OXG.Item);   (* x := {x .. y} *)
  BEGIN
    IF (x.mode = O7B.Const) & ( y.mode = O7B.Const) THEN
      IF x.a <= y.a THEN x.a := LSL(2, y.a) - LSL(1, x.a) ELSE x.a := 0 END
    ELSE
      IF (x.mode = O7B.Const) & (x.a < 10H) THEN x.a := LSL(-1, x.a)
      ELSE load(x); Put1(Mov, RH, 0, -1); Put0(Lsl, x.r, RH, x.r)
      END ;
      IF (y.mode = O7B.Const) & (y.a < 10H) THEN Put1(Mov, RH, 0, LSL(-2, y.a)); y.mode := Reg; y.r := RH; INC(RH)
      ELSE load(y); Put1(Mov, RH, 0, -2); Put0(Lsl, y.r, RH, y.r)
      END ;
      IF x.mode = O7B.Const THEN
        IF x.a # 0 THEN Put1(Xor, y.r, y.r, -1); Put1a(And, RH-1, y.r, x.a) END ;
        x.mode := Reg; x.r := RH-1
      ELSE DEC(RH); Put0(Ann, RH-1, x.r, y.r)
      END
    END
  END Set;

  PROCEDURE In*(VAR x, y: OXG.Item);  (* x := x IN y *)
  BEGIN load(y);
    IF x.mode = O7B.Const THEN Put1(Ror, y.r, y.r, (x.a + 1) MOD 20H); DEC(RH)
    ELSE load(x); Put1(Add, x.r, x.r, 1); Put0(Ror, y.r, y.r, x.r); DEC(RH, 2)
    END ;
    SetCC(x, MI)
  END In;

  PROCEDURE SetOp*(op: LONGINT; VAR x, y: OXG.Item);   (* x := x op y *)
    VAR xset, yset: SET; (*x.type.form = Set*)
  BEGIN
    IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN
      xset := SYSTEM.VAL(SET, x.a); yset := SYSTEM.VAL(SET, y.a);
      IF op = O7S.plus THEN xset := xset + yset
      ELSIF op = O7S.minus THEN xset := xset - yset
      ELSIF op = O7S.times THEN xset := xset * yset
      ELSIF op = O7S.rdiv THEN xset := xset / yset
      END ;
      x.a := SYSTEM.VAL(LONGINT, xset)
    ELSIF y.mode = O7B.Const THEN
      load(x);
      IF op = O7S.plus THEN Put1a(Ior, x.r, x.r, y.a)
      ELSIF op = O7S.minus THEN Put1a(Ann, x.r, x.r, y.a)
      ELSIF op = O7S.times THEN Put1a(And, x.r, x.r, y.a)
      ELSIF op = O7S.rdiv THEN Put1a(Xor, x.r, x.r, y.a)
      END ;
    ELSE load(x); load(y);
      IF op = O7S.plus THEN Put0(Ior, RH-2, x.r, y.r)
      ELSIF op = O7S.minus THEN Put0(Ann, RH-2, x.r, y.r)
      ELSIF op = O7S.times THEN Put0(And, RH-2, x.r, y.r)
      ELSIF op = O7S.rdiv THEN Put0(Xor, RH-2, x.r, y.r)
      END ;
      DEC(RH); x.r := RH-1
    END 
  END SetOp;

  (* Code generation for relations *)

  PROCEDURE IntRelation*(op: INTEGER; VAR x, y: OXG.Item);   (* x := x < y *)
  BEGIN
    IF (y.mode = O7B.Const) & (y.type.form # O7B.Proc) THEN
      load(x);
      IF (y.a # 0) OR ~(op IN {O7S.eql, O7S.neq}) OR (code[pc-1] DIV 40000000H # -2) THEN Put1a(Cmp, x.r, x.r, y.a) END ;
      DEC(RH)
    ELSE load(x); load(y); Put0(Cmp, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - O7S.eql])
  END IntRelation;

  PROCEDURE SetRelation*(op: INTEGER; VAR x, y: OXG.Item);   (* x := x < y *)
  BEGIN load(x);
    IF (op = O7S.eql) OR (op = O7S.neq) THEN
      IF y.mode = O7B.Const THEN Put1a(Cmp, x.r, x.r, y.a); DEC(RH)
      ELSE load(y); Put0(Cmp, x.r, x.r, y.r); DEC(RH, 2)
      END ;
      SetCC(x, relmap[op - O7S.eql])
    ELSE O7S.Mark("illegal relation") 
    END
  END SetRelation;

  PROCEDURE RealRelation*(op: INTEGER; VAR x, y: OXG.Item);   (* x := x < y *)
  BEGIN load(x);
    IF (y.mode = O7B.Const) & (y.a = 0) THEN DEC(RH)
    ELSE load(y); Put0(Fsb, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - O7S.eql])
  END RealRelation;

  PROCEDURE StringRelation*(op: INTEGER; VAR x, y: OXG.Item);   (* x := x < y *)
    (*x, y are char arrays or strings*)
  BEGIN
    IF x.type.form = O7B.String THEN loadStringAdr(x) ELSE loadAdr(x) END ;
    IF y.type.form = O7B.String THEN loadStringAdr(y) ELSE loadAdr(y) END ;
    Put2(Ldr+1, RH, x.r, 0); Put1(Add, x.r, x.r, 1);
    Put2(Ldr+1, RH+1, y.r, 0); Put1(Add, y.r, y.r, 1);
    Put0(Cmp, RH+2, RH, RH+1); Put3(BC, NE, 2);
    Put1(Cmp, RH+2, RH, 0); Put3(BC, NE, -8);
    DEC(RH, 2); SetCC(x, relmap[op - O7S.eql])
  END StringRelation;

  (* Code generation of Assignments *)

  PROCEDURE StrToChar*(VAR x: OXG.Item);
  BEGIN x.type := O7B.charType; DEC(strx, 4); x.a := ORD(str[x.a])
  END StrToChar;

  PROCEDURE Store*(VAR x, y: OXG.Item); (* x := y *)
    VAR op: LONGINT;
  BEGIN  load(y);
    IF x.type.size = 1 THEN op := Str+1 ELSE op := Str END ;
    IF x.mode = O7B.Var THEN
      IF x.r > 0 THEN (*local*) Put2(op, y.r, SP, x.a)
      ELSE GetSB(x.r); Put2(op, y.r, SB, x.a)
      END
    ELSIF x.mode = O7B.Par THEN Put2(Ldr, RH, SP, x.a); Put2(op, y.r, RH, x.b);
    ELSIF x.mode = RegI THEN Put2(op, y.r, x.r, x.a); DEC(RH);
    ELSE O7S.Mark("bad mode in Store")
    END ;
    DEC(RH)
  END Store;

  PROCEDURE StoreStruct*(VAR x, y: OXG.Item); (* x := y *)
    VAR s, pc0: LONGINT;
  BEGIN loadAdr(x); loadAdr(y);
    IF (x.type.form = O7B.Array) & (x.type.len > 0) THEN
      IF y.type.len >= 0 THEN 
        IF x.type.len >= y.type.len THEN Put1(Mov, RH, 0, (y.type.size+3) DIV 4)
        ELSE O7S.Mark("source array too long")
        END
      ELSE (*y is open array*)
        Put2(Ldr, RH, SP, y.a+4); s := y.type.base.size;  (*element size*)
        pc0 := pc; Put3(BC, EQ, 0);
        IF s = 1 THEN Put1(Add, RH, RH, 3); Put1(Asr, RH, RH, 2)
        ELSIF s # 4 THEN Put1(Mul, RH, RH, s DIV 4)
        END ;
        IF check THEN
          Put1(Mov, RH+1, 0, (x.type.size+3) DIV 4); Put0(Cmp, RH+1, RH, RH+1); Trap(GT, 3)
        END ;
        fix(pc0, pc + 5 - pc0)
      END
    ELSIF x.type.form = O7B.Record THEN Put1(Mov, RH, 0, x.type.size DIV 4)
    ELSE O7S.Mark("inadmissible assignment")
    END ;
    Put2(Ldr, RH+1, y.r, 0); Put1(Add, y.r, y.r, 4);
    Put2(Str, RH+1, x.r, 0); Put1(Add, x.r, x.r, 4);
    Put1(Sub, RH, RH, 1); Put3(BC, NE, -6); DEC(RH, 2)
  END StoreStruct;

  PROCEDURE CopyString*(VAR x, y: OXG.Item);  (*from x to y*)
    VAR len: LONGINT;
  BEGIN loadAdr(y); len := y.type.len;
    IF len >= 0 THEN
      IF x.b > len THEN O7S.Mark("string too long") END
    ELSIF check THEN Put2(Ldr, RH, y.r, 4);  (*array length check*)
      Put1(Cmp, RH, RH, x.b); Trap(NE, 3)
    END ;
    loadStringAdr(x);
    Put2(Ldr, RH, x.r, 0); Put1(Add, x.r, x.r, 4);
    Put2(Str, RH, y.r, 0); Put1(Add, y.r, y.r, 4);
    Put1(Asr, RH, RH, 24); Put3(BC, NE, -6); DEC(RH, 2)
  END CopyString;

  (* Code generation for parameters *)
  
  PROCEDURE VarParam*(VAR x: OXG.Item; ftype: O7B.Type);
    VAR xmd: INTEGER;
  BEGIN xmd := x.mode; loadAdr(x);
    IF (ftype.form = O7B.Array) & (ftype.len < 0) THEN (*open array*)
      IF x.type.len >= 0 THEN Put1(Mov, RH, 0, x.type.len) ELSE  Put2(Ldr, RH, SP, x.a+4) END ;
      incR
    ELSIF ftype.form = O7B.Record THEN
      IF xmd = O7B.Par THEN Put2(Ldr, RH, SP, x.a+4); incR ELSE loadTypTagAdr(x.type) END
    END
  END VarParam;

  PROCEDURE ValueParam*(VAR x: OXG.Item);
  BEGIN load(x)
  END ValueParam;

  PROCEDURE OpenArrayParam*(VAR x: OXG.Item);
  BEGIN loadAdr(x);
    IF x.type.len >= 0 THEN Put1a(Mov, RH, 0, x.type.len) ELSE Put2(Ldr, RH, SP, x.a+4) END ;
    incR
  END OpenArrayParam;

  PROCEDURE StringParam*(VAR x: OXG.Item);
  BEGIN loadStringAdr(x); Put1(Mov, RH, 0, x.b); incR  (*len*)
  END StringParam;

  (*For Statements*)

  PROCEDURE For0*(VAR x, y: OXG.Item);
  BEGIN load(y)
  END For0;

  PROCEDURE For1*(VAR x, y, z, w: OXG.Item; VAR L: LONGINT);
  BEGIN 
    IF z.mode = O7B.Const THEN Put1a(Cmp, RH, y.r, z.a)
    ELSE load(z); Put0(Cmp, RH-1, y.r, z.r); DEC(RH)
    END ;
    L := pc;
    IF w.a > 0 THEN Put3(BC, GT, 0)
    ELSIF w.a < 0 THEN Put3(BC, LT, 0)
    ELSE O7S.Mark("zero increment"); Put3(BC, MI, 0)
    END ;
    Store(x, y)
  END For1;

  PROCEDURE For2*(VAR x, y, w: OXG.Item);
  BEGIN load(x); DEC(RH); Put1a(Add, x.r, x.r, w.a)
  END For2;

  (* Branches, procedure calls, procedure prolog and epilog *)

  PROCEDURE Here*(): LONGINT;
  BEGIN invalSB; RETURN pc
  END Here;

  PROCEDURE FJump*(VAR L: LONGINT);
  BEGIN Put3(BC, 7, L); L := pc-1
  END FJump;

  PROCEDURE CFJump*(VAR x: OXG.Item);
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(BC, negated(x.r), x.a); FixLink(x.b); x.a := pc-1
  END CFJump;

  PROCEDURE BJump*(L: LONGINT);
  BEGIN Put3(BC, 7, L-pc-1)
  END BJump;

  PROCEDURE CBJump*(VAR x: OXG.Item; L: LONGINT);
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(BC, negated(x.r), L-pc-1); FixLink(x.b); FixLinkWith(x.a, L)
  END CBJump;

  PROCEDURE Fixup*(VAR x: OXG.Item);
  BEGIN FixLink(x.a)
  END Fixup;

  PROCEDURE PrepCall*(VAR x: OXG.Item; VAR r: LONGINT);
  BEGIN
    IF x.type.form = O7B.Proc THEN
      IF x.mode # O7B.Const THEN
        load(x); code[pc-1] := code[pc-1] + 0B000000H; x.r := 11; DEC(RH); inhibitCalls := TRUE;
        IF check THEN Trap(EQ, 5) END
      END
    ELSE O7S.Mark("not a procedure")
    END ;
    r := RH
  END PrepCall;

  PROCEDURE Call*(VAR x: OXG.Item; r: LONGINT);
  BEGIN
    IF inhibitCalls & (x.r # 11) THEN O7S.Mark("inadmissible call") ELSE inhibitCalls := FALSE END ;
    IF r > 0 THEN SaveRegs(r) END ;
    IF x.type.form = O7B.Proc THEN
      IF x.mode = O7B.Const THEN
        IF x.r >= 0 THEN Put3(BL, 7, (x.a DIV 4)-pc-1)
        ELSE (*imported*)
          IF pc - fixorgP < 1000H THEN
            Put3(BL, 7, ((-x.r) * 100H + x.a) * 1000H + pc-fixorgP); fixorgP := pc-1
          ELSE O7S.Mark("fixup impossible")
          END
        END
      ELSE Put3(BLR, 7, x.r)
      END
    ELSE O7S.Mark("not a procedure")
    END ;
    IF x.type.base.form = O7B.NoTyp THEN RH := 0
    ELSE
      IF r > 0 THEN RestoreRegs(r, x) END ;
      x.mode := Reg; x.r := r; RH := r+1
    END ;
    invalSB
  END Call;

  PROCEDURE Enter*(parblksize, locblksize: LONGINT; int: BOOLEAN);
    VAR a, r: LONGINT;
  BEGIN invalSB;
    IF ~int THEN (*procedure prolog*)
      a := 4; r := 0;
      Put1(Sub, SP, SP, locblksize); Put2(Str, LNK, SP, 0);
      WHILE a < parblksize DO Put2(Str, r, SP, a); INC(r); INC(a, 4) END
    ELSE (*interrupt procedure*)
      Put1(Sub, SP, SP, 8); Put2(Str, 0, SP, 0); Put2(Str, 1, SP, 4)
      (*R0 and R1 saved, but NOT LNK*)
    END
  END Enter;

  PROCEDURE Return*(form: INTEGER; VAR x: OXG.Item; size: LONGINT; int: BOOLEAN);
  BEGIN
    IF form # O7B.NoTyp THEN load(x) END ;
    IF ~int THEN (*procedure epilog*)
      Put2(Ldr, LNK, SP, 0); Put1(Add, SP, SP, size); Put3(BR, 7, LNK)
    ELSE (*interrupt*)
      Put2(Ldr, 1, SP, 4); Put2(Ldr, 0, SP, 0); Put1(Add, SP, SP, 8); Put3(BR, 7, 10H)
    END ;
    RH := 0
  END Return;

  (* In-line code procedures*)

  PROCEDURE Increment*(upordown: LONGINT; VAR x, y: OXG.Item);
    VAR op, zr, v: LONGINT;
  BEGIN
    IF upordown = 0 THEN op := Add ELSE op := Sub END ;
    IF x.type = O7B.byteType THEN v := 1 ELSE v := 0 END ;
    IF y.type.form = O7B.NoTyp THEN y.mode := O7B.Const; y.a := 1 END ;
    IF (x.mode = O7B.Var) & (x.r > 0) THEN
      zr := RH; Put2(Ldr+v, zr, SP, x.a); incR;
      IF y.mode = O7B.Const THEN Put1(op, zr, zr, y.a) ELSE load(y); Put0(op, zr, zr, y.r); DEC(RH) END ;
      Put2(Str+v, zr, SP, x.a); DEC(RH)
    ELSE loadAdr(x); zr := RH; Put2(Ldr+v, RH, x.r, 0); incR;
      IF y.mode = O7B.Const THEN Put1(op, zr, zr, y.a) ELSE load(y); Put0(op, zr, zr, y.r); DEC(RH) END ;
      Put2(Str+v, zr, x.r, 0); DEC(RH, 2)
    END
  END Increment;

  PROCEDURE Include*(inorex: LONGINT; VAR x, y: OXG.Item);
    VAR zr: LONGINT;
  BEGIN loadAdr(x); zr := RH; Put2(Ldr, RH, x.r, 0); incR;
    IF inorex = 0 THEN (*include*)
      IF y.mode = O7B.Const THEN Put1(Ior, zr, zr, LSL(1, y.a))
      ELSE load(y); Put1(Mov, RH, 0, 1); Put0(Lsl, y.r, RH, y.r); Put0(Ior, zr, zr, y.r); DEC(RH)
      END
    ELSE (*exclude*)
      IF y.mode = O7B.Const THEN Put1(And, zr, zr, -LSL(1, y.a)-1)
      ELSE load(y); Put1(Mov, RH, 0, 1); Put0(Lsl, y.r, RH, y.r); Put1(Xor, y.r, y.r, -1); Put0(And, zr, zr, y.r); DEC(RH)
      END
    END ;
    Put2(Str, zr, x.r, 0); DEC(RH, 2)
  END Include;

  PROCEDURE Assert*(VAR x: OXG.Item);
    VAR cond: LONGINT;
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    IF x.a = 0 THEN cond := negated(x.r)
    ELSE Put3(BC, x.r, x.b); FixLink(x.a); x.b := pc-1; cond := 7
    END ;
    Trap(cond, 7); FixLink(x.b)
  END Assert; 

  PROCEDURE New*(VAR x: OXG.Item);
  BEGIN loadAdr(x); loadTypTagAdr(x.type.base); Put3(BLR, 7, MT); RH := 0; invalSB
  END New;

  PROCEDURE Pack*(VAR x, y: OXG.Item);
    VAR z: OXG.Item;
  BEGIN z := x; load(x); load(y);
    Put1(Lsl, y.r, y.r, 23); Put0(Add, x.r, x.r, y.r); DEC(RH); Store(z, x)
  END Pack;

  PROCEDURE Unpk*(VAR x, y: OXG.Item);
    VAR z, e0: OXG.Item;
  BEGIN  z := x; load(x); e0.mode := Reg; e0.r := RH; e0.type := O7B.intType;
    Put1(Asr, RH, x.r, 23); Put1(Sub, RH, RH, 127); Store(y, e0); incR;
    Put1(Lsl, RH, RH, 23); Put0(Sub, x.r, x.r, RH); Store(z, x)
  END Unpk;

  PROCEDURE Led*(VAR x: OXG.Item);
  BEGIN load(x); Put1(Mov, RH, 0, -60); Put2(Str, x.r, RH, 0); DEC(RH)
  END Led;

  PROCEDURE Get*(VAR x, y: OXG.Item);
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(y, x)
  END Get;

  PROCEDURE Put*(VAR x, y: OXG.Item);
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(x, y)
  END Put;

  PROCEDURE Copy*(VAR x, y, z: OXG.Item);
  BEGIN load(x); load(y);
    IF z.mode = O7B.Const THEN
      IF z.a > 0 THEN load(z) ELSE O7S.Mark("bad count") END
    ELSE load(z);
      IF check THEN Trap(LT, 3) END ;
      Put3(BC, EQ, 6)
    END ;
    Put2(Ldr, RH, x.r, 0); Put1(Add, x.r, x.r, 4);
    Put2(Str, RH, y.r, 0); Put1(Add, y.r, y.r, 4);
    Put1(Sub, z.r, z.r, 1); Put3(BC, NE, -6); DEC(RH, 3)
  END Copy;

  PROCEDURE LDPSR*(VAR x: OXG.Item);
  BEGIN (*x.mode = Const*)  Put3(0, 15, x.a + 20H)
  END LDPSR;

  PROCEDURE LDREG*(VAR x, y: OXG.Item);
  BEGIN
    IF y.mode = O7B.Const THEN Put1a(Mov, x.a, 0, y.a)
    ELSE load(y); Put0(Mov, x.a, 0, y.r); DEC(RH)
    END
  END LDREG;

  (*In-line code functions*)

  PROCEDURE Abs*(VAR x: OXG.Item);
  BEGIN
    IF x.mode = O7B.Const THEN x.a := ABS(x.a)
    ELSE load(x);
      IF x.type.form = O7B.Real THEN Put1(Lsl, x.r, x.r, 1); Put1(Ror, x.r, x.r, 1)
      ELSE Put1(Cmp, x.r, x.r, 0); Put3(BC, GE, 2); Put1(Mov, RH, 0, 0); Put0(Sub, x.r, RH, x.r)
      END
    END
  END Abs;

  PROCEDURE Odd*(VAR x: OXG.Item);
  BEGIN load(x); Put1(And, x.r, x.r, 1); SetCC(x, NE); DEC(RH)
  END Odd;

  PROCEDURE Floor*(VAR x: OXG.Item);
  BEGIN load(x); Put1(Mov+U, RH, 0, 4B00H); Put0(Fad+1000H, x.r, x.r, RH) 
  END Floor;

  PROCEDURE Float*(VAR x: OXG.Item);
  BEGIN load(x); Put1(Mov+U, RH, 0, 4B00H);  Put0(Fad+U, x.r, x.r, RH)
  END Float;

  PROCEDURE Ord*(VAR x: OXG.Item);
  BEGIN
    IF x.mode IN {O7B.Var, O7B.Par, RegI} THEN load(x) END
  END Ord;

  PROCEDURE Len*(VAR x: OXG.Item);
  BEGIN
    IF x.type.len >= 0 THEN x.mode := O7B.Const; x.a := x.type.len
    ELSE (*open array*) Put2(Ldr, RH, SP, x.a + 4); x.mode := Reg; x.r := RH; incR
    END 
  END Len;

  PROCEDURE Shift*(fct: LONGINT; VAR x, y: OXG.Item);
    VAR op: LONGINT;
  BEGIN load(x);
    IF fct = 0 THEN op := Lsl ELSIF fct = 1 THEN op := Asr ELSE op := Ror END ;
    IF y.mode = O7B.Const THEN Put1(op, x.r, x.r, y.a MOD 20H)
    ELSE load(y); Put0(op, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
    END
  END Shift;

  PROCEDURE ADC*(VAR x, y: OXG.Item);
  BEGIN load(x); load(y); Put0(Add+2000H, x.r, x.r, y.r); DEC(RH)
  END ADC;

  PROCEDURE SBC*(VAR x, y: OXG.Item);
  BEGIN load(x); load(y); Put0(Sub+2000H, x.r, x.r, y.r); DEC(RH)
  END SBC;

  PROCEDURE UML*(VAR x, y: OXG.Item);
  BEGIN load(x); load(y); Put0(Mul+2000H, x.r, x.r, y.r); DEC(RH)
  END UML;

  PROCEDURE Bit*(VAR x, y: OXG.Item);
  BEGIN load(x); Put2(Ldr, x.r, x.r, 0);
    IF y.mode = O7B.Const THEN Put1(Ror, x.r, x.r, y.a+1); DEC(RH)
    ELSE load(y); Put1(Add, y.r, y.r, 1); Put0(Ror, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, MI)
  END Bit;

  PROCEDURE Register*(VAR x: OXG.Item);
  BEGIN (*x.mode = Const*)
    Put0(Mov, RH, 0, x.a MOD 10H); x.mode := Reg; x.r := RH; incR
  END Register;

  PROCEDURE H*(VAR x: OXG.Item);
  BEGIN (*x.mode = Const*)
    Put0(Mov + U + (x.a MOD 2 * 1000H), RH, 0, 0); x.mode := Reg; x.r := RH; incR
  END H;

  PROCEDURE Adr*(VAR x: OXG.Item);
  BEGIN 
    IF x.mode IN {O7B.Var, O7B.Par, RegI} THEN loadAdr(x)
    ELSIF (x.mode = O7B.Const) & (x.type.form = O7B.Proc) THEN load(x)
    ELSIF (x.mode = O7B.Const) & (x.type.form = O7B.String) THEN loadStringAdr(x)
    ELSE O7S.Mark("not addressable")
    END
  END Adr;

  PROCEDURE Condition*(VAR x: OXG.Item);
  BEGIN (*x.mode = Const*) SetCC(x, x.a)
  END Condition;

  PROCEDURE Open*(v: INTEGER);
  BEGIN pc := 0; tdx := 0; strx := 0; RH := 0; fixorgP := 0; fixorgD := 0; fixorgT := 0;
    check := v # 0; version := v; inhibitCalls := FALSE;
    IF v = 0 THEN pc := 8 END
  END Open;

  PROCEDURE SetDataSize*(dc: LONGINT);
  BEGIN varsize := dc
  END SetDataSize;

  PROCEDURE Header*;
  BEGIN entry := pc*4;
    IF version = 0 THEN code[0] := 0E7000000H-1 + pc; Put1(Mov, SB, 0, 16); Put1(Mov, SP, 0, StkOrg0)  (*RISC-0*)
    ELSE Put1(Sub, SP, SP, 4); Put2(Str, LNK, SP, 0); invalSB
    END
  END Header;

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
  END FindPtrs;

  PROCEDURE Close*(VAR modid: O7S.Ident; key, nofent: LONGINT);
    VAR obj: O7B.Object;
      i, comsize, nofimps, nofptrs, size: LONGINT;
      name: O7S.Ident;
      F: Files.File; R: Files.Rider;
  BEGIN  (*exit code*)
    IF version = 0 THEN Put1(Mov, 0, 0, 0); Put3(BR, 7, 0)  (*RISC-0*)
    ELSE Put2(Ldr, LNK, SP, 0); Put1(Add, SP, SP, 4); Put3(BR, 7, LNK)
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
    size := varsize + strx + comsize + (pc + nofimps + nofent + nofptrs + 1)*4;  (*varsize includes type descriptors*)

    O7B.MakeFileName(name, modid, ".a32"); (*write code file*)
    F := Files.New(name); Files.Set(R, F, 0); Files.WriteString(R, modid); Files.WriteInt(R, key); Files.WriteByte(R, version);
    Files.WriteInt(R, size);
    obj := O7B.topScope.next;
    WHILE (obj # NIL) & (obj.class = O7B.Mod) DO  (*imports*)
      IF obj.dsc # O7B.system THEN Files.WriteString(R, obj(O7B.Module).orgname); Files.WriteInt(R, obj.val) END ;
      obj := obj.next
    END ;
    Files.Write(R, 0X);
    Files.WriteInt(R, tdx*4);
    i := 0;
    WHILE i < tdx DO Files.WriteInt(R, data[i]); INC(i) END ; (*type descriptors*)
    Files.WriteInt(R, varsize - tdx*4);  (*data*)
    Files.WriteInt(R, strx);
    FOR i := 0 TO strx-1 DO Files.Write(R, str[i]) END ;  (*strings*)
    Files.WriteInt(R, pc);  (*code len*)
    FOR i := 0 TO pc-1 DO Files.WriteInt(R, code[i]) END ;  (*program*)
    obj := O7B.topScope.next;
    WHILE obj # NIL DO  (*commands*)
      IF (obj.exno # 0) & (obj.class = O7B.Const) & (obj.type.form = O7B.Proc) &
          (obj.type.nofpar = 0) & (obj.type.base = O7B.noType) THEN
        Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val)
      END ;
      obj := obj.next
    END ;
    Files.Write(R, 0X);
    Files.WriteInt(R, nofent); Files.WriteInt(R, entry);
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
      END ;
      obj := obj.next
    END ;
    obj := O7B.topScope.next;
    WHILE obj # NIL DO  (*pointer variables*)
      IF obj.class = O7B.Var THEN FindPtrs(R, obj.type, obj.val) END ;
      obj := obj.next
    END ;
    Files.WriteInt(R, -1);
    Files.WriteInt(R, fixorgP); Files.WriteInt(R, fixorgD); Files.WriteInt(R, fixorgT); Files.WriteInt(R, entry);
    Files.Write(R, "O"); Files.Register(F)
  END Close;

BEGIN
  relmap[0] := 1; relmap[1] := 9; relmap[2] := 5; relmap[3] := 6; relmap[4] := 14; relmap[5] := 13
END Oa32G.
