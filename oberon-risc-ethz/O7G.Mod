MODULE O7G; (* NW  10.10.2013 CP 8.14.2014 Retargetable code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, O7X, Or32G, Oa32G;
  (*Code generator for Oberon compiler for a generic processor. 
     Procedural interface to Parser O7P; result in array "code". 
     Procedure Close writes code-files*) 
 
  CONST WordSize* = 4; 
    StkOrg0 = -64; VarOrg0 = 0;  (*for RISC-0 only*) 
    MT = 27; SB = 28; SP = 29; LNK = 30; PC* = 31;   (*abstract registers*)
    (* MT = 12; SB = 13; SP = 14; LNK = 15; *)  (*dedicated registers*) 
    maxCode = 8000; maxstrx = 2400; maxTD = 120;  C24 = 1000000H; 
    Reg = 10; RegI = 11; Cond = 12;  (*internal item modes*) 
 
  (*frequently used opcodes*)  U = 2000H; 
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3; And = 4; Ann = 5; Ior = 6; Xor = 7; 
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11; 
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15; 
    Ldr = 0; Ldrb = 1; Str = 2; Strb = 3; 
    BR = 0; BLR = 1; BC = 2; BL = 3; 
    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14; AL = 7;
 
 
  (* Item forms and meaning of fields: 
    mode    r      a       b 
    -------------------------------- 
    Const   -     value (proc adr)   (immediate value) 
    Var     base   off     -               (direct adr) 
    Par      -     off0     off1         (indirect adr) 
    Reg    regno 
    RegI   regno   off     - 
    Cond  cond   Fchain  Tchain  *) 
 
  VAR      arch: CHAR;     T: O7X.Target;    PROCEDURE SetArch*( a : CHAR );
   BEGIN
     arch:=a;     IF arch = 0X THEN Or32G.SetArch(T); END ;     IF arch = 1X THEN Oa32G.SetArch(T); END; (*
     IF arch = 2X THEN Oi32G.SetArch(T); END *)   END SetArch;    (*instruction assemblers according to formats*) 
 
  PROCEDURE GetPC*(): LONGINT;
  BEGIN
    RETURN T.pc
  END GetPC;
 
  PROCEDURE incR; 
  BEGIN 
    IF T.RH < T.RX THEN INC(T.RH) ELSE O7S.Mark("register stack overflow") END 
  END incR; 
 
  PROCEDURE CheckRegs*; 
  BEGIN 
    IF T.RH # 0 THEN O7S.Mark("Reg Stack"); T.RH := 0 END ; 
    IF T.pc >= maxCode - 40 THEN O7S.Mark("Program too long"); END 
  END CheckRegs; 
 
  PROCEDURE SaveRegs(r: LONGINT); (* R[0 .. r-1] to be saved; R[r .. T.RH-1] to be moved down*) 
    VAR rs, rd: LONGINT;  (*r > 0*) 
  BEGIN rs := r; rd := 0; 
    REPEAT DEC(rs); T.PutOpRRI(T, 0, Sub, SP, SP, 4); T.PutOpLS(T, Str, rs, SP, 0) UNTIL rs = 0; 
    rs := r; rd := 0; 
    WHILE rs < T.RH DO T.PutOpRRR(T, 0, Mov, rd, 0, rs); INC(rs); INC(rd) END ; 
    T.RH := rd 
  END SaveRegs; 
 
  PROCEDURE RestoreRegs(r: LONGINT; VAR x: O7X.Item); (*R[0 .. r-1] to be restored*) 
    VAR rd: LONGINT;  (*r > 0*) 
  BEGIN T.PutOpRRR(T, 0, Mov, r, 0, 0); rd := 0; 
    REPEAT T.PutOpLS(T, Ldr, rd, SP, 0); T.PutOpRRI(T, 0, Add, SP, SP, 4); INC(rd) UNTIL rd = r 
  END RestoreRegs; 
 
  PROCEDURE SetCC(VAR x: O7X.Item; n: LONGINT); 
  BEGIN x.mode := Cond; x.a := 0; x.b := 0; x.r := n 
  END SetCC; 
 
  PROCEDURE Trap(cond, num: LONGINT);   VAR pos : LONGINT; 
  BEGIN pos := O7S.Pos();     T.PutOpBRR(T, BLR, cond, pos*100H + num*10H , MT) 
  END Trap; 
 
  (*handling of forward reference, fixups of branch addresses and constant tables*) 
 
  PROCEDURE negated(cond: LONGINT): LONGINT; 
  BEGIN 
    IF cond < 8 THEN cond := cond+8 ELSE cond := cond-8 END ; 
    RETURN cond 
  END negated; 
 
  PROCEDURE invalSB; 
  BEGIN T.invalSB(T) 
  END invalSB; 
 
(*  PROCEDURE fix(at, with: LONGINT); 
  BEGIN T.code[at] := T.code[at] DIV C24 * C24 + (with MOD C24) 
  END fix;  *)
 
  PROCEDURE FixLink*(L: LONGINT); 
  BEGIN T.FixLink(T, L) 
  END FixLink; 
 
  PROCEDURE FixLinkWith(L0, dst: LONGINT); 
  BEGIN T.FixLinkWith(T,L0,dst)
  END FixLinkWith; 
 
  PROCEDURE merged(L0, L1: LONGINT): LONGINT; 
    VAR L2, L3: LONGINT; 
  BEGIN  
    IF L0 # 0 THEN L3 := L0; 
      REPEAT L2 := L3; L3 := T.code[L2] MOD 40000H UNTIL L3 = 0; 
      T.code[L2] := T.code[L2] + L1; L1 := L0 
    END ; 
    RETURN L1 
  END merged; 
 
  (* loading of operands and addresses into registers *) 
 
  PROCEDURE GetSB(base: LONGINT); 
  BEGIN 
    IF (T.version # 0) & ((base # T.curSB) OR (base # 0)) THEN 
      T.PutOpLS(T, Ldr, SB, -base, T.pc-T.fixorgD); T.fixorgD := T.pc-1; T.curSB := base 
    END 
  END GetSB; 
 
  PROCEDURE NilCheck; 
  BEGIN IF T.check THEN Trap(EQ, 4) END 
  END NilCheck; 
 
  PROCEDURE load(VAR x: O7X.Item); 
    VAR op, ng: LONGINT; 
  BEGIN 
    IF x.type.size = 1 THEN op := Ldr+1 ELSE op := Ldr END ; 
    IF x.mode # Reg THEN 
      IF x.mode = O7B.Var THEN 
        IF x.r > 0 THEN (*local*) T.PutOpLS(T, op, T.RH, SP, x.a) 
        ELSE GetSB(x.r); T.PutOpLS(T, op, T.RH, SB, x.a) 
        END ; 
        x.r := T.RH; incR 
      ELSIF x.mode = O7B.Par THEN T.PutOpLS(T, Ldr, T.RH, SP, x.a); T.PutOpLS(T, op, T.RH, T.RH, x.b); x.r := T.RH; incR 
      ELSIF x.mode = O7B.Const THEN 
        IF x.type.form = O7B.Proc THEN 
          IF x.r > 0 THEN O7S.Mark("not allowed") 
          ELSIF x.r = 0 THEN T.PutOpBRI(T, BL, AL, 0); T.PutOpRRIa(T, Sub, T.RH, LNK, T.pc*4 - x.a) 
          ELSE GetSB(x.r); T.PutOpRRI(T, 0, Add, T.RH, SB, x.a + 100H) (*mark as progbase-relative*) 
          END 
        ELSIF (x.a <= 0FFFFH) & (x.a >= -10000H) THEN T.PutOpRRI(T, 0, Mov, T.RH, 0, x.a) 
        ELSE T.PutOpRRI(T, U, Mov, T.RH, 0, x.a DIV 10000H MOD 10000H); 
          IF x.a MOD 10000H # 0 THEN T.PutOpRRI(T, 0, Ior, T.RH, T.RH, x.a MOD 10000H) END 
        END ; 
        x.r := T.RH; incR 
      ELSIF x.mode = RegI THEN T.PutOpLS(T, op, x.r, x.r, x.a) 
      ELSIF x.mode = Cond THEN         ng := negated(x.r); 
        T.PutOpBRI(T, BC, ng, 2); 
        FixLink(x.b); T.PutOpRRI(T, 0, Mov, T.RH, 0, 1); T.PutOpBRI(T, BC, AL, 1); 
        FixLink(x.a); T.PutOpRRI(T, 0, Mov, T.RH, 0, 0); x.r := T.RH; incR 
      END ; 
      x.mode := Reg 
    END 
  END load; 
 
  PROCEDURE loadAdr(VAR x: O7X.Item); 
  BEGIN 
    IF x.mode = O7B.Var THEN 
      IF x.r > 0 THEN (*local*) T.PutOpRRIa(T, Add, T.RH, SP, x.a) 
      ELSE GetSB(x.r); T.PutOpRRIa(T, Add, T.RH, SB, x.a) 
      END ; 
      x.r := T.RH; incR 
    ELSIF x.mode = O7B.Par THEN T.PutOpLS(T, Ldr, T.RH, SP, x.a); 
      IF x.b # 0 THEN T.PutOpRRIa(T, Add, T.RH, T.RH, x.b) END ; 
      x.r := T.RH; incR 
    ELSIF x.mode = RegI THEN 
      IF x.a # 0 THEN T.PutOpRRIa(T, Add, x.r, x.r, x.a) END 
    ELSE O7S.Mark("address error")  
    END ; 
    x.mode := Reg 
  END loadAdr; 
 
  PROCEDURE loadCond(VAR x: O7X.Item); 
  BEGIN 
    IF x.type.form = O7B.Bool THEN 
      IF x.mode = O7B.Const THEN x.r := 15 - x.a*8 
      ELSE load(x); 
        IF T.code[T.pc-1] DIV 40000000H # -2 THEN T.PutOpRRI(T, 0, Cmp, x.r, x.r, 0) END ; 
        x.r := NE; DEC(T.RH) 
      END ; 
      x.mode := Cond; x.a := 0; x.b := 0 
    ELSE O7S.Mark("not Boolean?") 
    END 
  END loadCond; 
 
  PROCEDURE loadTypTagAdr(typ: O7B.Type); 
    VAR x: O7X.Item; 
  BEGIN x.mode := O7B.Var; x.a := typ.len; x.r := -typ.mno; loadAdr(x) 
  END loadTypTagAdr; 
 
  PROCEDURE loadStringAdr(VAR x: O7X.Item); 
  BEGIN GetSB(0); T.PutOpRRIa(T, Add, T.RH, SB, T.varsize+x.a); x.mode := Reg; x.r := T.RH; incR 
  END loadStringAdr; 
 
  (* Items: ConT.version from constants or from Objects on the Heap to Items on the Stack*) 
 
  PROCEDURE MakeConstItem*(VAR x: O7X.Item; typ: O7B.Type; val: LONGINT); 
  BEGIN x.mode := O7B.Const; x.type := typ; x.a := val 
  END MakeConstItem; 
 
  PROCEDURE MakeRealItem*(VAR x: O7X.Item; val: REAL); 
  BEGIN x.mode := O7B.Const; x.type := O7B.realType; x.a := SYSTEM.VAL(LONGINT, val) 
  END MakeRealItem; 
 
  PROCEDURE MakeStringItem*(VAR x: O7X.Item; len: LONGINT); (*copies string from O7S-buffer to ORG-string array*) 
    VAR i: LONGINT; 
  BEGIN x.mode := O7B.Const; x.type := O7B.strType; x.a := T.strx; x.b := len; i := 0; 
    IF T.strx + len + 4 < maxstrx THEN 
      WHILE len > 0 DO T.str[T.strx] := O7S.str[i]; INC(T.strx); INC(i); DEC(len) END ; 
      WHILE T.strx MOD 4 # 0 DO T.str[T.strx] := 0X; INC(T.strx) END 
    ELSE O7S.Mark("too many strings") 
    END 
  END MakeStringItem; 
 
  PROCEDURE MakeItem*(VAR x: O7X.Item; y: O7B.Object; curlev: LONGINT); 
  BEGIN x.mode := y.class; x.type := y.type; x.a := y.val; x.rdo := y.rdo; 
    IF y.class = O7B.Par THEN x.b := 0 
    ELSIF y.class = O7B.Typ THEN x.a := y.type.len; x.r := -y.lev 
    ELSIF (y.class = O7B.Const) & (y.type.form = O7B.String) THEN x.b := y.lev  (*len*) 
    ELSE x.r := y.lev 
    END ; 
    IF (y.lev > 0) & (y.lev # curlev) & (y.class # O7B.Const) THEN O7S.Mark("level error, not accessible") END 
  END MakeItem; 
 
  (* Code generation for Selectors, Variables, Constants *) 
 
  PROCEDURE Field*(VAR x: O7X.Item; y: O7B.Object);   (* x := x.y *) 
  BEGIN; 
    IF x.mode = O7B.Var THEN 
      IF x.r >= 0 THEN x.a := x.a + y.val 
      ELSE loadAdr(x); x.mode := RegI; x.a := y.val 
      END 
    ELSIF x.mode = RegI THEN x.a := x.a + y.val 
    ELSIF x.mode = O7B.Par THEN x.b := x.b + y.val 
    END 
  END Field; 
 
  PROCEDURE Index*(VAR x, y: O7X.Item);   (* x := x[y] *) 
    VAR s, lim: LONGINT; 
  BEGIN s := x.type.base.size; lim := x.type.len; 
    IF (y.mode = O7B.Const) & (lim >= 0) THEN 
      IF (y.a < 0) OR (y.a >= lim) THEN O7S.Mark("bad index") END ; 
      IF x.mode IN {O7B.Var, RegI} THEN x.a := y.a * s + x.a 
      ELSIF x.mode = O7B.Par THEN x.b := y.a * s + x.b 
      END 
    ELSE load(y); 
      IF T.check THEN  (*check array bounds*) 
        IF lim >= 0 THEN T.PutOpRRIa(T, Cmp, T.RH, y.r, lim) 
        ELSE (*open array*) 
          IF x.mode IN {O7B.Var, O7B.Par} THEN T.PutOpLS(T, Ldr, T.RH, SP, x.a+4); T.PutOpRRR(T, 0, Cmp, T.RH, y.r, T.RH) 
          ELSE O7S.Mark("error in Index") 
          END 
        END ; 
        Trap(10, 1) 
      END ; 
      IF s = 4 THEN T.PutOpRRI(T, 0, Lsl, y.r, y.r, 2) ELSIF s > 1 THEN T.PutOpRRI(T, 0, Mul, y.r, y.r, s) END ; 
      IF x.mode = O7B.Var THEN 
        IF x.r > 0 THEN T.PutOpRRR(T, 0, Add, y.r, SP, y.r) 
        ELSE GetSB(x.r); 
          IF x.r = 0 THEN T.PutOpRRR(T, 0, Add, y.r, SB, y.r) 
          ELSE T.PutOpRRIa(T, Add, T.RH, SB, x.a); T.PutOpRRR(T, 0, Add, y.r, T.RH, y.r); x.a := 0 
          END 
        END ; 
        x.r := y.r; x.mode := RegI 
      ELSIF x.mode = O7B.Par THEN 
        T.PutOpLS(T, Ldr, T.RH, SP, x.a); 
        T.PutOpRRR(T, 0, Add, y.r, T.RH, y.r); x.mode := RegI; x.r := y.r; x.a := x.b 
      ELSIF x.mode = RegI THEN T.PutOpRRR(T, 0, Add, x.r, x.r, y.r); DEC(T.RH) 
      END 
    END 
  END Index; 
 
  PROCEDURE DeRef*(VAR x: O7X.Item); 
  BEGIN 
    IF x.mode = O7B.Var THEN 
      IF x.r > 0 THEN (*local*) T.PutOpLS(T, Ldr, T.RH, SP, x.a) ELSE GetSB(x.r); T.PutOpLS(T, Ldr, T.RH, SB, x.a) END ; 
      NilCheck; x.r := T.RH; incR 
    ELSIF x.mode = O7B.Par THEN 
      T.PutOpLS(T, Ldr, T.RH, SP, x.a); T.PutOpLS(T, Ldr, T.RH, T.RH, x.b); NilCheck; x.r := T.RH; incR 
    ELSIF x.mode = RegI THEN T.PutOpLS(T, Ldr, x.r, x.r, x.a); NilCheck 
    ELSIF x.mode # Reg THEN O7S.Mark("bad mode in DeRef") 
    END ; 
    x.mode := RegI; x.a := 0; x.b := 0 
  END DeRef; 
 
  PROCEDURE Q(typ: O7B.Type; VAR dcw: LONGINT); 
  BEGIN (*one entry of type descriptor extension table*) 
    IF typ.base # NIL THEN 
      Q(typ.base, dcw); T.data[dcw] := (typ.mno*1000H + typ.len) * 1000H + dcw - T.fixorgT; 
      T.fixorgT := dcw; INC(dcw) 
    END 
  END Q; 
 
  PROCEDURE FindPtrFlds(typ: O7B.Type; off: LONGINT; VAR dcw: LONGINT); 
    VAR fld: O7B.Object; i, s: LONGINT; 
  BEGIN 
    IF (typ.form = O7B.Pointer) OR (typ.form = O7B.NilTyp) THEN T.data[dcw] := off; INC(dcw) 
    ELSIF typ.form = O7B.Record THEN 
      fld := typ.dsc; 
      WHILE fld # NIL DO FindPtrFlds(fld.type, fld.val + off, dcw); fld := fld.next END 
    ELSIF typ.form = O7B.Array THEN 
      s := typ.base.size; 
      FOR i := 0 TO typ.len-1 DO FindPtrFlds(typ.base, i*s + off, dcw) END 
    END 
  END FindPtrFlds; 
 
  PROCEDURE BuildTD*(typ: O7B.Type; VAR dc: LONGINT); 
    VAR dcw, k, s: LONGINT;  (*dcw = word address*) 
  BEGIN dcw := dc DIV 4; s := typ.size; (*convert size for heap allocation*) 
    IF s <= 24 THEN s := 32 ELSIF s <= 56 THEN s := 64 ELSIF s <= 120 THEN s := 128 
    ELSE s := (s+263) DIV 256 * 256 
    END ; 
    T.data[dcw] := s; INC(dcw); 
    k := typ.nofpar;   (*extension level!*) 
    IF k > 3 THEN O7S.Mark("ext level too large") 
    ELSE Q(typ, dcw); 
      WHILE k < 3 DO T.data[dcw] := -1; INC(dcw); INC(k) END 
    END ; 
    FindPtrFlds(typ, 0, dcw); T.data[dcw] := -1; INC(dcw); T.tdx := dcw; dc := dcw*4; 
    IF T.tdx >= maxTD THEN O7S.Mark("too many record types"); T.tdx := 0 END 
  END BuildTD; 
 
  PROCEDURE TypeTest*(VAR x: O7X.Item; typ: O7B.Type; varpar, isguard: BOOLEAN); 
  BEGIN (*fetch tag into T.RH*) 
    IF varpar THEN T.PutOpLS(T, Ldr, T.RH, SP, x.a+4) 
    ELSE load(x); NilCheck; T.PutOpLS(T, Ldr, T.RH, x.r, -8) 
    END ; 
    T.PutOpLS(T, Ldr, T.RH, T.RH, typ.nofpar*4); incR; 
    loadTypTagAdr(typ);  (*tag of typ*) 
    T.PutOpRRR(T, 0, Cmp, T.RH, T.RH-1, T.RH-2); DEC(T.RH, 2); 
    IF isguard THEN 
      IF T.check THEN Trap(NE, 2) END 
    ELSE SetCC(x, EQ); 
      IF ~varpar THEN DEC(T.RH) END 
    END 
  END TypeTest; 
 
  (* Code generation for Boolean operators *) 
 
  PROCEDURE Not*(VAR x: O7X.Item);   (* x := ~x *) 
    VAR t: LONGINT; 
  BEGIN 
    IF x.mode # Cond THEN loadCond(x) END ; 
    x.r := negated(x.r); t := x.a; x.a := x.b; x.b := t 
  END Not; 
 
  PROCEDURE And1*(VAR x: O7X.Item);   (* x := x & *)   VAR ng : LONGINT; 
  BEGIN 
    IF x.mode # Cond THEN loadCond(x) END ;     ng := negated(x.r); 
    T.PutOpBRI(T, BC, ng, x.a); x.a := T.pc-1; FixLink(x.b); x.b := 0 
  END And1; 
 
  PROCEDURE And2*(VAR x, y: O7X.Item); 
  BEGIN 
    IF y.mode # Cond THEN loadCond(y) END ; 
    x.a := merged(y.a, x.a); x.b := y.b; x.r := y.r 
  END And2; 
 
  PROCEDURE Or1*(VAR x: O7X.Item);   (* x := x OR *) 
  BEGIN 
    IF x.mode # Cond THEN loadCond(x) END ; 
    T.PutOpBRI(T, BC, x.r, x.b);  x.b := T.pc-1; FixLink(x.a); x.a := 0 
  END Or1; 
 
  PROCEDURE Or2*(VAR x, y: O7X.Item); 
  BEGIN 
    IF y.mode # Cond THEN loadCond(y) END ; 
    x.a := y.a; x.b := merged(y.b, x.b); x.r := y.r 
  END Or2; 
 
  (* Code generation for arithmetic operators *) 
 
  PROCEDURE Neg*(VAR x: O7X.Item);   (* x := -x *) 
  BEGIN 
    IF x.type.form = O7B.Int THEN 
      IF x.mode = O7B.Const THEN x.a := -x.a 
      ELSE load(x); T.PutOpRRI(T, 0, Mov, T.RH, 0, 0); T.PutOpRRR(T, 0, Sub, x.r, T.RH, x.r) 
      END 
    ELSIF x.type.form = O7B.Real THEN 
      IF x.mode = O7B.Const THEN x.a := x.a + 7FFFFFFFH + 1 
      ELSE load(x); T.PutOpRRI(T, 0, Mov, T.RH, 0, 0); T.PutOpRRR(T, 0, Fsb, x.r, T.RH, x.r) 
      END 
    ELSE (*form = Set*) 
      IF x.mode = O7B.Const THEN x.a := -x.a-1  
      ELSE load(x); T.PutOpRRI(T, 0, Xor, x.r, x.r, -1) 
      END 
    END 
  END Neg; 
 
  PROCEDURE AddOp*(op: LONGINT; VAR x, y: O7X.Item);   (* x := x +- y *) 
  BEGIN 
    IF op = O7S.plus THEN 
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN x.a := x.a + y.a 
      ELSIF y.mode = O7B.Const THEN load(x); 
        IF y.a # 0 THEN T.PutOpRRIa(T, Add, x.r, x.r, y.a) END 
      ELSE load(x); load(y); T.PutOpRRR(T, 0, Add, T.RH-2, x.r, y.r); DEC(T.RH); x.r := T.RH-1 
      END 
    ELSE (*op = O7S.minus*) 
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN x.a := x.a - y.a 
      ELSIF y.mode = O7B.Const THEN load(x); 
        IF y.a # 0 THEN T.PutOpRRIa(T, Sub, x.r, x.r, y.a) END 
      ELSE load(x); load(y); T.PutOpRRR(T, 0, Sub, T.RH-2, x.r, y.r); DEC(T.RH); x.r := T.RH-1 
      END 
    END 
  END AddOp; 
 
  PROCEDURE log2(m: LONGINT; VAR e: LONGINT): LONGINT; 
  BEGIN e := 0; 
    WHILE ~ODD(m) DO m := m DIV 2; INC(e) END ; 
    RETURN m 
  END log2; 
   
  PROCEDURE MulOp*(VAR x, y: O7X.Item);   (* x := x * y *) 
    VAR e: LONGINT; 
  BEGIN 
    IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN x.a := x.a * y.a 
    ELSIF (y.mode = O7B.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); T.PutOpRRI(T, 0, Lsl, x.r, x.r, e) 
    ELSIF y.mode = O7B.Const THEN load(x); T.PutOpRRIa(T, Mul, x.r, x.r, y.a) 
    ELSIF (x.mode = O7B.Const) & (x.a >= 2) & (log2(x.a, e) = 1) THEN load(y); T.PutOpRRI(T, 0, Lsl, y.r, y.r, e); x.mode := Reg; x.r := y.r 
    ELSIF x.mode = O7B.Const THEN load(y); T.PutOpRRIa(T, Mul, y.r, y.r, x.a); x.mode := Reg; x.r := y.r 
    ELSE load(x); load(y); T.PutOpRRR(T, 0, Mul, T.RH-2, x.r, y.r); DEC(T.RH); x.r := T.RH-1 
    END 
  END MulOp; 
 
  PROCEDURE DivOp*(op: LONGINT; VAR x, y: O7X.Item);   (* x := x op y *) 
    VAR e: LONGINT; 
  BEGIN 
    IF op = O7S.div THEN 
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN 
        IF y.a > 0 THEN x.a := x.a DIV y.a ELSE O7S.Mark("bad divisor") END 
      ELSIF (y.mode = O7B.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); T.PutOpRRI(T, 0, Asr, x.r, x.r, e) 
      ELSIF y.mode = O7B.Const THEN 
        IF y.a > 0 THEN load(x); T.PutOpRRIa(T, Div, x.r, x.r, y.a) ELSE O7S.Mark("bad divisor") END 
      ELSE load(y); 
        IF T.check THEN Trap(LE, 6) END ; 
        load(x); T.PutOpRRR(T, 0, Div, T.RH-2, x.r, y.r); DEC(T.RH); x.r := T.RH-1 
      END 
    ELSE (*op = O7S.mod*) 
      IF (x.mode = O7B.Const) & (y.mode = O7B.Const) THEN 
        IF y.a > 0 THEN x.a := x.a MOD y.a ELSE O7S.Mark("bad modulus") END 
      ELSIF (y.mode = O7B.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); 
        IF e <= 16 THEN T.PutOpRRI(T, 0, And, x.r, x.r, y.a-1) ELSE T.PutOpRRI(T, 0, Lsl, x.r, x.r, 32-e); T.PutOpRRI(T, 0, Ror, x.r, x.r, 32-e) END 
      ELSIF y.mode = O7B.Const THEN 
        IF y.a > 0 THEN load(x); T.PutOpRRIa(T, Div, x.r, x.r, y.a); T.PutOpRRR(T, U, Mov, x.r, 0, 0) ELSE O7S.Mark("bad modulus") END 
      ELSE load(y); 
        IF T.check THEN Trap(LE, 6) END ; 
        load(x); T.PutOpRRR(T, 0, Div, T.RH-2, x.r, y.r); T.PutOpRRR(T, U, Mov, T.RH-2, 0, 0); DEC(T.RH); x.r := T.RH-1 
      END 
    END 
  END DivOp; 
 
  (* Code generation for REAL operators *) 
 
  PROCEDURE RealOp*(op: INTEGER; VAR x, y: O7X.Item);   (* x := x op y *) 
  BEGIN load(x); load(y); 
    IF op = O7S.plus THEN T.PutOpRRR(T, 0, Fad, T.RH-2, x.r, y.r) 
    ELSIF op = O7S.minus THEN T.PutOpRRR(T, 0, Fsb, T.RH-2, x.r, y.r) 
    ELSIF op = O7S.times THEN T.PutOpRRR(T, 0, Fml, T.RH-2, x.r, y.r) 
    ELSIF op = O7S.rdiv THEN T.PutOpRRR(T, 0, Fdv, T.RH-2, x.r, y.r) 
    END ; 
    DEC(T.RH); x.r := T.RH-1 
  END RealOp; 
 
  (* Code generation for set operators *) 
 
  PROCEDURE Singleton*(VAR x: O7X.Item);  (* x := {x} *) 
  BEGIN 
    IF x.mode = O7B.Const THEN x.a := LSL(1, x.a) 
    ELSE load(x); T.PutOpRRI(T, 0, Mov, T.RH, 0, 1); T.PutOpRRR(T, 0, Lsl, x.r, T.RH,  x.r) 
    END 
  END Singleton; 
 
  PROCEDURE Set*(VAR x, y: O7X.Item);   (* x := {x .. y} *) 
  BEGIN 
    IF (x.mode = O7B.Const) & ( y.mode = O7B.Const) THEN 
      IF x.a <= y.a THEN x.a := LSL(2, y.a) - LSL(1, x.a) ELSE x.a := 0 END 
    ELSE 
      IF (x.mode = O7B.Const) & (x.a < 10H) THEN x.a := LSL(-1, x.a) 
      ELSE load(x); T.PutOpRRI(T, 0, Mov, T.RH, 0, -1); T.PutOpRRR(T, 0, Lsl, x.r, T.RH, x.r) 
      END ; 
      IF (y.mode = O7B.Const) & (y.a < 10H) THEN T.PutOpRRI(T, 0, Mov, T.RH, 0, LSL(-2, y.a)); y.mode := Reg; y.r := T.RH; INC(T.RH) 
      ELSE load(y); T.PutOpRRI(T, 0, Mov, T.RH, 0, -2); T.PutOpRRR(T, 0, Lsl, y.r, T.RH, y.r) 
      END ; 
      IF x.mode = O7B.Const THEN 
        IF x.a # 0 THEN T.PutOpRRI(T, 0, Xor, y.r, y.r, -1); T.PutOpRRIa(T, And, T.RH-1, y.r, x.a) END ; 
        x.mode := Reg; x.r := T.RH-1 
      ELSE DEC(T.RH); T.PutOpRRR(T, 0, Ann, T.RH-1, x.r, y.r) 
      END 
    END 
  END Set; 
 
  PROCEDURE In*(VAR x, y: O7X.Item);  (* x := x IN y *) 
  BEGIN load(y); 
    IF x.mode = O7B.Const THEN T.PutOpRRI(T, 0, Ror, y.r, y.r, (x.a + 1) MOD 20H); DEC(T.RH) 
    ELSE load(x); T.PutOpRRI(T, 0, Add, x.r, x.r, 1); T.PutOpRRR(T, 0, Ror, y.r, y.r, x.r); DEC(T.RH, 2) 
    END ; 
    SetCC(x, MI) 
  END In; 
 
  PROCEDURE SetOp*(op: LONGINT; VAR x, y: O7X.Item);   (* x := x op y *) 
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
      IF op = O7S.plus THEN T.PutOpRRIa(T, Ior, x.r, x.r, y.a) 
      ELSIF op = O7S.minus THEN T.PutOpRRIa(T, Ann, x.r, x.r, y.a) 
      ELSIF op = O7S.times THEN T.PutOpRRIa(T, And, x.r, x.r, y.a) 
      ELSIF op = O7S.rdiv THEN T.PutOpRRIa(T, Xor, x.r, x.r, y.a) 
      END ; 
    ELSE load(x); load(y); 
      IF op = O7S.plus THEN T.PutOpRRR(T, 0, Ior, T.RH-2, x.r, y.r) 
      ELSIF op = O7S.minus THEN T.PutOpRRR(T, 0, Ann, T.RH-2, x.r, y.r) 
      ELSIF op = O7S.times THEN T.PutOpRRR(T, 0, And, T.RH-2, x.r, y.r) 
      ELSIF op = O7S.rdiv THEN T.PutOpRRR(T, 0, Xor, T.RH-2, x.r, y.r) 
      END ; 
      DEC(T.RH); x.r := T.RH-1 
    END  
  END SetOp; 
 
  (* Code generation for relations *) 
 
  PROCEDURE IntRelation*(op: INTEGER; VAR x, y: O7X.Item);   (* x := x < y *) 
  BEGIN 
    IF (y.mode = O7B.Const) & (y.type.form # O7B.Proc) THEN 
      load(x); 
      IF (y.a # 0) OR ~(op IN {O7S.eql, O7S.neq}) OR (T.code[T.pc-1] DIV 40000000H # -2) THEN T.PutOpRRIa(T, Cmp, x.r, x.r, y.a) END ; 
      DEC(T.RH) 
    ELSE load(x); load(y); T.PutOpRRR(T, 0, Cmp, x.r, x.r, y.r); DEC(T.RH, 2) 
    END ; 
    SetCC(x, T.relmap[op - O7S.eql]) 
  END IntRelation; 
 
  PROCEDURE SetRelation*(op: INTEGER; VAR x, y: O7X.Item);   (* x := x < y *) 
  BEGIN load(x); 
    IF (op = O7S.eql) OR (op = O7S.neq) THEN 
      IF y.mode = O7B.Const THEN T.PutOpRRIa(T, Cmp, x.r, x.r, y.a); DEC(T.RH) 
      ELSE load(y); T.PutOpRRR(T, 0, Cmp, x.r, x.r, y.r); DEC(T.RH, 2) 
      END ; 
      SetCC(x, T.relmap[op - O7S.eql]) 
    ELSE O7S.Mark("illegal relation")  
    END 
  END SetRelation; 
 
  PROCEDURE RealRelation*(op: INTEGER; VAR x, y: O7X.Item);   (* x := x < y *) 
  BEGIN load(x); 
    IF (y.mode = O7B.Const) & (y.a = 0) THEN DEC(T.RH) 
    ELSE load(y); T.PutOpRRR(T, 0, Fsb, x.r, x.r, y.r); DEC(T.RH, 2) 
    END ; 
    SetCC(x, T.relmap[op - O7S.eql]) 
  END RealRelation; 
 
  PROCEDURE StringRelation*(op: INTEGER; VAR x, y: O7X.Item);   (* x := x < y *) 
    (*x, y are char arrays or strings*) 
  BEGIN 
    IF x.type.form = O7B.String THEN loadStringAdr(x) ELSE loadAdr(x) END ; 
    IF y.type.form = O7B.String THEN loadStringAdr(y) ELSE loadAdr(y) END ; 
    T.PutOpLS(T, Ldr+1, T.RH, x.r, 0); T.PutOpRRI(T, 0, Add, x.r, x.r, 1); 
    T.PutOpLS(T, Ldr+1, T.RH+1, y.r, 0); T.PutOpRRI(T, 0, Add, y.r, y.r, 1); 
    T.PutOpRRR(T, 0, Cmp, T.RH+2, T.RH, T.RH+1); T.PutOpBRI(T, BC, NE, 2); 
    T.PutOpRRI(T, 0, Cmp, T.RH+2, T.RH, 0); T.PutOpBRI(T, BC, NE, -8); 
    DEC(T.RH, 2); SetCC(x, T.relmap[op - O7S.eql]) 
  END StringRelation; 
 
  (* Code generation of Assignments *) 
 
  PROCEDURE StrToChar*(VAR x: O7X.Item); 
  BEGIN x.type := O7B.charType; DEC(T.strx, 4); x.a := ORD(T.str[x.a]) 
  END StrToChar; 
 
  PROCEDURE Store*(VAR x, y: O7X.Item); (* x := y *) 
    VAR op: LONGINT; 
  BEGIN  load(y); 
    IF x.type.size = 1 THEN op := Str+1 ELSE op := Str END ; 
    IF x.mode = O7B.Var THEN 
      IF x.r > 0 THEN (*local*) T.PutOpLS(T, op, y.r, SP, x.a) 
      ELSE GetSB(x.r); T.PutOpLS(T, op, y.r, SB, x.a) 
      END 
    ELSIF x.mode = O7B.Par THEN T.PutOpLS(T, Ldr, T.RH, SP, x.a); T.PutOpLS(T, op, y.r, T.RH, x.b); 
    ELSIF x.mode = RegI THEN T.PutOpLS(T, op, y.r, x.r, x.a); DEC(T.RH); 
    ELSE O7S.Mark("bad mode in Store") 
    END ; 
    DEC(T.RH) 
  END Store; 
 
  PROCEDURE StoreStruct*(VAR x, y: O7X.Item); (* x := y *) 
    VAR s, pc0: LONGINT; 
  BEGIN loadAdr(x); loadAdr(y); 
    IF (x.type.form = O7B.Array) & (x.type.len > 0) THEN 
      IF y.type.len >= 0 THEN  
        IF x.type.len >= y.type.len THEN T.PutOpRRI(T, 0, Mov, T.RH, 0, (y.type.size+3) DIV 4) 
        ELSE O7S.Mark("source array too long") 
        END 
      ELSE (*y is open array*) 
        T.PutOpLS(T, Ldr, T.RH, SP, y.a+4); s := y.type.base.size;  (*element size*) 
        pc0 := T.pc; T.PutOpBRI(T, BC, EQ, 0); 
        IF s = 1 THEN T.PutOpRRI(T, 0, Add, T.RH, T.RH, 3); T.PutOpRRI(T, 0, Asr, T.RH, T.RH, 2) 
        ELSIF s # 4 THEN T.PutOpRRI(T, 0, Mul, T.RH, T.RH, s DIV 4) 
        END ; 
        IF T.check THEN 
          T.PutOpRRI(T, 0, Mov, T.RH+1, 0, (x.type.size+3) DIV 4); T.PutOpRRR(T, 0, Cmp, T.RH+1, T.RH, T.RH+1); Trap(GT, 3) 
        END ; 
        T.fix(T,pc0, T.pc + 5 - pc0) 
      END 
    ELSIF x.type.form = O7B.Record THEN T.PutOpRRI(T, 0, Mov, T.RH, 0, x.type.size DIV 4) 
    ELSE O7S.Mark("inadmissible assignment") 
    END ; 
    T.PutOpLS(T, Ldr, T.RH+1, y.r, 0); T.PutOpRRI(T, 0, Add, y.r, y.r, 4); 
    T.PutOpLS(T, Str, T.RH+1, x.r, 0); T.PutOpRRI(T, 0, Add, x.r, x.r, 4); 
    T.PutOpRRI(T, 0, Sub, T.RH, T.RH, 1); T.PutOpBRI(T, BC, NE, -6); DEC(T.RH, 2) 
  END StoreStruct; 
 
  PROCEDURE CopyString*(VAR x, y: O7X.Item);  (*from x to y*) 
    VAR len: LONGINT; 
  BEGIN loadAdr(y); len := y.type.len; 
    IF len >= 0 THEN 
      IF x.b > len THEN O7S.Mark("string too long") END 
    ELSIF T.check THEN T.PutOpLS(T, Ldr, T.RH, y.r, 4);  (*array length check*) 
      T.PutOpRRI(T, 0, Cmp, T.RH, T.RH, x.b); Trap(NE, 3) 
    END ; 
    loadStringAdr(x); 
    T.PutOpLS(T, Ldr, T.RH, x.r, 0); T.PutOpRRI(T, 0, Add, x.r, x.r, 4); 
    T.PutOpLS(T, Str, T.RH, y.r, 0); T.PutOpRRI(T, 0, Add, y.r, y.r, 4); 
    T.PutOpRRI(T, 0, Asr, T.RH, T.RH, 24); T.PutOpBRI(T, BC, NE, -6); DEC(T.RH, 2) 
  END CopyString; 
 
  (* Code generation for parameters *) 
   
  PROCEDURE VarParam*(VAR x: O7X.Item; ftype: O7B.Type); 
    VAR xmd: INTEGER; 
  BEGIN xmd := x.mode; loadAdr(x); 
    IF (ftype.form = O7B.Array) & (ftype.len < 0) THEN (*open array*) 
      IF x.type.len >= 0 THEN T.PutOpRRI(T, 0, Mov, T.RH, 0, x.type.len) ELSE  T.PutOpLS(T, Ldr, T.RH, SP, x.a+4) END ; 
      incR 
    ELSIF ftype.form = O7B.Record THEN 
      IF xmd = O7B.Par THEN T.PutOpLS(T, Ldr, T.RH, SP, x.a+4); incR ELSE loadTypTagAdr(x.type) END 
    END 
  END VarParam; 
 
  PROCEDURE ValueParam*(VAR x: O7X.Item); 
  BEGIN load(x) 
  END ValueParam; 
 
  PROCEDURE OpenArrayParam*(VAR x: O7X.Item); 
  BEGIN loadAdr(x); 
    IF x.type.len >= 0 THEN T.PutOpRRIa(T, Mov, T.RH, 0, x.type.len) ELSE T.PutOpLS(T, Ldr, T.RH, SP, x.a+4) END ; 
    incR 
  END OpenArrayParam; 
 
  PROCEDURE StringParam*(VAR x: O7X.Item); 
  BEGIN loadStringAdr(x); T.PutOpRRI(T, 0, Mov, T.RH, 0, x.b); incR  (*len*) 
  END StringParam; 
 
  (*For Statements*) 
 
  PROCEDURE For0*(VAR x, y: O7X.Item); 
  BEGIN load(y) 
  END For0; 
 
  PROCEDURE For1*(VAR x, y, z, w: O7X.Item; VAR L: LONGINT); 
  BEGIN  
    IF z.mode = O7B.Const THEN T.PutOpRRIa(T, Cmp, T.RH, y.r, z.a) 
    ELSE load(z); T.PutOpRRR(T, 0, Cmp, T.RH-1, y.r, z.r); DEC(T.RH) 
    END ; 
    L := T.pc; 
    IF w.a > 0 THEN T.PutOpBRI(T, BC, GT, 0) 
    ELSIF w.a < 0 THEN T.PutOpBRI(T, BC, LT, 0) 
    ELSE O7S.Mark("zero increment"); T.PutOpBRI(T, BC, MI, 0) 
    END ; 
    Store(x, y) 
  END For1; 
 
  PROCEDURE For2*(VAR x, y, w: O7X.Item); 
  BEGIN load(x); DEC(T.RH); T.PutOpRRIa(T, Add, x.r, x.r, w.a) 
  END For2; 
 
  (* Branches, procedure calls, procedure prolog and epilog *) 
 
  PROCEDURE Here*(): LONGINT; 
  BEGIN invalSB; RETURN T.pc 
  END Here; 
 
  PROCEDURE FJump*(VAR L: LONGINT); 
  BEGIN T.PutOpBRI(T, BC, AL, L); L := T.pc-1 
  END FJump; 
 
  PROCEDURE CFJump*(VAR x: O7X.Item);   VAR ng : LONGINT; 
  BEGIN 
    IF x.mode # Cond THEN loadCond(x) END ;     ng := negated(x.r); 
    T.PutOpBRI(T, BC, ng, x.a); FixLink(x.b); x.a := T.pc-1 
  END CFJump; 
 
  PROCEDURE BJump*(L: LONGINT); 
  BEGIN T.PutOpBRI(T, BC, AL, L-T.pc-1) 
  END BJump; 
 
  PROCEDURE CBJump*(VAR x: O7X.Item; L: LONGINT);   VAR ng : LONGINT; 
  BEGIN 
    IF x.mode # Cond THEN loadCond(x) END ;     ng := negated(x.r); 
    T.PutOpBRI(T, BC, ng, L-T.pc-1); FixLink(x.b); FixLinkWith(x.a, L) 
  END CBJump; 
 
  PROCEDURE Fixup*(VAR x: O7X.Item); 
  BEGIN FixLink(x.a) 
  END Fixup; 
 
  PROCEDURE PrepCall*(VAR x: O7X.Item; VAR r: LONGINT); 
  BEGIN 
    IF x.type.form = O7B.Proc THEN 
      IF x.mode # O7B.Const THEN 
        load(x); T.code[T.pc-1] := T.code[T.pc-1] + 0B000000H; x.r := 11; DEC(T.RH); T.inhibitCalls := TRUE; 
        IF T.check THEN Trap(EQ, 5) END 
      END 
    ELSE O7S.Mark("not a procedure") 
    END ; 
    r := T.RH 
  END PrepCall; 
 
  PROCEDURE Call*(VAR x: O7X.Item; r: LONGINT); 
  BEGIN 
    IF T.inhibitCalls & (x.r # 11) THEN O7S.Mark("inadmissible call") ELSE T.inhibitCalls := FALSE END ; 
    IF r > 0 THEN SaveRegs(r) END ; 
    IF x.type.form = O7B.Proc THEN 
      IF x.mode = O7B.Const THEN 
        IF x.r >= 0 THEN T.PutOpBRI(T, BL, AL, (x.a DIV 4)-T.pc-1) 
        ELSE (*imported*) 
          IF T.pc - T.fixorgP < 1000H THEN 
            T.PutOpBRI(T, BL, AL, ((-x.r) * 100H + x.a) * 1000H + T.pc-T.fixorgP); T.fixorgP := T.pc-1 
          ELSE O7S.Mark("fixup impossible") 
          END 
        END 
      ELSE T.PutOpBRR(T, BLR, AL, 0, x.r) 
      END 
    ELSE O7S.Mark("not a procedure") 
    END ; 
    IF x.type.base.form = O7B.NoTyp THEN T.RH := 0 
    ELSE 
      IF r > 0 THEN RestoreRegs(r, x) END ; 
      x.mode := Reg; x.r := r; T.RH := r+1 
    END ; 
    invalSB 
  END Call; 
 
  PROCEDURE Enter*(parblksize, locblksize: LONGINT; int: BOOLEAN); 
    VAR a, r: LONGINT; 
  BEGIN invalSB; 
    IF ~int THEN (*procedure prolog*) 
      a := 4; r := 0; 
      T.PutOpRRI(T, 0, Sub, SP, SP, locblksize); T.PutOpLS(T, Str, LNK, SP, 0); 
      WHILE a < parblksize DO T.PutOpLS(T, Str, r, SP, a); INC(r); INC(a, 4) END 
    ELSE (*interrupt procedure*) 
      T.PutOpRRI(T, 0, Sub, SP, SP, 8); T.PutOpLS(T, Str, 0, SP, 0); T.PutOpLS(T, Str, 1, SP, 4) 
      (*R0 and R1 saved, but NOT LNK*) 
    END 
  END Enter; 
 
  PROCEDURE Return*(form: INTEGER; VAR x: O7X.Item; size: LONGINT; int: BOOLEAN); 
  BEGIN 
    IF form # O7B.NoTyp THEN load(x) END ; 
    IF ~int THEN (*procedure epilog*) 
      T.PutOpLS(T, Ldr, LNK, SP, 0); T.PutOpRRI(T, 0, Add, SP, SP, size); T.PutOpBRR(T, BR, AL, 0, LNK) 
    ELSE (*interrupt*) 
      T.PutOpLS(T, Ldr, 1, SP, 4); T.PutOpLS(T, Ldr, 0, SP, 0); T.PutOpRRI(T, 0, Add, SP, SP, 8); T.PutOpBRI(T, BR, AL, 10H) 
    END ; 
    T.RH := 0 
  END Return; 
 
  (* In-line code procedures*) 
 
  PROCEDURE Increment*(upordown: LONGINT; VAR x, y: O7X.Item); 
    VAR op, zr, v: LONGINT; 
  BEGIN 
    IF upordown = 0 THEN op := Add ELSE op := Sub END ; 
    IF x.type = O7B.byteType THEN v := 1 ELSE v := 0 END ; 
    IF y.type.form = O7B.NoTyp THEN y.mode := O7B.Const; y.a := 1 END ; 
    IF (x.mode = O7B.Var) & (x.r > 0) THEN 
      zr := T.RH; T.PutOpLS(T, Ldr+v, zr, SP, x.a); incR; 
      IF y.mode = O7B.Const THEN T.PutOpRRI(T, 0, op, zr, zr, y.a) ELSE load(y); T.PutOpRRR(T, 0, op, zr, zr, y.r); DEC(T.RH) END ; 
      T.PutOpLS(T, Str+v, zr, SP, x.a); DEC(T.RH) 
    ELSE loadAdr(x); zr := T.RH; T.PutOpLS(T, Ldr+v, T.RH, x.r, 0); incR; 
      IF y.mode = O7B.Const THEN T.PutOpRRI(T, 0, op, zr, zr, y.a) ELSE load(y); T.PutOpRRR(T, 0, op, zr, zr, y.r); DEC(T.RH) END ; 
      T.PutOpLS(T, Str+v, zr, x.r, 0); DEC(T.RH, 2) 
    END 
  END Increment; 
 
  PROCEDURE Include*(inorex: LONGINT; VAR x, y: O7X.Item); 
    VAR zr: LONGINT; 
  BEGIN loadAdr(x); zr := T.RH; T.PutOpLS(T, Ldr, T.RH, x.r, 0); incR; 
    IF inorex = 0 THEN (*include*) 
      IF y.mode = O7B.Const THEN T.PutOpRRI(T, 0, Ior, zr, zr, LSL(1, y.a)) 
      ELSE load(y); T.PutOpRRI(T, 0, Mov, T.RH, 0, 1); T.PutOpRRR(T, 0, Lsl, y.r, T.RH, y.r); T.PutOpRRR(T, 0, Ior, zr, zr, y.r); DEC(T.RH) 
      END 
    ELSE (*exclude*) 
      IF y.mode = O7B.Const THEN T.PutOpRRI(T, 0, And, zr, zr, -LSL(1, y.a)-1) 
      ELSE load(y); T.PutOpRRI(T, 0, Mov, T.RH, 0, 1); T.PutOpRRR(T, 0, Lsl, y.r, T.RH, y.r); T.PutOpRRI(T, 0, Xor, y.r, y.r, -1); T.PutOpRRR(T, 0, And, zr, zr, y.r); DEC(T.RH) 
      END 
    END ; 
    T.PutOpLS(T, Str, zr, x.r, 0); DEC(T.RH, 2) 
  END Include; 
 
  PROCEDURE Assert*(VAR x: O7X.Item); 
    VAR cond: LONGINT; 
  BEGIN 
    IF x.mode # Cond THEN loadCond(x) END ; 
    IF x.a = 0 THEN cond := negated(x.r) 
    ELSE T.PutOpBRI(T, BC, x.r, x.b); FixLink(x.a); x.b := T.pc-1; cond := 7 
    END ; 
    Trap(cond, 7); FixLink(x.b) 
  END Assert;  
 
  PROCEDURE New*(VAR x: O7X.Item); 
  BEGIN loadAdr(x); loadTypTagAdr(x.type.base); T.PutOpBRR(T, BLR, AL, 0, MT); T.RH := 0; invalSB 
  END New; 
 
  PROCEDURE Pack*(VAR x, y: O7X.Item); 
    VAR z: O7X.Item; 
  BEGIN z := x; load(x); load(y); 
    T.PutOpRRI(T, 0, Lsl, y.r, y.r, 23); T.PutOpRRR(T, 0, Add, x.r, x.r, y.r); DEC(T.RH); Store(z, x) 
  END Pack; 
 
  PROCEDURE Unpk*(VAR x, y: O7X.Item); 
    VAR z, e0: O7X.Item; 
  BEGIN  z := x; load(x); e0.mode := Reg; e0.r := T.RH; e0.type := O7B.intType; 
    T.PutOpRRI(T, 0, Asr, T.RH, x.r, 23); T.PutOpRRI(T, 0, Sub, T.RH, T.RH, 127); Store(y, e0); incR; 
    T.PutOpRRI(T, 0, Lsl, T.RH, T.RH, 23); T.PutOpRRR(T, 0, Sub, x.r, x.r, T.RH); Store(z, x) 
  END Unpk; 
 
  PROCEDURE Led*(VAR x: O7X.Item); 
  BEGIN load(x); T.PutOpRRI(T, 0, Mov, T.RH, 0, -60); T.PutOpLS(T, Str, x.r, T.RH, 0); DEC(T.RH) 
  END Led; 
 
  PROCEDURE Get*(VAR x, y: O7X.Item); 
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(y, x) 
  END Get; 
 
  PROCEDURE Put*(VAR x, y: O7X.Item); 
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(x, y) 
  END Put; 
 
  PROCEDURE Copy*(VAR x, y, z: O7X.Item); 
  BEGIN load(x); load(y); 
    IF z.mode = O7B.Const THEN 
      IF z.a > 0 THEN load(z) ELSE O7S.Mark("bad count") END 
    ELSE load(z); 
      IF T.check THEN Trap(LT, 3) END ; 
      T.PutOpBRI(T, BC, EQ, 6) 
    END ; 
    T.PutOpLS(T, Ldr, T.RH, x.r, 0); T.PutOpRRI(T, 0, Add, x.r, x.r, 4); 
    T.PutOpLS(T, Str, T.RH, y.r, 0); T.PutOpRRI(T, 0, Add, y.r, y.r, 4); 
    T.PutOpRRI(T, 0, Sub, z.r, z.r, 1); T.PutOpBRI(T, BC, NE, -6); DEC(T.RH, 3) 
  END Copy; 
 
  PROCEDURE LDPSR*(VAR x: O7X.Item); 
  BEGIN (*x.mode = Const*)  T.PutOpBRI(T, 0, 15, x.a + 20H) 
  END LDPSR; 
 
  PROCEDURE LDREG*(VAR x, y: O7X.Item); 
  BEGIN 
    IF y.mode = O7B.Const THEN T.PutOpRRIa(T, Mov, x.a, 0, y.a) 
    ELSE load(y); T.PutOpRRR(T, 0, Mov, x.a, 0, y.r); DEC(T.RH) 
    END 
  END LDREG; 
 
  (*In-line code functions*) 
 
  PROCEDURE Abs*(VAR x: O7X.Item); 
  BEGIN 
    IF x.mode = O7B.Const THEN x.a := ABS(x.a) 
    ELSE load(x); 
      IF x.type.form = O7B.Real THEN T.PutOpRRI(T, 0, Lsl, x.r, x.r, 1); T.PutOpRRI(T, 0, Ror, x.r, x.r, 1) 
      ELSE T.PutOpRRI(T, 0, Cmp, x.r, x.r, 0); T.PutOpBRI(T, BC, GE, 2); T.PutOpRRI(T, 0, Mov, T.RH, 0, 0); T.PutOpRRR(T, 0, Sub, x.r, T.RH, x.r) 
      END 
    END 
  END Abs; 
 
  PROCEDURE Odd*(VAR x: O7X.Item); 
  BEGIN load(x); T.PutOpRRI(T, 0, And, x.r, x.r, 1); SetCC(x, NE); DEC(T.RH) 
  END Odd; 
 
  PROCEDURE Floor*(VAR x: O7X.Item); 
  BEGIN load(x); T.PutOpRRI(T, U, Mov, T.RH, 0, 4B00H); T.PutOpRRR(T, 0, Fad+1000H, x.r, x.r, T.RH)  
  END Floor; 
 
  PROCEDURE Float*(VAR x: O7X.Item); 
  BEGIN load(x); T.PutOpRRI(T, U, Mov, T.RH, 0, 4B00H);  T.PutOpRRR(T, U, Fad, x.r, x.r, T.RH) 
  END Float; 
 
  PROCEDURE Ord*(VAR x: O7X.Item); 
  BEGIN 
    IF x.mode IN {O7B.Var, O7B.Par, RegI} THEN load(x) END 
  END Ord; 
 
  PROCEDURE Len*(VAR x: O7X.Item); 
  BEGIN 
    IF x.type.len >= 0 THEN x.mode := O7B.Const; x.a := x.type.len 
    ELSE (*open array*) T.PutOpLS(T, Ldr, T.RH, SP, x.a + 4); x.mode := Reg; x.r := T.RH; incR 
    END  
  END Len; 
 
  PROCEDURE Shift*(fct: LONGINT; VAR x, y: O7X.Item); 
    VAR op: LONGINT; 
  BEGIN load(x); 
    IF fct = 0 THEN op := Lsl ELSIF fct = 1 THEN op := Asr ELSE op := Ror END ; 
    IF y.mode = O7B.Const THEN T.PutOpRRI(T, 0, op, x.r, x.r, y.a MOD 20H) 
    ELSE load(y); T.PutOpRRR(T, 0, op, T.RH-2, x.r, y.r); DEC(T.RH); x.r := T.RH-1 
    END 
  END Shift; 
 
  PROCEDURE ADC*(VAR x, y: O7X.Item); 
  BEGIN load(x); load(y); T.PutOpRRR(T, 0, Add+2000H, x.r, x.r, y.r); DEC(T.RH) 
  END ADC; 
 
  PROCEDURE SBC*(VAR x, y: O7X.Item); 
  BEGIN load(x); load(y); T.PutOpRRR(T, 0, Sub+2000H, x.r, x.r, y.r); DEC(T.RH) 
  END SBC; 
 
  PROCEDURE UML*(VAR x, y: O7X.Item); 
  BEGIN load(x); load(y); T.PutOpRRR(T, 0, Mul+2000H, x.r, x.r, y.r); DEC(T.RH) 
  END UML; 
 
  PROCEDURE Bit*(VAR x, y: O7X.Item); 
  BEGIN load(x); T.PutOpLS(T, Ldr, x.r, x.r, 0); 
    IF y.mode = O7B.Const THEN T.PutOpRRI(T, 0, Ror, x.r, x.r, y.a+1); DEC(T.RH) 
    ELSE load(y); T.PutOpRRI(T, 0, Add, y.r, y.r, 1); T.PutOpRRR(T, 0, Ror, x.r, x.r, y.r); DEC(T.RH, 2) 
    END ; 
    SetCC(x, MI) 
  END Bit; 
 
  PROCEDURE Register*(VAR x: O7X.Item); 
  BEGIN (*x.mode = Const*) 
    T.PutOpRRR(T, 0, Mov, T.RH, 0, x.a MOD 10H); x.mode := Reg; x.r := T.RH; incR 
  END Register; 
 
  PROCEDURE H*(VAR x: O7X.Item); 
  BEGIN (*x.mode = Const*) 
    T.PutOpRRR(T, 0, Mov + U + (x.a MOD 2 * 1000H), T.RH, 0, 0); x.mode := Reg; x.r := T.RH; incR 
  END H; 
 
  PROCEDURE Adr*(VAR x: O7X.Item); 
  BEGIN  
    IF x.mode IN {O7B.Var, O7B.Par, RegI} THEN loadAdr(x) 
    ELSIF (x.mode = O7B.Const) & (x.type.form = O7B.Proc) THEN load(x) 
    ELSIF (x.mode = O7B.Const) & (x.type.form = O7B.String) THEN loadStringAdr(x) 
    ELSE O7S.Mark("not addressable") 
    END 
  END Adr; 
 
  PROCEDURE Condition*(VAR x: O7X.Item); 
  BEGIN (*x.mode = Const*) SetCC(x, x.a) 
  END Condition; 
 
  PROCEDURE Open*(v: INTEGER); 
  BEGIN
    T.Open(T,v)
  END Open; 
 
  PROCEDURE SetDataSize*(dc: LONGINT); 
  BEGIN T.varsize := dc 
  END SetDataSize; 
 
  PROCEDURE Header*; 
  BEGIN
    T.Header(T) 
  END Header;

  PROCEDURE Close * (VAR modid: O7S.Ident; key, nofent: LONGINT);
  BEGIN
    T.Close( T, modid, key, nofent );
  END Close; 
 
BEGIN   NEW(T);   
  T.relmap[0] := 1; T.relmap[1] := 9; T.relmap[2] := 5; T.relmap[3] := 6; T.relmap[4] := 14; T.relmap[5] := 13 
END O7G. 
