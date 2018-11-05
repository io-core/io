MODULE O7P; (*N. Wirth 1.7.97 / 15.12.2013 / CP 6.3.2014 Oberon compiler for Oberon-07*)
  IMPORT Texts, Oberon, O7S, O7B, OXG, O7G;
  (*Author: Niklaus Wirth, 2011.
    Parser of Oberon-07 compiler. Uses Scanner O7S to obtain symbols (tokens),
    O7B for definition of data structures and for handling import and export, and
    O<arch>G to produce binary code. O7P performs type checking and data allocation.
    Parser is target-independent, except for part of the handling of allocations.*)

  TYPE PtrBase = POINTER TO PtrBaseDesc;
    PtrBaseDesc = RECORD  (*list of names of pointer base types*)
      name: O7S.Ident; type: O7B.Type; next: PtrBase
    END ;
  
  VAR sym: INTEGER;   (*last symbol read*)
    dc: LONGINT;    (*data counter*)
    level, exno, version: INTEGER;
    newSF: BOOLEAN;  (*option flag*)
    arch: CHAR;
    expression: PROCEDURE (VAR x: OXG.Item);  (*to avoid forward reference*)
    Type: PROCEDURE (VAR type: O7B.Type);
    FormalType: PROCEDURE (VAR typ: O7B.Type; dim: INTEGER);
    modid: O7S.Ident;
    pbsList: PtrBase;   (*list of names of pointer base types*)
    dummy: O7B.Object;
    W: Texts.Writer;

    

  PROCEDURE Check(s: INTEGER; msg: ARRAY OF CHAR);
  BEGIN
    IF sym = s THEN O7S.Get(sym) ELSE O7S.Mark(msg) END
  END Check;

  PROCEDURE qualident(VAR obj: O7B.Object);
  BEGIN obj := O7B.thisObj(); O7S.Get(sym);
    IF obj = NIL THEN O7S.Mark("undef"); obj := dummy END ;
    IF (sym = O7S.period) & (obj.class = O7B.Mod) THEN
      O7S.Get(sym);
      IF sym = O7S.ident THEN obj := O7B.thisimport(obj); O7S.Get(sym);
        IF obj = NIL THEN O7S.Mark("undef"); obj := dummy END
      ELSE O7S.Mark("identifier expected"); obj := dummy
      END
    END
  END qualident;

  PROCEDURE CheckBool(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # O7B.Bool THEN O7S.Mark("not Boolean"); x.type := O7B.boolType END
  END CheckBool;

  PROCEDURE CheckInt(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # O7B.Int THEN O7S.Mark("not Integer"); x.type := O7B.intType END
  END CheckInt;

  PROCEDURE CheckReal(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # O7B.Real THEN O7S.Mark("not Real"); x.type := O7B.realType END
  END CheckReal;

  PROCEDURE CheckSet(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # O7B.Set THEN O7S.Mark("not Set"); x.type := O7B.setType END 
  END CheckSet;

  PROCEDURE CheckSetVal(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # O7B.Int THEN O7S.Mark("not Int"); x.type := O7B.setType
    ELSIF x.mode = O7B.Const THEN
      IF (x.a < 0) OR (x.a >= 32) THEN O7S.Mark("invalid set") END
    END 
  END CheckSetVal;

  PROCEDURE CheckConst(VAR x: OXG.Item);
  BEGIN
    IF x.mode # O7B.Const THEN O7S.Mark("not a constant"); x.mode := O7B.Const END
  END CheckConst;

  PROCEDURE CheckReadOnly(VAR x: OXG.Item);
  BEGIN
    IF x.rdo THEN O7S.Mark("read-only") END
  END CheckReadOnly;

  PROCEDURE CheckExport(VAR expo: BOOLEAN);
  BEGIN
    IF sym = O7S.times THEN
      expo := TRUE; O7S.Get(sym);
      IF level # 0 THEN O7S.Mark("remove asterisk") END
    ELSE expo := FALSE
    END
  END CheckExport;

  PROCEDURE IsExtension(t0, t1: O7B.Type): BOOLEAN;
  BEGIN (*t1 is an extension of t0*)
    RETURN (t0 = t1) OR (t1 # NIL) & IsExtension(t0, t1.base)
  END IsExtension;

  (* expressions *)

  PROCEDURE TypeTest(VAR x: OXG.Item; T: O7B.Type; guard: BOOLEAN);
    VAR xt: O7B.Type;
  BEGIN xt := x.type;
    WHILE (xt # T) & (xt # NIL) DO xt := xt.base END ;
    IF xt # T THEN xt := x.type;
      IF (xt.form = O7B.Pointer) & (T.form = O7B.Pointer) THEN
        IF IsExtension(xt.base, T.base) THEN O7G.TypeTest(x, T.base, FALSE, guard); x.type := T
        ELSE O7S.Mark("not an extension")
        END
      ELSIF (xt.form = O7B.Record) & (T.form = O7B.Record) & (x.mode = O7B.Par) THEN
        IF IsExtension(xt, T) THEN  O7G.TypeTest(x, T, TRUE, guard); x.type := T
        ELSE O7S.Mark("not an extension")
        END
      ELSE O7S.Mark("incompatible types")
      END
    ELSIF ~guard THEN O7G.MakeConstItem(x, O7B.boolType, 1)
    END ;
    IF ~guard THEN x.type := O7B.boolType END
  END TypeTest;

  PROCEDURE selector(VAR x: OXG.Item);
    VAR y: OXG.Item; obj: O7B.Object;
  BEGIN
    WHILE (sym = O7S.lbrak) OR (sym = O7S.period) OR (sym = O7S.arrow)
        OR (sym = O7S.lparen) & (x.type.form IN {O7B.Record, O7B.Pointer}) DO
      IF sym = O7S.lbrak THEN
        REPEAT O7S.Get(sym); expression(y);
          IF x.type.form = O7B.Array THEN
            CheckInt(y); O7G.Index(x, y); x.type := x.type.base
          ELSE O7S.Mark("not an array")
          END
        UNTIL sym # O7S.comma;
        Check(O7S.rbrak, "no ]")
      ELSIF sym = O7S.period THEN O7S.Get(sym);
        IF sym = O7S.ident THEN
          IF x.type.form = O7B.Pointer THEN O7G.DeRef(x); x.type := x.type.base END ;
          IF x.type.form = O7B.Record THEN
            obj := O7B.thisfield(x.type); O7S.Get(sym);
            IF obj # NIL THEN O7G.Field(x, obj); x.type := obj.type
            ELSE O7S.Mark("undef")
            END
          ELSE O7S.Mark("not a record")
          END
        ELSE O7S.Mark("ident?")
        END
      ELSIF sym = O7S.arrow THEN
        O7S.Get(sym);
        IF x.type.form = O7B.Pointer THEN O7G.DeRef(x); x.type := x.type.base
        ELSE O7S.Mark("not a pointer")
        END
      ELSIF (sym = O7S.lparen) & (x.type.form IN {O7B.Record, O7B.Pointer}) THEN (*type guard*)
        O7S.Get(sym);
        IF sym = O7S.ident THEN
          qualident(obj);
          IF obj.class = O7B.Typ THEN TypeTest(x, obj.type, TRUE)
          ELSE O7S.Mark("guard type expected")
          END
        ELSE O7S.Mark("not an identifier")
        END ;
        Check(O7S.rparen, " ) missing")
      END
    END
  END selector;

  PROCEDURE CompTypes(t0, t1: O7B.Type; varpar: BOOLEAN): BOOLEAN;

    PROCEDURE EqualSignatures(t0, t1: O7B.Type): BOOLEAN;
      VAR p0, p1: O7B.Object; com: BOOLEAN;
    BEGIN com := TRUE;
      IF (t0.base = t1.base) & (t0.nofpar = t1.nofpar) THEN
        p0 := t0.dsc; p1 := t1.dsc;
        WHILE p0 # NIL DO
          IF (p0.class = p1.class) & CompTypes(p0.type, p1.type, TRUE) & (ORD(p0.rdo) = ORD(p1.rdo)) THEN
            IF p0.type.form >= O7B.Array THEN com := CompTypes(p0.type, p1.type, (p0.class = O7B.Par)) END ;
            p0 := p0.next; p1 := p1.next
          ELSE p0 := NIL; com := FALSE
          END
        END
      ELSE com := FALSE
      END ;
      RETURN com
    END EqualSignatures;
  
  BEGIN (*Compatible Types*)
    RETURN (t0 = t1)
      OR (t0.form = O7B.Array) & (t1.form = O7B.Array) & CompTypes(t0.base, t1.base, varpar)
      OR (t0.form = O7B.Pointer) & (t1.form = O7B.Pointer) & IsExtension(t0.base, t1.base)
      OR (t0.form = O7B.Record) & (t1.form = O7B.Record) & IsExtension(t0, t1)
      OR (t0.form = O7B.Proc) & (t1.form = O7B.Proc) & EqualSignatures(t0, t1)
      OR (t0.form IN {O7B.Pointer, O7B.Proc}) & (t1.form = O7B.NilTyp)
      OR (t0.form = O7B.NilTyp) & (t1.form IN {O7B.Pointer, O7B.Proc})
      OR ~varpar & (t0.form = O7B.Int) & (t1.form = O7B.Int)
  END CompTypes;

  PROCEDURE Parameter(par: O7B.Object);
    VAR x: OXG.Item; varpar: BOOLEAN;
  BEGIN expression(x);
    IF par # NIL THEN
      varpar := par.class = O7B.Par;
      IF CompTypes(par.type, x.type, varpar) THEN
        IF ~varpar THEN O7G.ValueParam(x)
        ELSE (*par.class = Par*)
          IF ~par.rdo THEN CheckReadOnly(x) END ;
          O7G.VarParam(x, par.type)
        END
      ELSIF ~varpar & (par.type.form = O7B.Int) & (x.type.form = O7B.Int) THEN
        O7G.ValueParam(x) 
      ELSIF (x.type.form = O7B.String) & (x.b = 2) & (par.class = O7B.Var) & (par.type.form = O7B.Char) THEN
        O7G.StrToChar(x); O7G.ValueParam(x)
      ELSIF (x.type.form = O7B.Array) & (par.type.form = O7B.Array) &
          (x.type.base.form = par.type.base.form) & (par.type.len < 0) THEN
        O7G.OpenArrayParam(x);
      ELSIF (x.type.form = O7B.String) & (par.class = O7B.Par) & (par.type.form = O7B.Array) & 
          (par.type.base.form = O7B.Char) & (par.type.len < 0) THEN O7G.StringParam(x)
      ELSIF (par.type.form = O7B.Array) & (par.type.base.form = O7B.Int) & (par.type.size = x.type.size) THEN
        O7G.VarParam(x, par.type)
      ELSE O7S.Mark("incompatible parameters")
      END
    END
  END Parameter;

  PROCEDURE ParamList(VAR x: OXG.Item);
    VAR n: INTEGER; par: O7B.Object;
  BEGIN par := x.type.dsc; n := 0;
    IF sym # O7S.rparen THEN
      Parameter(par); n := 1;
      WHILE sym <= O7S.comma DO
        Check(sym, "comma?");
        IF par # NIL THEN par := par.next END ;
        INC(n); Parameter(par)
      END ;
      Check(O7S.rparen, ") missing")
    ELSE O7S.Get(sym);
    END ;
    IF n < x.type.nofpar THEN O7S.Mark("too few params")
    ELSIF n > x.type.nofpar THEN O7S.Mark("too many params")
    END
  END ParamList;

  PROCEDURE StandFunc(VAR x: OXG.Item; fct: LONGINT; restyp: O7B.Type);
    VAR y: OXG.Item; n, npar: LONGINT;
  BEGIN Check(O7S.lparen, "no (");
    npar := fct MOD 10; fct := fct DIV 10; expression(x); n := 1;
    WHILE sym = O7S.comma DO O7S.Get(sym); expression(y); INC(n) END ;
    Check(O7S.rparen, "no )");
    IF n = npar THEN
      IF fct = 0 THEN (*ABS*)
        IF x.type.form IN {O7B.Int, O7B.Real} THEN O7G.Abs(x); restyp := x.type ELSE O7S.Mark("bad type") END
      ELSIF fct = 1 THEN (*ODD*) CheckInt(x); O7G.Odd(x)
      ELSIF fct = 2 THEN (*FLOOR*) CheckReal(x); O7G.Floor(x)
      ELSIF fct = 3 THEN (*FLT*) CheckInt(x); O7G.Float(x)
      ELSIF fct = 4 THEN (*ORD*)
        IF x.type.form <= O7B.Proc THEN O7G.Ord(x)
        ELSIF (x.type.form = O7B.String) & (x.b = 2) THEN O7G.StrToChar(x)
        ELSE O7S.Mark("bad type")
        END
      ELSIF fct = 5 THEN (*CHR*) CheckInt(x); O7G.Ord(x)
      ELSIF fct = 6 THEN (*LEN*)
          IF x.type.form = O7B.Array THEN O7G.Len(x) ELSE O7S.Mark("not an array") END
      ELSIF fct IN {7, 8, 9} THEN (*LSL, ASR, ROR*) CheckInt(y);
        IF x.type.form IN {O7B.Int, O7B.Set} THEN O7G.Shift(fct-7, x, y); restyp := x.type ELSE O7S.Mark("bad type") END
      ELSIF fct = 11 THEN (*ADC*) O7G.ADC(x, y)
      ELSIF fct = 12 THEN (*SBC*) O7G.SBC(x, y)
      ELSIF fct = 13 THEN (*UML*) O7G.UML(x, y)
      ELSIF fct = 14 THEN (*BIT*) CheckInt(x); CheckInt(y); O7G.Bit(x, y)
      ELSIF fct = 15 THEN (*REG*) CheckConst(x); CheckInt(x); O7G.Register(x)
      ELSIF fct = 16 THEN (*VAL*)
        IF (x.mode= O7B.Typ) & (x.type.size <= y.type.size) THEN restyp := x.type; x := y
        ELSE O7S.Mark("casting not allowed")
        END
      ELSIF fct = 17 THEN (*ADR*) O7G.Adr(x)
      ELSIF fct = 18 THEN (*SIZE*)
        IF x.mode = O7B.Typ THEN O7G.MakeConstItem(x, O7B.intType, x.type.size)
        ELSE O7S.Mark("must be a type")
        END
      ELSIF fct = 19 THEN (*COND*) CheckConst(x); CheckInt(x); O7G.Condition(x)
      ELSIF fct = 20 THEN (*H*) CheckConst(x); CheckInt(x); O7G.H(x)
      END ;
      x.type := restyp
    ELSE O7S.Mark("wrong nof params")
    END
  END StandFunc;

  PROCEDURE element(VAR x: OXG.Item);
    VAR y: OXG.Item;
  BEGIN expression(x); CheckSetVal(x);
    IF sym = O7S.upto THEN O7S.Get(sym); expression(y); CheckSetVal(y); O7G.Set(x, y)
    ELSE O7G.Singleton(x)
    END ;
    x.type := O7B.setType
  END element;
  
  PROCEDURE set(VAR x: OXG.Item);
    VAR y: OXG.Item;
  BEGIN
    IF sym >= O7S.if THEN
      IF sym # O7S.rbrace THEN O7S.Mark(" } missing") END ;
      O7G.MakeConstItem(x, O7B.setType, 0) (*empty set*)
    ELSE element(x);
      WHILE (sym < O7S.rparen) OR (sym > O7S.rbrace) DO
        IF sym = O7S.comma THEN O7S.Get(sym)
        ELSIF sym # O7S.rbrace THEN O7S.Mark("missing comma")
        END ;
        element(y); O7G.SetOp(O7S.plus, x, y)
      END
    END
  END set; 

  PROCEDURE factor(VAR x: OXG.Item);
    VAR obj: O7B.Object; rx: LONGINT;
  BEGIN (*sync*)
    IF (sym < O7S.char) OR (sym > O7S.ident) THEN O7S.Mark("expression expected");
      REPEAT O7S.Get(sym) UNTIL (sym >= O7S.char) & (sym <= O7S.ident)
    END ;
    IF sym = O7S.ident THEN
      qualident(obj);  
      IF obj.class = O7B.SFunc THEN StandFunc(x, obj.val, obj.type)
      ELSE O7G.MakeItem(x, obj, level); selector(x);
        IF sym = O7S.lparen THEN
          O7S.Get(sym); O7G.PrepCall(x, rx); ParamList(x);
          IF (x.type.form = O7B.Proc) & (x.type.base.form # O7B.NoTyp) THEN
            O7G.Call(x, rx); x.type := x.type.base
          ELSE O7S.Mark("not a function")
          END ;
        END
      END
    ELSIF sym = O7S.int THEN O7G.MakeConstItem(x, O7B.intType, O7S.ival); O7S.Get(sym)
    ELSIF sym = O7S.real THEN O7G.MakeRealItem(x, O7S.rval); O7S.Get(sym)
    ELSIF sym = O7S.char THEN O7G.MakeConstItem(x, O7B.charType, O7S.ival); O7S.Get(sym)
    ELSIF sym = O7S.nil THEN O7S.Get(sym); O7G.MakeConstItem(x, O7B.nilType, 0)
    ELSIF sym = O7S.string THEN O7G.MakeStringItem(x, O7S.slen); O7S.Get(sym)
    ELSIF sym = O7S.lparen THEN O7S.Get(sym); expression(x); Check(O7S.rparen, "no )")
    ELSIF sym = O7S.lbrace THEN O7S.Get(sym); set(x); Check(O7S.rbrace, "no }")
    ELSIF sym = O7S.not THEN O7S.Get(sym); factor(x); CheckBool(x); O7G.Not(x)
    ELSIF sym = O7S.false THEN O7S.Get(sym); O7G.MakeConstItem(x, O7B.boolType, 0)
    ELSIF sym = O7S.true THEN O7S.Get(sym); O7G.MakeConstItem(x, O7B.boolType, 1)
    ELSE O7S.Mark("not a factor"); O7G.MakeItem(x, NIL, level)
    END
  END factor;

  PROCEDURE term(VAR x: OXG.Item);
    VAR y: OXG.Item; op, f: INTEGER;
  BEGIN factor(x); f := x.type.form;
    WHILE (sym >= O7S.times) & (sym <= O7S.and) DO
      op := sym; O7S.Get(sym);
      IF op = O7S.times THEN
        IF f = O7B.Int THEN factor(y); CheckInt(y); O7G.MulOp(x, y)
        ELSIF f = O7B.Real THEN factor(y); CheckReal(y); O7G.RealOp(op, x, y)
        ELSIF f = O7B.Set THEN factor(y); CheckSet(y); O7G.SetOp(op, x, y)
        ELSE O7S.Mark("bad type")
        END
      ELSIF (op = O7S.div) OR (op = O7S.mod) THEN
        CheckInt(x); factor(y); CheckInt(y); O7G.DivOp(op, x, y)
      ELSIF op = O7S.rdiv THEN
        IF f = O7B.Real THEN factor(y); CheckReal(y); O7G.RealOp(op, x, y)
        ELSIF f = O7B.Set THEN factor(y); CheckSet(y); O7G.SetOp(op, x, y)
        ELSE O7S.Mark("bad type")
        END
      ELSE (*op = and*) CheckBool(x); O7G.And1(x); factor(y); CheckBool(y); O7G.And2(x, y)
      END
    END
  END term;

  PROCEDURE SimpleExpression(VAR x: OXG.Item);
    VAR y: OXG.Item; op: INTEGER;
  BEGIN
    IF sym = O7S.minus THEN O7S.Get(sym); term(x);
      IF x.type.form IN {O7B.Int, O7B.Real, O7B.Set} THEN O7G.Neg(x) ELSE CheckInt(x) END
    ELSIF sym = O7S.plus THEN O7S.Get(sym); term(x);
    ELSE term(x)
    END ;
    WHILE (sym >= O7S.plus) & (sym <= O7S.or) DO
      op := sym; O7S.Get(sym);
      IF op = O7S.or THEN O7G.Or1(x); CheckBool(x); term(y); CheckBool(y); O7G.Or2(x, y)
      ELSIF x.type.form = O7B.Int THEN term(y); CheckInt(y); O7G.AddOp(op, x, y)
      ELSIF x.type.form = O7B.Real THEN term(y); CheckReal(y); O7G.RealOp(op, x, y)
      ELSE CheckSet(x); term(y); CheckSet(y); O7G.SetOp(op, x, y)
      END
    END
  END SimpleExpression;

  PROCEDURE expression0(VAR x: OXG.Item);
    VAR y: OXG.Item; obj: O7B.Object; rel, xf, yf: INTEGER;
  BEGIN SimpleExpression(x);
    IF (sym >= O7S.eql) & (sym <= O7S.geq) THEN
      rel := sym; O7S.Get(sym); SimpleExpression(y); xf := x.type.form; yf := y.type.form;
      IF CompTypes(x.type, y.type, FALSE) OR
          (xf = O7B.Pointer) & (yf = O7B.Pointer) & IsExtension(y.type.base, x.type.base) THEN
        IF (xf IN {O7B.Char, O7B.Int}) THEN O7G.IntRelation(rel, x, y)
        ELSIF xf = O7B.Real THEN O7G.RealRelation(rel, x, y)
        ELSIF xf = O7B.Set THEN O7G.SetRelation(rel, x, y)
        ELSIF (xf IN {O7B.Pointer, O7B.Proc, O7B.NilTyp}) THEN
          IF rel <= O7S.neq THEN O7G.IntRelation(rel, x, y) ELSE O7S.Mark("only = or #") END
        ELSIF (xf = O7B.Array) & (x.type.base.form = O7B.Char) OR (xf = O7B.String) THEN
          O7G.StringRelation(rel, x, y)
        ELSE O7S.Mark("illegal comparison")
        END
      ELSIF (xf = O7B.Array) & (x.type.base.form = O7B.Char) &
            ((yf = O7B.String) OR (yf = O7B.Array) & (y.type.base.form = O7B.Char))
          OR (yf = O7B.Array) & (y.type.base.form = O7B.Char) & (xf = O7B.String) THEN
        O7G.StringRelation(rel, x, y)
      ELSIF (xf = O7B.Char) & (yf = O7B.String) & (y.b = 2) THEN
        O7G.StrToChar(y); O7G.IntRelation(rel, x, y)
      ELSIF (yf = O7B.Char) & (xf = O7B.String) & (x.b = 2) THEN
        O7G.StrToChar(x); O7G.IntRelation(rel, x, y)
      ELSE O7S.Mark("illegal comparison")
      END ;
      x.type := O7B.boolType
    ELSIF sym = O7S.in THEN
      O7S.Get(sym); SimpleExpression(y);
      IF (x.type.form = O7B.Int) & (y.type.form = O7B.Set) THEN O7G.In(x, y)
      ELSE O7S.Mark("illegal operands of IN")
      END ;
      x.type := O7B.boolType
    ELSIF sym = O7S.is THEN
      O7S.Get(sym); qualident(obj); TypeTest(x, obj.type, FALSE) ;
      x.type := O7B.boolType
    END
  END expression0;

  (* statements *)

  PROCEDURE StandProc(pno: LONGINT);
    VAR nap, npar: LONGINT; (*nof actual/formal parameters*)
      x, y, z: OXG.Item;
  BEGIN Check(O7S.lparen, "no (");
    npar := pno MOD 10; pno := pno DIV 10; expression(x); nap := 1;
    IF sym = O7S.comma THEN
      O7S.Get(sym); expression(y); nap := 2; z.type := O7B.noType;
      WHILE sym = O7S.comma DO O7S.Get(sym); expression(z); INC(nap) END
    ELSE y.type := O7B.noType
    END ;
    Check(O7S.rparen, "no )");
    IF (npar = nap) OR (pno IN {0, 1}) THEN 
      IF pno IN {0, 1} THEN (*INC, DEC*)
        CheckInt(x); CheckReadOnly(x);
        IF y.type # O7B.noType THEN CheckInt(y) END ;
        O7G.Increment(pno, x, y)
      ELSIF pno IN {2, 3} THEN (*INCL, EXCL*)
        CheckSet(x); CheckReadOnly(x); CheckInt(y); O7G.Include(pno-2, x, y)
      ELSIF pno = 4 THEN CheckBool(x); O7G.Assert(x)
      ELSIF pno = 5 THEN(*NEW*) CheckReadOnly(x);
         IF (x.type.form = O7B.Pointer) & (x.type.base.form = O7B.Record) THEN O7G.New(x)
         ELSE O7S.Mark("not a pointer to record")
         END
      ELSIF pno = 6 THEN CheckReal(x); CheckInt(y); CheckReadOnly(x); O7G.Pack(x, y)
      ELSIF pno = 7 THEN CheckReal(x); CheckInt(y); CheckReadOnly(x); O7G.Unpk(x, y)
      ELSIF pno = 8 THEN
        IF x.type.form <= O7B.Set THEN O7G.Led(x) ELSE O7S.Mark("bad type") END
      ELSIF pno = 10 THEN CheckInt(x); O7G.Get(x, y)
      ELSIF pno = 11 THEN CheckInt(x); O7G.Put(x, y)
      ELSIF pno = 12 THEN CheckInt(x); CheckInt(y); CheckInt(z); O7G.Copy(x, y, z)
      ELSIF pno = 13 THEN CheckConst(x); CheckInt(x); O7G.LDPSR(x)
      ELSIF pno = 14 THEN CheckInt(x); O7G.LDREG(x, y)
      END
    ELSE O7S.Mark("wrong nof parameters")
    END
  END StandProc;

  PROCEDURE StatSequence;
    VAR obj: O7B.Object;
      O7Gtype: O7B.Type; (*original type of case var*)
      x, y, z, w: OXG.Item;
      L0, L1, rx: LONGINT;

    PROCEDURE TypeCase(obj: O7B.Object; VAR x: OXG.Item);
      VAR typobj: O7B.Object;
    BEGIN
      IF sym = O7S.ident THEN
        qualident(typobj); O7G.MakeItem(x, obj, level);
        IF typobj.class # O7B.Typ THEN O7S.Mark("not a type") END ;
        TypeTest(x, typobj.type, FALSE); obj.type := typobj.type;
        O7G.CFJump(x); Check(O7S.colon, ": expected"); StatSequence
      ELSE O7G.CFJump(x); O7S.Mark("type id expected")
      END
     END TypeCase;

    PROCEDURE SkipCase;
    BEGIN 
      WHILE sym # O7S.colon DO O7S.Get(sym) END ;
      O7S.Get(sym); StatSequence
    END SkipCase;

  BEGIN (* StatSequence *)
    REPEAT (*sync*) obj := NIL;
      IF ~((sym = O7S.ident) OR (sym >= O7S.if) & (sym <= O7S.for) OR (sym >= O7S.semicolon)) THEN
        O7S.Mark("statement expected");
        REPEAT O7S.Get(sym) UNTIL (sym = O7S.ident) OR (sym >= O7S.if)
      END ;
      IF sym = O7S.ident THEN
        qualident(obj); O7G.MakeItem(x, obj, level);
        IF x.mode = O7B.SProc THEN StandProc(obj.val)
        ELSE selector(x);
          IF sym = O7S.becomes THEN (*assignment*)
            O7S.Get(sym); CheckReadOnly(x); expression(y);
            IF CompTypes(x.type, y.type, FALSE) OR (x.type.form = O7B.Int) & (y.type.form = O7B.Int) THEN
              IF (x.type.form <= O7B.Pointer) OR (x.type.form = O7B.Proc) THEN O7G.Store(x, y)
              ELSIF y.type.size # 0 THEN O7G.StoreStruct(x, y)
              END
            ELSIF (x.type.form = O7B.Char) & (y.type.form = O7B.String) & (y.b = 2) THEN
              O7G.StrToChar(y); O7G.Store(x, y)
            ELSIF (x.type.form = O7B.Array) & (x.type.base.form = O7B.Char) & 
                (y.type.form = O7B.String) THEN O7G.CopyString(y, x)
            ELSE O7S.Mark("illegal assignment")
            END
          ELSIF sym = O7S.eql THEN O7S.Mark("should be :="); O7S.Get(sym); expression(y)
          ELSIF sym = O7S.lparen THEN (*procedure call*)
            O7S.Get(sym); O7G.PrepCall(x, rx); ParamList(x);
            IF (x.type.form = O7B.Proc) & (x.type.base.form = O7B.NoTyp) THEN O7G.Call(x, rx)
            ELSE O7S.Mark("not a procedure")
            END
          ELSIF x.type.form = O7B.Proc THEN (*procedure call without parameters*)
            IF x.type.nofpar > 0 THEN O7S.Mark("missing parameters") END ;
            IF x.type.base.form = O7B.NoTyp THEN O7G.PrepCall(x, rx); O7G.Call(x, rx) ELSE O7S.Mark("not a procedure") END
          ELSIF x.mode = O7B.Typ THEN O7S.Mark("illegal assignment")
          ELSE O7S.Mark("not a procedure")
          END
        END
      ELSIF sym = O7S.if THEN
        O7S.Get(sym); expression(x); CheckBool(x); O7G.CFJump(x);
        Check(O7S.then, "no THEN");
        StatSequence; L0 := 0;
        WHILE sym = O7S.elsif DO
          O7S.Get(sym); O7G.FJump(L0); O7G.Fixup(x); expression(x); CheckBool(x);
          O7G.CFJump(x); Check(O7S.then, "no THEN"); StatSequence
        END ;
        IF sym = O7S.else THEN O7S.Get(sym); O7G.FJump(L0); O7G.Fixup(x); StatSequence
        ELSE O7G.Fixup(x)
        END ;
        O7G.FixLink(L0); Check(O7S.end, "no END")
      ELSIF sym = O7S.while THEN
        O7S.Get(sym); L0 := O7G.Here(); expression(x); CheckBool(x); O7G.CFJump(x);
        Check(O7S.do, "no DO"); StatSequence; O7G.BJump(L0);
        WHILE sym = O7S.elsif DO
          O7S.Get(sym); O7G.Fixup(x); expression(x); CheckBool(x); O7G.CFJump(x);
          Check(O7S.do, "no DO"); StatSequence; O7G.BJump(L0)
        END ;
        O7G.Fixup(x); Check(O7S.end, "no END")
      ELSIF sym = O7S.repeat THEN
        O7S.Get(sym); L0 := O7G.Here(); StatSequence;
        IF sym = O7S.until THEN
          O7S.Get(sym); expression(x); CheckBool(x); O7G.CBJump(x, L0)
        ELSE O7S.Mark("missing UNTIL")
        END
      ELSIF sym = O7S.for THEN
        O7S.Get(sym);
        IF sym = O7S.ident THEN
          qualident(obj); O7G.MakeItem(x, obj, level); CheckInt(x); CheckReadOnly(x);
          IF sym = O7S.becomes THEN
            O7S.Get(sym); expression(y); CheckInt(y); O7G.For0(x, y); L0 := O7G.Here();
            Check(O7S.to, "no TO"); expression(z); CheckInt(z); obj.rdo := TRUE;
            IF sym = O7S.by THEN O7S.Get(sym); expression(w); CheckConst(w); CheckInt(w)
            ELSE O7G.MakeConstItem(w, O7B.intType, 1)
            END ;
            Check(O7S.do, "no DO"); O7G.For1(x, y, z, w, L1);
            StatSequence; Check(O7S.end, "no END");
            O7G.For2(x, y, w); O7G.BJump(L0); O7G.FixLink(L1); obj.rdo := FALSE
          ELSE O7S.Mark(":= expected")
          END
        ELSE O7S.Mark("identifier expected")
        END
      ELSIF sym = O7S.case THEN
        O7S.Get(sym);
        IF sym = O7S.ident THEN
          qualident(obj); O7Gtype := obj.type;
          IF (O7Gtype.form = O7B.Pointer) OR (O7Gtype.form = O7B.Record) & (obj.class = O7B.Par) THEN
            Check(O7S.of, "OF expected"); TypeCase(obj, x); L0 := 0;
            WHILE sym = O7S.bar DO
              O7S.Get(sym); O7G.FJump(L0); O7G.Fixup(x); obj.type := O7Gtype; TypeCase(obj, x)
            END ;
            O7G.Fixup(x); O7G.FixLink(L0); obj.type := O7Gtype
          ELSE O7S.Mark("numeric case not implemented");
            Check(O7S.of, "OF expected"); SkipCase;
            WHILE sym = O7S.bar DO SkipCase END
          END
        END ;
        Check(O7S.end, "no END")
      END ;
      O7G.CheckRegs;
      IF sym = O7S.semicolon THEN O7S.Get(sym)
      ELSIF sym < O7S.semicolon THEN O7S.Mark("missing semicolon?")
      END
    UNTIL sym > O7S.semicolon
  END StatSequence;

  (* Types and declarations *)

  PROCEDURE IdentList(class: INTEGER; VAR first: O7B.Object);
    VAR obj: O7B.Object;
  BEGIN
    IF sym = O7S.ident THEN
      O7B.NewObj(first, O7S.id, class); O7S.Get(sym); CheckExport(first.expo);
      WHILE sym = O7S.comma DO
        O7S.Get(sym);
        IF sym = O7S.ident THEN O7B.NewObj(obj, O7S.id, class); O7S.Get(sym); CheckExport(obj.expo)
        ELSE O7S.Mark("ident?")
        END
      END;
      IF sym = O7S.colon THEN O7S.Get(sym) ELSE O7S.Mark(":?") END
    ELSE first := NIL
    END
  END IdentList;
  
  PROCEDURE ArrayType(VAR type: O7B.Type);
    VAR x: OXG.Item; typ: O7B.Type; len: LONGINT;
  BEGIN NEW(typ); typ.form := O7B.NoTyp;
    IF sym = O7S.of THEN (*dynamic array*) len := -1
    ELSE expression(x);
      IF (x.mode = O7B.Const) & (x.type.form = O7B.Int) & (x.a >= 0) THEN len := x.a
      ELSE len := 0; O7S.Mark("not a valid length")
      END
    END ;
    IF sym = O7S.of THEN O7S.Get(sym); Type(typ.base);
      IF (typ.base.form = O7B.Array) & (typ.base.len < 0) THEN O7S.Mark("dyn array not allowed") END
    ELSIF sym = O7S.comma THEN O7S.Get(sym); ArrayType(typ.base)
    ELSE O7S.Mark("missing OF"); typ.base := O7B.intType
    END ;
    IF len >= 0 THEN typ.size := len * typ.base.size ELSE typ.size := 2*O7G.WordSize  (*array desc*) END ;
    typ.form := O7B.Array; typ.len := len; type := typ
  END ArrayType;

  PROCEDURE RecordType(VAR type: O7B.Type);
    VAR obj, obj0, new, bot, base: O7B.Object;
      typ, tp: O7B.Type;
      offset, off, n: LONGINT;
  BEGIN NEW(typ); typ.form := O7B.NoTyp; typ.base := NIL; typ.mno := level; typ.nofpar := 0;
    offset := 0; bot := NIL;
    IF sym = O7S.lparen THEN
      O7S.Get(sym); (*record extension*)
      IF sym = O7S.ident THEN
        qualident(base);
        IF base.class = O7B.Typ THEN
          IF base.type.form = O7B.Record THEN typ.base := base.type
          ELSE typ.base := O7B.intType; O7S.Mark("invalid extension")
          END ;
          typ.nofpar := typ.base.nofpar + 1; (*"nofpar" here abused for extension level*)
          bot := typ.base.dsc; offset := typ.base.size
        ELSE O7S.Mark("type expected")
        END
      ELSE O7S.Mark("ident expected")
      END ;
      Check(O7S.rparen, "no )")
    END ;
    WHILE sym = O7S.ident DO  (*fields*)
      n := 0; obj := bot;
      WHILE sym = O7S.ident DO
        obj0 := obj;
        WHILE (obj0 # NIL) & (obj0.name # O7S.id) DO obj0 := obj0.next END ;
        IF obj0 # NIL THEN O7S.Mark("mult def") END ;
        NEW(new); O7S.CopyId(new.name); new.class := O7B.Fld; new.next := obj; obj := new; INC(n);
        O7S.Get(sym); CheckExport(new.expo);
        IF (sym # O7S.comma) & (sym # O7S.colon) THEN O7S.Mark("comma expected")
        ELSIF sym = O7S.comma THEN O7S.Get(sym)
        END
      END ;
      Check(O7S.colon, "colon expected"); Type(tp);
      IF (tp.form = O7B.Array) & (tp.len < 0) THEN O7S.Mark("dyn array not allowed") END ;
      IF tp.size > 1 THEN offset := (offset+3) DIV 4 * 4 END ;
      offset := offset + n * tp.size; off := offset; obj0 := obj;
      WHILE obj0 # bot DO obj0.type := tp; obj0.lev := 0; off := off - tp.size; obj0.val := off; obj0 := obj0.next END ;
      bot := obj;
      IF sym = O7S.semicolon THEN O7S.Get(sym) ELSIF sym # O7S.end THEN O7S.Mark(" ; or END") END
    END ;
    typ.form := O7B.Record; typ.dsc := bot; typ.size := offset; type := typ
  END RecordType;

  PROCEDURE FPSection(VAR adr: LONGINT; VAR nofpar: INTEGER);
    VAR obj, first: O7B.Object; tp: O7B.Type;
      parsize: LONGINT; cl: INTEGER; rdo: BOOLEAN;
  BEGIN
    IF sym = O7S.var THEN O7S.Get(sym); cl := O7B.Par ELSE cl := O7B.Var END ;
    IdentList(cl, first); FormalType(tp, 0); rdo := FALSE;
    IF (cl = O7B.Var) & (tp.form >= O7B.Array) THEN cl := O7B.Par; rdo := TRUE END ;
    IF (tp.form = O7B.Array) & (tp.len < 0) OR (tp.form = O7B.Record) THEN
      parsize := 2*O7G.WordSize  (*open array or record, needs second word for length or type tag*)
    ELSE parsize := O7G.WordSize
    END ;
    obj := first;
    WHILE obj # NIL DO
      INC(nofpar); obj.class := cl; obj.type := tp; obj.rdo := rdo; obj.lev := level; obj.val := adr;
      adr := adr + parsize; obj := obj.next
    END ;
    IF adr >= 52 THEN O7S.Mark("too many parameters") END
  END FPSection;

  PROCEDURE ProcedureType(ptype: O7B.Type; VAR parblksize: LONGINT);
    VAR obj: O7B.Object; size: LONGINT; nofpar: INTEGER;
  BEGIN ptype.base := O7B.noType; size := parblksize; nofpar := 0; ptype.dsc := NIL;
    IF sym = O7S.lparen THEN
      O7S.Get(sym);
      IF sym = O7S.rparen THEN O7S.Get(sym)
      ELSE FPSection(size, nofpar);
        WHILE sym = O7S.semicolon DO O7S.Get(sym); FPSection(size, nofpar) END ;
        Check(O7S.rparen, "no )")
      END ;
      ptype.nofpar := nofpar; parblksize := size;
      IF sym = O7S.colon THEN  (*function*)
        O7S.Get(sym);
        IF sym = O7S.ident THEN qualident(obj);
          IF (obj.class = O7B.Typ) & (obj.type.form IN {O7B.Byte .. O7B.Pointer, O7B.Proc}) THEN ptype.base := obj.type
          ELSE O7S.Mark("illegal function type")
          END
        ELSE O7S.Mark("type identifier expected")
        END
      END
    END
  END ProcedureType;

  PROCEDURE FormalType0(VAR typ: O7B.Type; dim: INTEGER);
    VAR obj: O7B.Object; dmy: LONGINT;
  BEGIN
    IF sym = O7S.ident THEN
      qualident(obj);
      IF obj.class = O7B.Typ THEN typ := obj.type ELSE O7S.Mark("not a type"); typ := O7B.intType END
    ELSIF sym = O7S.array THEN
      O7S.Get(sym); Check(O7S.of, "OF ?");
      IF dim >= 1 THEN O7S.Mark("multi-dimensional open arrays not implemented") END ;
      NEW(typ); typ.form := O7B.Array; typ.len := -1; typ.size := 2*O7G.WordSize; 
      FormalType(typ.base, dim+1)
    ELSIF sym = O7S.procedure THEN
      O7S.Get(sym); O7B.OpenScope;
      NEW(typ); typ.form := O7B.Proc; typ.size := O7G.WordSize; dmy := 0; ProcedureType(typ, dmy);
      typ.dsc := O7B.topScope.next; O7B.CloseScope
    ELSE O7S.Mark("identifier expected"); typ := O7B.noType
    END
  END FormalType0;

  PROCEDURE Type0(VAR type: O7B.Type);
    VAR dmy: LONGINT; obj: O7B.Object; ptbase: PtrBase;
  BEGIN type := O7B.intType; (*sync*)
    IF (sym # O7S.ident) & (sym < O7S.array) THEN O7S.Mark("not a type");
      REPEAT O7S.Get(sym) UNTIL (sym = O7S.ident) OR (sym >= O7S.array)
    END ;
    IF sym = O7S.ident THEN
      qualident(obj);
      IF obj.class = O7B.Typ THEN
        IF (obj.type # NIL) & (obj.type.form # O7B.NoTyp) THEN type := obj.type END
      ELSE O7S.Mark("not a type or undefined")
      END
    ELSIF sym = O7S.array THEN O7S.Get(sym); ArrayType(type)
    ELSIF sym = O7S.record THEN
      O7S.Get(sym); RecordType(type); Check(O7S.end, "no END")
    ELSIF sym = O7S.pointer THEN
      O7S.Get(sym); Check(O7S.to, "no TO");
      NEW(type);  type.form := O7B.Pointer; type.size := O7G.WordSize; type.base := O7B.intType;
      IF sym = O7S.ident THEN
        obj := O7B.thisObj(); O7S.Get(sym);
        IF obj # NIL THEN
          IF (obj.class = O7B.Typ) & (obj.type.form IN {O7B.Record, O7B.NoTyp}) THEN type.base := obj.type
          ELSE O7S.Mark("no valid base type")
          END
        END ;
        NEW(ptbase); O7S.CopyId(ptbase.name); ptbase.type := type; ptbase.next := pbsList; pbsList := ptbase
      ELSE Type(type.base);
        IF type.base.form # O7B.Record THEN O7S.Mark("must point to record") END
      END
    ELSIF sym = O7S.procedure THEN
      O7S.Get(sym); O7B.OpenScope;
      NEW(type); type.form := O7B.Proc; type.size := O7G.WordSize; dmy := 0;
      ProcedureType(type, dmy); type.dsc := O7B.topScope.next; O7B.CloseScope
    ELSE O7S.Mark("illegal type")
    END
  END Type0;

  PROCEDURE Declarations(VAR varsize: LONGINT);
    VAR obj, first: O7B.Object;
      x: OXG.Item; tp: O7B.Type; ptbase: PtrBase;
      expo: BOOLEAN; id: O7S.Ident;
  BEGIN (*sync*) pbsList := NIL;
    IF (sym < O7S.const) & (sym # O7S.end) THEN O7S.Mark("declaration?");
      REPEAT O7S.Get(sym) UNTIL (sym >= O7S.const) OR (sym = O7S.end)
    END ;
    IF sym = O7S.const THEN
      O7S.Get(sym);
      WHILE sym = O7S.ident DO
        O7S.CopyId(id); O7S.Get(sym); CheckExport(expo);
        IF sym = O7S.eql THEN O7S.Get(sym) ELSE O7S.Mark("= ?") END;
        expression(x);
        IF (x.type.form = O7B.String) & (x.b = 2) THEN O7G.StrToChar(x) END ;
        O7B.NewObj(obj, id, O7B.Const); obj.expo := expo;
        IF x.mode = O7B.Const THEN obj.val := x.a; obj.lev := x.b; obj.type := x.type
        ELSE O7S.Mark("expression not constant"); obj.type := O7B.intType
        END;
        Check(O7S.semicolon, "; missing")
      END
    END ;
    IF sym = O7S.type THEN
      O7S.Get(sym);
      WHILE sym = O7S.ident DO
        O7S.CopyId(id); O7S.Get(sym); CheckExport(expo);
        IF sym = O7S.eql THEN O7S.Get(sym) ELSE O7S.Mark("=?") END ;
        Type(tp);
        O7B.NewObj(obj, id, O7B.Typ); obj.type := tp; obj.expo := expo; obj.lev := level; tp.typobj := obj;
        IF expo & (obj.type.form = O7B.Record) THEN obj.exno := exno; INC(exno) ELSE obj.exno := 0 END ;
        IF tp.form = O7B.Record THEN
          ptbase := pbsList;  (*check whether this is base of a pointer type; search and fixup*)
          WHILE ptbase # NIL DO
            IF obj.name = ptbase.name THEN
              IF ptbase.type.base = O7B.intType THEN ptbase.type.base := obj.type ELSE O7S.Mark("recursive record?") END
            END ;
            ptbase := ptbase.next
          END ;
          tp.len := dc;
          IF level = 0 THEN O7G.BuildTD(tp, dc) END    (*type descriptor; len used as its address*)
        END ;
        Check(O7S.semicolon, "; missing")
      END
    END ;
    IF sym = O7S.var THEN
      O7S.Get(sym);
      WHILE sym = O7S.ident DO
        IdentList(O7B.Var, first); Type(tp);
        obj := first;
        WHILE obj # NIL DO
          obj.type := tp; obj.lev := level;
          IF tp.size > 1 THEN varsize := (varsize + 3) DIV 4 * 4 (*align*) END ;
          obj.val := varsize; varsize := varsize + obj.type.size;
          IF obj.expo THEN obj.exno := exno; INC(exno) END ;
          obj := obj.next
        END ;
        Check(O7S.semicolon, "; missing")
      END
    END ;
    varsize := (varsize + 3) DIV 4 * 4;
    ptbase := pbsList;
    WHILE ptbase # NIL DO
      IF ptbase.type.base.form = O7B.Int THEN O7S.Mark("undefined pointer base of") END ;
      ptbase := ptbase.next
    END ;
    IF (sym >= O7S.const) & (sym <= O7S.var) THEN O7S.Mark("declaration in bad order") END
  END Declarations;

  PROCEDURE ProcedureDecl;
    VAR proc: O7B.Object;
      type: O7B.Type;
      procid: O7S.Ident;
      x: OXG.Item;
      locblksize, parblksize, L: LONGINT;
      int: BOOLEAN;
  BEGIN (* ProcedureDecl *) int := FALSE; O7S.Get(sym);
    IF sym = O7S.times THEN O7S.Get(sym); int := TRUE END ;
    IF sym = O7S.ident THEN
      O7S.CopyId(procid); O7S.Get(sym);
      (*Texts.WriteLn(W); Texts.WriteString(W, procid); Texts.WriteInt(W, O7G.Here(), 7);*)
      O7B.NewObj(proc, O7S.id, O7B.Const); parblksize := 4;
      NEW(type); type.form := O7B.Proc; type.size := O7G.WordSize; proc.type := type;
      CheckExport(proc.expo);
      IF proc.expo THEN proc.exno := exno; INC(exno) END ;
      O7B.OpenScope; INC(level); proc.val := -1; type.base := O7B.noType;
      ProcedureType(type, parblksize);  (*formal parameter list*)
      Check(O7S.semicolon, "no ;"); locblksize := parblksize; 
      Declarations(locblksize);
      proc.val := O7G.Here() * 4; proc.type.dsc := O7B.topScope.next;
      IF sym = O7S.procedure THEN
        L := 0; O7G.FJump(L);
        REPEAT ProcedureDecl; Check(O7S.semicolon, "no ;") UNTIL sym # O7S.procedure;
        O7G.FixLink(L); proc.val := O7G.Here() * 4; proc.type.dsc := O7B.topScope.next
      END ;
      O7G.Enter(parblksize, locblksize, int);
      IF sym = O7S.begin THEN O7S.Get(sym); StatSequence END ;
      IF sym = O7S.return THEN
        O7S.Get(sym); expression(x);
        IF type.base = O7B.noType THEN O7S.Mark("this is not a function")
        ELSIF ~CompTypes(type.base, x.type, FALSE) THEN O7S.Mark("wrong result type")
        END
      ELSIF type.base.form # O7B.NoTyp THEN
        O7S.Mark("function without result"); type.base := O7B.noType
      END ;
      O7G.Return(type.base.form, x, locblksize, int);
      O7B.CloseScope; DEC(level); Check(O7S.end, "no END");
      IF sym = O7S.ident THEN
        IF O7S.id # procid THEN O7S.Mark("no match") END ;
        O7S.Get(sym)
      ELSE O7S.Mark("no proc id")
      END
    END ;
    int := FALSE
  END ProcedureDecl;

  PROCEDURE Module;
    VAR key,pc: LONGINT;
      obj: O7B.Object;
      impid, impid1: O7S.Ident;
  BEGIN Texts.WriteString(W, "  compiling "); O7G.SetArch(arch); 
    IF arch = 0X THEN Texts.WriteString(W, "risc32 ") END;
    IF arch = 1X THEN Texts.WriteString(W, "arm32 ") END;
    IF arch = 2X THEN Texts.WriteString(W, "intel32 ") END;
    O7S.Get(sym);
    IF sym = O7S.module THEN
      O7S.Get(sym);
      IF sym = O7S.times THEN version := 0; Texts.Write(W, "*"); O7S.Get(sym) ELSE version := 1 END ;
      O7B.Init; O7B.OpenScope;
      IF sym = O7S.ident THEN
        O7S.CopyId(modid); O7S.Get(sym);
        Texts.WriteString(W, modid); Texts.Append(Oberon.Log, W.buf)
      ELSE O7S.Mark("identifier expected")
      END ;
      Check(O7S.semicolon, "no ;"); level := 0; dc := 0; exno := 1; key := 0;
      IF sym = O7S.import THEN
        O7S.Get(sym);
        WHILE sym = O7S.ident DO
          O7S.CopyId(impid); O7S.Get(sym);
          IF sym = O7S.becomes THEN
            O7S.Get(sym);
            IF sym = O7S.ident THEN O7S.CopyId(impid1); O7S.Get(sym)
            ELSE O7S.Mark("id expected")
            END
          ELSE impid1 := impid
          END ;
          O7B.Import(impid, impid1);
          IF sym = O7S.comma THEN O7S.Get(sym)
          ELSIF sym = O7S.ident THEN O7S.Mark("comma missing")
          END
        END ;
        Check(O7S.semicolon, "no ;")
      END ;
      obj := O7B.topScope.next;
      O7G.Open(version); Declarations(dc); O7G.SetDataSize((dc + 3) DIV 4 * 4);
      WHILE sym = O7S.procedure DO ProcedureDecl; Check(O7S.semicolon, "no ;") END ;
      O7G.Header;
      IF sym = O7S.begin THEN O7S.Get(sym); StatSequence END ;
      Check(O7S.end, "no END");
      IF sym = O7S.ident THEN
        IF O7S.id # modid THEN O7S.Mark("no match") END ;
        O7S.Get(sym)
      ELSE O7S.Mark("identifier missing")
      END ;
      IF sym # O7S.period THEN O7S.Mark("period missing") END ;
      IF O7S.errcnt = 0 THEN
        O7B.Export(modid, newSF, key);
        IF newSF THEN Texts.WriteLn(W); Texts.WriteString(W, "new symbol file ") END
      END ;
      IF O7S.errcnt = 0 THEN
        O7G.Close(modid, key, exno); Texts.WriteLn(W); Texts.WriteString(W, "compilation done ");
        Texts.WriteInt(W, O7G.GetPC(), 6); Texts.WriteInt(W, dc, 6)
      ELSE Texts.WriteLn(W); Texts.WriteString(W, "compilation FAILED")
      END ;
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
      O7B.CloseScope; pbsList := NIL
    ELSE O7S.Mark("must start with MODULE")
    END
  END Module;

  PROCEDURE Option(VAR S: Texts.Scanner);
  BEGIN newSF := FALSE;
    IF S.nextCh = "/" THEN
      Texts.Scan(S); Texts.Scan(S);
      IF (S.class = Texts.Name) & (S.s[0] = "s") THEN newSF := TRUE END;
      IF (S.class = Texts.Name) & (S.s[0] = "r") THEN arch := 0X END;
      IF (S.class = Texts.Name) & (S.s[0] = "a") THEN arch := 1X END;
      IF (S.class = Texts.Name) & (S.s[0] = "i") THEN arch := 2X END
    END
  END Option;

  PROCEDURE Compile*;
    VAR beg, end, time: LONGINT;
      T: Texts.Text;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class = Texts.Char THEN
      IF S.c = "@" THEN
        Option(S); Option(S); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN O7S.Init(T, beg); Module END
      ELSIF S.c = "^" THEN
        Option(S); Option(S); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN
          Texts.OpenScanner(S, T, beg); Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, S.s); NEW(T); Texts.Open(T, S.s);
            IF T.len > 0 THEN O7S.Init(T, 0); Module END
          END
        END
      END
    ELSE 
      WHILE S.class = Texts.Name DO
        NEW(T); Texts.Open(T, S.s);
        IF T.len > 0 THEN Option(S); Option(S); O7S.Init(T, 0); Module
        ELSE Texts.WriteString(W, S.s); Texts.WriteString(W, " not found");
          Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
        END ;
        IF (T.len # 0) & (O7S.errcnt = 0) THEN Texts.Scan(S) ELSE S.class := 0 END
      END
    END ;
    Oberon.Collect(0)
  END Compile;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "O7 Compiler  4.6.2014");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
  NEW(dummy); dummy.class := O7B.Var; dummy.type := O7B.intType; arch:= 0X;
  expression := expression0; Type := Type0; FormalType := FormalType0
END O7P.
