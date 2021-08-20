(* begin-package-description

**Package Overview**

C for Integrated Oberon is a front-end replacing the Oberon parser with a G parser, calling OXG to generate the program executable.

end-package-description *)

(* begin-module-short-description
implements a recursive-descent parser for the C language.
end-module-short-description *)

(* begin-module-use-description

Module CXP reads the source code of a C program and produces an executable binary module.

end-module-use-description *)
(* begin-module-develop-description

(N. Wirth 1.7.97 / 8.3.2020 Oberon compiler for RISC in Oberon-07, C. Perkins 2021 retargetted to C.)

**CXP** implements a one-pass recursive descent parser for the C language.

This module (CXP) relies on module OXG for code generation, OXB for the symbol table, execution context tracking and reserved words, and OXS
for lexical parsing and built-in type identification.

end-module-develop-description *)
MODULE CXP; (*N. Wirth 1.7.97 / 8.3.2020*)
  IMPORT Texts, Oberon, OXS, OXB, OXG;
  (*Author: Niklaus Wirth, 2014.
    Parser of C compiler. Uses Scanner OXS to obtain symbols (tokens),
    OXB for definition of data structures and for handling import and export, and
    OXG to produce binary code. CXP performs type checking and data allocation.
    Parser is target-independent, except for part of the handling of allocations.*)

  CONST

  TYPE 
    PtrBase = POINTER TO PtrBaseDesc;
    PtrBaseDesc = RECORD  (*list of names of pointer base types*)
      name: OXS.Ident; type: OXB.Type; next: PtrBase
    END ;
  
  VAR 
    sym: INTEGER;   (*last symbol read*)
    dc: LONGINT;    (*data counter*)
    level, exno, version: INTEGER;
    newSF: BOOLEAN;  (*option flag*)
    ccARCH, ccWordsize, ccStackalign: INTEGER;
    expression: PROCEDURE (VAR x: OXG.Item);  (*to avoid forward reference*)
    Type: PROCEDURE (VAR type: OXB.Type);
    FormalType: PROCEDURE (VAR typ: OXB.Type; dim: INTEGER);
    modid: OXS.Ident;
    pbsList: PtrBase;   (*list of names of pointer base types*)
    dummy: OXB.Object;
    W: Texts.Writer;

(* begin-section-description
## ---------- Tests
  end-section-description *)

  (* begin-procedure-description
---
**Check** marks an error if the current symbol does not match the expeted symbol.
  end-procedure-description *)
  PROCEDURE Check(s: INTEGER; msg: ARRAY OF CHAR);
  BEGIN
    IF sym = s THEN OXS.Get(sym) ELSE OXS.Mark(msg) END
  END Check;

  (* begin-procedure-description
---
**Qualident** generates a reference to a previously defined item if possible otherwise an error is marked.
  end-procedure-description *)
  PROCEDURE qualident(VAR obj: OXB.Object);
  BEGIN obj := OXB.thisObj(); OXS.Get(sym);
    IF obj = NIL THEN OXS.Mark("undef"); obj := dummy END ;
    IF (sym = OXS.period) & (obj.class = OXB.Mod) THEN
      OXS.Get(sym);
      IF sym = OXS.ident THEN obj := OXB.thisimport(obj); OXS.Get(sym);
        IF obj = NIL THEN OXS.Mark("undef"); obj := dummy END
      ELSE OXS.Mark("identifier expected"); obj := dummy
      END
    END
  END qualident;

  (* begin-procedure-description
---
**CheckBool** marks an error if the item is not a boolean.
  end-procedure-description *)
  PROCEDURE CheckBool(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # OXB.Bool THEN OXS.Mark("not Boolean"); x.type := OXB.boolType END
  END CheckBool;

  (* begin-procedure-description
---
**CheckInt** marks an error if the item is not an Int.
  end-procedure-description *)
  PROCEDURE CheckInt(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # OXB.Int THEN OXS.Mark("not Integer"); x.type := OXB.intType END
  END CheckInt;

  (* begin-procedure-description
---
**CheckReal** marks an error if the item is not a Real.
  end-procedure-description *)
  PROCEDURE CheckReal(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # OXB.Real THEN OXS.Mark("not Real"); x.type := OXB.realType END
  END CheckReal;

  (* begin-procedure-description
---
**CheckSet** marks an error if the item is not a Set.
  end-procedure-description *)
  PROCEDURE CheckSet(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # OXB.Set THEN OXS.Mark("not Set"); x.type := OXB.setType END 
  END CheckSet;

  (* begin-procedure-description
---
**CheckSetVal** marks an error if the item is not a Set Value.
  end-procedure-description *)
  PROCEDURE CheckSetVal(VAR x: OXG.Item);
  BEGIN
    IF x.type.form # OXB.Int THEN OXS.Mark("not Int"); x.type := OXB.setType
    ELSIF x.mode = OXB.Const THEN
      IF (x.a < 0) OR (x.a >= 32) THEN OXS.Mark("invalid set") END
    END 
  END CheckSetVal;

  (* begin-procedure-description
---
**CheckConst** marks an error if the value is not a Constant.
  end-procedure-description *)
  PROCEDURE CheckConst(VAR x: OXG.Item);
  BEGIN
    IF x.mode # OXB.Const THEN OXS.Mark("not a constant"); x.mode := OXB.Const END
  END CheckConst;

  (* begin-procedure-description
---
**CheckReadOnly** marks an error if the value is not read-only.
  end-procedure-description *)
  PROCEDURE CheckReadOnly(VAR x: OXG.Item);
  BEGIN
    IF x.rdo THEN OXS.Mark("read-only") END
  END CheckReadOnly;

  (* begin-procedure-description
---
**CheckExport** checks for an export symbol and marks an error if export not at top level.
  end-procedure-description *)
  PROCEDURE CheckExport(VAR expo: BOOLEAN);
  BEGIN
    IF sym = OXS.times THEN
      expo := TRUE; OXS.Get(sym);
      IF level # 0 THEN OXS.Mark("remove asterisk") END
    ELSE expo := FALSE
    END
  END CheckExport;

  (* begin-procedure-description
---
**IsExtension** determines if type t1 is an extension of t0.
  end-procedure-description *)
  PROCEDURE IsExtension(t0, t1: OXB.Type): BOOLEAN;
  BEGIN (*t1 is an extension of t0*)
    RETURN (t0 = t1) OR (t1 # NIL) & IsExtension(t0, t1.base)
  END IsExtension;

  (* expressions *)

(* begin-section-description
## ---------- Expressions
  end-section-description *)

  (* begin-procedure-description
---
**TypeTest** checks for assignment type compatibility.
  end-procedure-description *)
  PROCEDURE TypeTest(VAR x: OXG.Item; T: OXB.Type; guard: BOOLEAN);
    VAR xt: OXB.Type;
  BEGIN xt := x.type;
    IF (T.form = xt.form ) & ((T.form = OXB.Pointer) OR (T.form = OXB.Record) & (x.mode = OXB.Par)) THEN
      WHILE (xt # T) & (xt # NIL) DO xt := xt.base END ;
      IF xt # T THEN xt := x.type;
        IF xt.form = OXB.Pointer THEN
          IF IsExtension(xt.base, T.base) THEN OXG.TypeTest(x, T.base, FALSE, guard); x.type := T
          ELSE OXS.Mark("not an extension")
          END
        ELSIF (xt.form = OXB.Record) & (x.mode = OXB.Par) THEN
          IF IsExtension(xt, T) THEN  OXG.TypeTest(x, T, TRUE, guard); x.type := T
          ELSE OXS.Mark("not an extension")
          END
        ELSE OXS.Mark("incompatible types")
        END
      ELSIF ~guard THEN OXG.TypeTest(x, NIL, FALSE, FALSE)
      END
    ELSE OXS.Mark("type mismatch")
    END ;
    IF ~guard THEN x.type := OXB.boolType END
  END TypeTest;

  (* begin-procedure-description
---
**selector** generates the array item, procedure, or method dereference on an array or record.
  end-procedure-description *)
  PROCEDURE selector(VAR x: OXG.Item);
    VAR y: OXG.Item; obj: OXB.Object;
  BEGIN
    WHILE (sym = OXS.lbrak) OR (sym = OXS.period) OR (sym = OXS.arrow)
        OR (sym = OXS.lparen) & (x.type.form IN {OXB.Record, OXB.Pointer}) DO
      IF sym = OXS.lbrak THEN
        REPEAT OXS.Get(sym); expression(y);
          IF x.type.form = OXB.Array THEN
            CheckInt(y); OXG.Index(x, y); x.type := x.type.base
          ELSE OXS.Mark("not an array")
          END
        UNTIL sym # OXS.comma;
        Check(OXS.rbrak, "no ]")
      ELSIF sym = OXS.period THEN OXS.Get(sym);
        IF sym = OXS.ident THEN
          IF x.type.form = OXB.Pointer THEN OXG.DeRef(x); x.type := x.type.base END ;
          IF x.type.form = OXB.Record THEN
            obj := OXB.thisfield(x.type); OXS.Get(sym);
            IF obj # NIL THEN OXG.Field(x, obj); x.type := obj.type
            ELSE OXS.Mark("undef")
            END
          ELSE OXS.Mark("not a record")
          END
        ELSE OXS.Mark("ident?")
        END
      ELSIF sym = OXS.arrow THEN
        OXS.Get(sym);
        IF x.type.form = OXB.Pointer THEN OXG.DeRef(x); x.type := x.type.base
        ELSE OXS.Mark("not a pointer")
        END
      ELSIF (sym = OXS.lparen) & (x.type.form IN {OXB.Record, OXB.Pointer}) THEN (*type guard*)
        OXS.Get(sym);
        IF sym = OXS.ident THEN
          qualident(obj);
          IF obj.class = OXB.Typ THEN TypeTest(x, obj.type, TRUE)
          ELSE OXS.Mark("guard type expected")
          END
        ELSE OXS.Mark("not an identifier")
        END ;
        Check(OXS.rparen, " ) missing")
      END
    END
  END selector;

  (* begin-procedure-description
---
**EqualSignatures** verifies that a procedure may be assigned to a procedure variable.
  end-procedure-description *)
  PROCEDURE EqualSignatures(t0, t1: OXB.Type): BOOLEAN;
    VAR p0, p1: OXB.Object; com: BOOLEAN;
  BEGIN com := TRUE;
    IF (t0.base = t1.base) & (t0.nofpar = t1.nofpar) THEN
      p0 := t0.dsc; p1 := t1.dsc;
      WHILE p0 # NIL DO
        IF (p0.class = p1.class) &  (p0.rdo = p1.rdo) &
          ((p0.type = p1.type) OR
          (p0.type.form = OXB.Array) & (p1.type.form = OXB.Array) & (p0.type.len = p1.type.len) & (p0.type.base = p1.type.base) OR
          (p0.type.form = OXB.Proc) & (p1.type.form = OXB.Proc) & EqualSignatures(p0.type, p1.type))
        THEN p0 := p0.next; p1 := p1.next
        ELSE p0 := NIL; com := FALSE
        END
      END
    ELSE com := FALSE
    END ;
    RETURN com
  END EqualSignatures;

  (* begin-procedure-description
---
**CompTypes** verifies assigment compatibility by type.
  end-procedure-description *)
  PROCEDURE CompTypes(t0, t1: OXB.Type; varpar: BOOLEAN): BOOLEAN;
  BEGIN (*check for assignment compatibility*)
    RETURN (t0 = t1)    (*openarray assignment disallowed in OXG*)
      OR (t0.form = OXB.Array) & (t1.form = OXB.Array) & (t0.base =  t1.base) & (t0.len = t1.len)
      OR (t0.form = OXB.Record) & (t1.form = OXB.Record)  & IsExtension(t0, t1)
      OR ~varpar &
        ((t0.form = OXB.Pointer) & (t1.form = OXB.Pointer)  & IsExtension(t0.base, t1.base)
        OR (t0.form = OXB.Proc) & (t1.form = OXB.Proc) & EqualSignatures(t0, t1)
        OR (t0.form IN {OXB.Pointer, OXB.Proc}) & (t1.form = OXB.NilTyp))
  END CompTypes;

  (* begin-procedure-description
---
**Parameter** consumes a function call parameter and produces function call proloogue code for the parameter.
  end-procedure-description *)
  PROCEDURE Parameter(par: OXB.Object);
    VAR x: OXG.Item; varpar: BOOLEAN;
  BEGIN expression(x);
    IF par # NIL THEN
      varpar := par.class = OXB.Par;
      IF CompTypes(par.type, x.type, varpar) THEN
        IF ~varpar THEN OXG.ValueParam(x)
        ELSE (*par.class = Par*)
          IF ~par.rdo THEN CheckReadOnly(x) END ;
          OXG.VarParam(x, par.type)
        END
      ELSIF (x.type.form = OXB.Array) & (par.type.form = OXB.Array) &
          (x.type.base = par.type.base) & (par.type.len < 0) THEN
        IF ~par.rdo THEN CheckReadOnly(x) END ;
        OXG.OpenArrayParam(x)
      ELSIF (x.type.form = OXB.String) & varpar & par.rdo & (par.type.form = OXB.Array) & 
          (par.type.base.form = OXB.Char) & (par.type.len < 0) THEN OXG.StringParam(x)
      ELSIF ~varpar & (par.type.form = OXB.Int) & (x.type.form = OXB.Int) THEN OXG.ValueParam(x)  (*BYTE*)
      ELSIF (x.type.form = OXB.String) & (x.b = 2) & (par.class = OXB.Var) & (par.type.form = OXB.Char) THEN
        OXG.StrToChar(x); OXG.ValueParam(x)
      ELSIF (par.type.form = OXB.Array) & (par.type.base = OXB.byteType) & 
          (par.type.len >= 0) & (par.type.size = x.type.size) THEN
        OXG.VarParam(x, par.type)
      ELSE OXS.Mark("incompatible parameters")
      END
    END
  END Parameter;

  (* begin-procedure-description
---
**ParamList** consumes the function call parameters, resulting in a function call prologue.
  end-procedure-description *)
  PROCEDURE ParamList(VAR x: OXG.Item);
    VAR n: INTEGER; par: OXB.Object;
  BEGIN par := x.type.dsc; n := 0;
    IF sym # OXS.rparen THEN
      Parameter(par); n := 1;
      WHILE sym <= OXS.comma DO
        Check(OXS.comma, "comma?");
        IF par # NIL THEN par := par.next END ;
        INC(n); Parameter(par)
      END ;
      Check(OXS.rparen, ") missing")
    ELSE OXS.Get(sym);
    END ;
    IF n < x.type.nofpar THEN OXS.Mark("too few params")
    ELSIF n > x.type.nofpar THEN OXS.Mark("too many params")
    END
  END ParamList;

  (* begin-procedure-description
---
**StandFunc** consumes standard language functions and produces inline code for those functions.

Standard functions include: `ABS` `ODD` `FLOOR` `FLT` `ORD` `CHR` `LEN` `ADC` `SBC` `UML` `BIT` `REG` `VAL` `ADR` `SIZE` `COND` `H`
  end-procedure-description *)
  PROCEDURE StandFunc(VAR x: OXG.Item; fct: LONGINT; restyp: OXB.Type);
    VAR y: OXG.Item; n, npar: LONGINT;
  BEGIN Check(OXS.lparen, "no (");
    npar := fct MOD 10; fct := fct DIV 10; expression(x); n := 1;
    WHILE sym = OXS.comma DO OXS.Get(sym); expression(y); INC(n) END ;
    Check(OXS.rparen, "no )");
    IF n = npar THEN
      IF fct = 0 THEN (*ABS*)
        IF x.type.form IN {OXB.Int, OXB.Real} THEN OXG.Abs(x); restyp := x.type ELSE OXS.Mark("bad type") END
      ELSIF fct = 1 THEN (*ODD*) CheckInt(x); OXG.Odd(x)
      ELSIF fct = 2 THEN (*FLOOR*) CheckReal(x); OXG.Floor(x)
      ELSIF fct = 3 THEN (*FLT*) CheckInt(x); OXG.Float(x)
      ELSIF fct = 4 THEN (*ORD*)
        IF x.type.form <= OXB.Proc THEN OXG.Ord(x)
        ELSIF (x.type.form = OXB.String) & (x.b = 2) THEN OXG.StrToChar(x)
        ELSE OXS.Mark("bad type")
        END
      ELSIF fct = 5 THEN (*CHR*) CheckInt(x); OXG.Ord(x)
      ELSIF fct = 6 THEN (*LEN*)
          IF x.type.form = OXB.Array THEN OXG.Len(x) ELSE OXS.Mark("not an array") END
      ELSIF fct IN {7, 8, 9} THEN (*LSL, ASR, ROR*) CheckInt(y);
        IF x.type.form IN {OXB.Int, OXB.Set} THEN OXG.Shift(fct-7, x, y); restyp := x.type ELSE OXS.Mark("bad type") END
      ELSIF fct = 11 THEN (*ADC*) OXG.ADC(x, y)
      ELSIF fct = 12 THEN (*SBC*) OXG.SBC(x, y)
      ELSIF fct = 13 THEN (*UML*) OXG.UML(x, y)
      ELSIF fct = 14 THEN (*BIT*) CheckInt(x); CheckInt(y); OXG.Bit(x, y)
      ELSIF fct = 15 THEN (*REG*) CheckConst(x); CheckInt(x); OXG.Register(x)
      ELSIF fct = 16 THEN (*VAL*)
        IF (x.mode= OXB.Typ) & (x.type.size <= y.type.size) THEN restyp := x.type; x := y
        ELSE OXS.Mark("casting not allowed")
        END
      ELSIF fct = 17 THEN (*ADR*) OXG.Adr(x)
      ELSIF fct = 18 THEN (*SIZE*)
        IF x.mode = OXB.Typ THEN OXG.MakeConstItem(x, OXB.intType, x.type.size)
        ELSE OXS.Mark("must be a type")
        END
      ELSIF fct = 19 THEN (*COND*) CheckConst(x); CheckInt(x); OXG.Condition(x)
      ELSIF fct = 20 THEN (*H*) CheckConst(x); CheckInt(x); OXG.H(x)
      END ;
      x.type := restyp
    ELSE OXS.Mark("wrong nof params")
    END
  END StandFunc;

  (* begin-procedure-description
---
**element** produces a reference to an element in a set.
  end-procedure-description *)
  PROCEDURE element(VAR x: OXG.Item);
    VAR y: OXG.Item;
  BEGIN expression(x); CheckSetVal(x);
    IF sym = OXS.upto THEN OXS.Get(sym); expression(y); CheckSetVal(y); OXG.Set(x, y)
    ELSE OXG.Singleton(x)
    END ;
    x.type := OXB.setType
  END element;
  
  (* begin-procedure-description
---
**set** produces a set from elements.
  end-procedure-description *)
  PROCEDURE set(VAR x: OXG.Item);
    VAR y: OXG.Item;
  BEGIN
    IF sym >= OXS.if THEN
      IF sym # OXS.rbrace THEN OXS.Mark(" } missing") END ;
      OXG.MakeConstItem(x, OXB.setType, 0) (*empty set*)
    ELSE element(x);
      WHILE (sym < OXS.rparen) OR (sym > OXS.rbrace) DO
        IF sym = OXS.comma THEN OXS.Get(sym)
        ELSIF sym # OXS.rbrace THEN OXS.Mark("missing comma")
        END ;
        element(y); OXG.SetOp(OXS.plus, x, y)
      END
    END
  END set; 

  (* begin-procedure-description
---
**factor** generates code that produces a value from identifiers, applications of functions and procedures, etc. for use in a calculation or assignment.
  end-procedure-description *)
  PROCEDURE factor(VAR x: OXG.Item);
    VAR obj: OXB.Object; rx: LONGINT;
  BEGIN (*sync*)
    IF (sym < OXS.char) OR (sym > OXS.ident) THEN OXS.Mark("expression expected");
      REPEAT OXS.Get(sym) UNTIL (sym >= OXS.char) & (sym <= OXS.for) OR (sym >= OXS.then)
    END ;
    IF sym = OXS.ident THEN
      qualident(obj);  
      IF obj.class = OXB.SFunc THEN StandFunc(x, obj.val, obj.type)
      ELSE OXG.MakeItem(x, obj, level); selector(x);
        IF sym = OXS.lparen THEN
          OXS.Get(sym);
          IF (x.type.form = OXB.Proc) & (x.type.base.form # OXB.NoTyp) THEN
            OXG.PrepCall(x, rx); ParamList(x); OXG.Call(x, rx); x.type := x.type.base
          ELSE OXS.Mark("not a function"); ParamList(x)
          END
        END
      END
    ELSIF sym = OXS.int THEN OXG.MakeConstItem(x, OXB.intType, OXS.ival); OXS.Get(sym)
    ELSIF sym = OXS.real THEN OXG.MakeRealItem(x, OXS.rval); OXS.Get(sym)
    ELSIF sym = OXS.char THEN OXG.MakeConstItem(x, OXB.charType, OXS.ival); OXS.Get(sym)
    ELSIF sym = OXS.nil THEN OXS.Get(sym); OXG.MakeConstItem(x, OXB.nilType, 0)
    ELSIF sym = OXS.string THEN OXG.MakeStringItem(x, OXS.slen); OXS.Get(sym)
    ELSIF sym = OXS.lparen THEN OXS.Get(sym); expression(x); Check(OXS.rparen, "no )")
    ELSIF sym = OXS.lbrace THEN OXS.Get(sym); set(x); Check(OXS.rbrace, "no }")
    ELSIF sym = OXS.not THEN OXS.Get(sym); factor(x); CheckBool(x); OXG.Not(x)
    ELSIF sym = OXS.false THEN OXS.Get(sym); OXG.MakeConstItem(x, OXB.boolType, 0)
    ELSIF sym = OXS.true THEN OXS.Get(sym); OXG.MakeConstItem(x, OXB.boolType, 1)
    ELSE OXS.Mark("not a factor"); OXG.MakeConstItem(x, OXB.intType, 0)
    END
  END factor;

  (* begin-procedure-description
---
**term** combines factors via multiplication and division, resulting in a value.
  end-procedure-description *)
  PROCEDURE term(VAR x: OXG.Item);
    VAR y: OXG.Item; op, f: INTEGER;
  BEGIN factor(x); f := x.type.form;
    WHILE (sym >= OXS.times) & (sym <= OXS.and) DO
      op := sym; OXS.Get(sym);
      IF op = OXS.times THEN
        IF f = OXB.Int THEN factor(y); CheckInt(y); OXG.MulOp(x, y)
        ELSIF f = OXB.Real THEN factor(y); CheckReal(y); OXG.RealOp(op, x, y)
        ELSIF f = OXB.Set THEN factor(y); CheckSet(y); OXG.SetOp(op, x, y)
        ELSE OXS.Mark("bad type")
        END
      ELSIF (op = OXS.div) OR (op = OXS.mod) THEN
        CheckInt(x); factor(y); CheckInt(y); OXG.DivOp(op, x, y)
      ELSIF op = OXS.rdiv THEN
        IF f = OXB.Real THEN factor(y); CheckReal(y); OXG.RealOp(op, x, y)
        ELSIF f = OXB.Set THEN factor(y); CheckSet(y); OXG.SetOp(op, x, y)
        ELSE OXS.Mark("bad type")
        END
      ELSE (*op = and*) CheckBool(x); OXG.And1(x); factor(y); CheckBool(y); OXG.And2(x, y)
      END
    END
  END term;

  (* begin-procedure-description
---
**SimpleExpression** combines terms via addition, subtraction, boolean, and set operations, resulting in a value.
  end-procedure-description *)
  PROCEDURE SimpleExpression(VAR x: OXG.Item);
    VAR y: OXG.Item; op: INTEGER;
  BEGIN
    IF sym = OXS.minus THEN OXS.Get(sym); term(x);
      IF x.type.form IN {OXB.Int, OXB.Real, OXB.Set} THEN OXG.Neg(x) ELSE CheckInt(x) END
    ELSIF sym = OXS.plus THEN OXS.Get(sym); term(x);
    ELSE term(x)
    END ;
    WHILE (sym >= OXS.plus) & (sym <= OXS.or) DO
      op := sym; OXS.Get(sym);
      IF op = OXS.or THEN OXG.Or1(x); CheckBool(x); term(y); CheckBool(y); OXG.Or2(x, y)
      ELSIF x.type.form = OXB.Int THEN term(y); CheckInt(y); OXG.AddOp(op, x, y)
      ELSIF x.type.form = OXB.Real THEN term(y); CheckReal(y); OXG.RealOp(op, x, y)
      ELSE CheckSet(x); term(y); CheckSet(y); OXG.SetOp(op, x, y)
      END
    END
  END SimpleExpression;

  (* begin-procedure-description
---
**expression0** produces code handling arbitrary arithmetic and logical operations, resulting in a value.

expression0 is assigned to the procedure variable `expression` to allow the forward reference.

  end-procedure-description *)
  PROCEDURE expression0(VAR x: OXG.Item);
    VAR y: OXG.Item; obj: OXB.Object; rel, xf, yf: INTEGER;
  BEGIN SimpleExpression(x);
    IF (sym >= OXS.eql) & (sym <= OXS.geq) THEN
      rel := sym; OXS.Get(sym); SimpleExpression(y); xf := x.type.form; yf := y.type.form;
      IF x.type = y.type THEN
        IF (xf IN {OXB.Char, OXB.Int}) THEN OXG.IntRelation(rel, x, y)
        ELSIF xf = OXB.Real THEN OXG.RealRelation(rel, x, y)
        ELSIF (xf IN {OXB.Set, OXB.Pointer, OXB.Proc, OXB.NilTyp, OXB.Bool}) THEN
          IF rel <= OXS.neq THEN OXG.IntRelation(rel, x, y) ELSE OXS.Mark("only = or #") END
        ELSIF (xf = OXB.Array) & (x.type.base.form = OXB.Char) OR (xf = OXB.String) THEN
          OXG.StringRelation(rel, x, y)
        ELSE OXS.Mark("illegal comparison")
        END
      ELSIF (xf IN {OXB.Pointer, OXB.Proc}) & (yf = OXB.NilTyp)
          OR (yf IN {OXB.Pointer, OXB.Proc}) & (xf = OXB.NilTyp) THEN
        IF rel <= OXS.neq THEN OXG.IntRelation(rel, x,  y) ELSE OXS.Mark("only = or #") END
      ELSIF (xf = OXB.Pointer) & (yf = OXB.Pointer) &
          (IsExtension(x.type.base, y.type.base) OR IsExtension(y.type.base, x.type.base))
          OR (xf = OXB.Proc) & (yf = OXB.Proc) & EqualSignatures(x.type, y.type) THEN
        IF rel <= OXS.neq THEN OXG.IntRelation(rel,  x, y) ELSE OXS.Mark("only = or #") END
      ELSIF (xf = OXB.Array) & (x.type.base.form = OXB.Char) &
            ((yf = OXB.String) OR (yf = OXB.Array) & (y.type.base.form = OXB.Char))
          OR (yf = OXB.Array) & (y.type.base.form = OXB.Char) & (xf = OXB.String) THEN
        OXG.StringRelation(rel, x, y)
      ELSIF (xf = OXB.Char) & (yf = OXB.String) & (y.b = 2) THEN
        OXG.StrToChar(y); OXG.IntRelation(rel, x, y)
      ELSIF (yf = OXB.Char) & (xf = OXB.String) & (x.b = 2) THEN
        OXG.StrToChar(x); OXG.IntRelation(rel, x, y)
      ELSIF (xf = OXB.Int) & (yf = OXB.Int) THEN OXG.IntRelation(rel,  x, y)  (*BYTE*)
      ELSE OXS.Mark("illegal comparison")
      END ;
      x.type := OXB.boolType
    ELSIF sym = OXS.in THEN
      OXS.Get(sym); CheckInt(x); SimpleExpression(y); CheckSet(y); OXG.In(x, y) ;
      x.type := OXB.boolType
    ELSIF sym = OXS.is THEN
      OXS.Get(sym); qualident(obj); TypeTest(x, obj.type, FALSE) ;
      x.type := OXB.boolType
    END
  END expression0;

  (* statements *)

(* begin-section-description
## ---------- Statements
  end-section-description *)

  (* begin-procedure-description
---
**StandProc** handles standard (predefined) procedures.
  end-procedure-description *)
  PROCEDURE StandProc(pno: LONGINT);
    VAR nap, npar: LONGINT; (*nof actual/formal parameters*)
      x, y, z: OXG.Item;
  BEGIN Check(OXS.lparen, "no (");
    npar := pno MOD 10; pno := pno DIV 10; expression(x); nap := 1;
    IF sym = OXS.comma THEN
      OXS.Get(sym); expression(y); nap := 2; z.type := OXB.noType;
      WHILE sym = OXS.comma DO OXS.Get(sym); expression(z); INC(nap) END
    ELSE y.type := OXB.noType
    END ;
    Check(OXS.rparen, "no )");
    IF (npar = nap) OR (pno IN {0, 1}) THEN 
      IF pno IN {0, 1} THEN (*INC, DEC*)
        CheckInt(x); CheckReadOnly(x);
        IF y.type # OXB.noType THEN CheckInt(y) END ;
        OXG.Increment(pno, x, y)
      ELSIF pno IN {2, 3} THEN (*INCL, EXCL*)
        CheckSet(x); CheckReadOnly(x); CheckInt(y); OXG.Include(pno-2, x, y)
      ELSIF pno = 4 THEN CheckBool(x); OXG.Assert(x)
      ELSIF pno = 5 THEN(*NEW*) CheckReadOnly(x);
         IF (x.type.form = OXB.Pointer) & (x.type.base.form = OXB.Record) THEN OXG.New(x)
         ELSE OXS.Mark("not a pointer to record")
         END
      ELSIF pno = 6 THEN CheckReal(x); CheckInt(y); CheckReadOnly(x); OXG.Pack(x, y)
      ELSIF pno = 7 THEN CheckReal(x); CheckInt(y); CheckReadOnly(x); OXG.Unpk(x, y)
      ELSIF pno = 8 THEN
        IF x.type.form <= OXB.Set THEN OXG.Led(x) ELSE OXS.Mark("bad type") END
      ELSIF pno = 10 THEN CheckInt(x); OXG.Get(x, y)
      ELSIF pno = 11 THEN CheckInt(x); OXG.Put(x, y)
      ELSIF pno = 12 THEN CheckInt(x); CheckInt(y); CheckInt(z); OXG.Copy(x, y, z)
      ELSIF pno = 13 THEN CheckConst(x); CheckInt(x); OXG.LDPSR(x)
      ELSIF pno = 14 THEN CheckInt(x); OXG.LDREG(x, y)
      ELSIF pno = 21 THEN CheckInt(x); CheckInt(y); OXG.REGREG(x, y)
      END
    ELSE OXS.Mark("wrong nof parameters")
    END
  END StandProc;

  (* begin-procedure-description
---
**StatSequence** matches a statement sequence.
  end-procedure-description *)
  PROCEDURE StatSequence;
    VAR obj: OXB.Object;
      orgtype: OXB.Type; (*original type of case var*)
      x, y, z, w: OXG.Item;
      L0, L1, rx: LONGINT;

  (* begin-procedure-description
**TypeCase** (interior procedure)
  end-procedure-description *)
    PROCEDURE TypeCase(obj: OXB.Object; VAR x: OXG.Item);
      VAR typobj: OXB.Object;
    BEGIN
      IF sym = OXS.ident THEN
        qualident(typobj); OXG.MakeItem(x, obj, level);
        IF typobj.class # OXB.Typ THEN OXS.Mark("not a type") END ;
        TypeTest(x, typobj.type, FALSE); obj.type := typobj.type;
        OXG.CFJump(x); Check(OXS.colon, ": expected"); StatSequence
      ELSE OXG.CFJump(x); OXS.Mark("type id expected")
      END
     END TypeCase;

  (* begin-procedure-description
**SkipCase** (interior procedure)
  end-procedure-description *)
    PROCEDURE SkipCase;
    BEGIN 
      WHILE sym # OXS.colon DO OXS.Get(sym) END ;
      OXS.Get(sym); StatSequence
    END SkipCase;

  BEGIN (* StatSequence *)
    REPEAT (*sync*) obj := NIL;
      IF ~((sym >= OXS.ident)  & (sym <= OXS.for) OR (sym >= OXS.semicolon)) THEN
        OXS.Mark("statement expected");
        REPEAT OXS.Get(sym) UNTIL (sym >= OXS.ident)
      END ;
      IF sym = OXS.ident THEN
        qualident(obj); OXG.MakeItem(x, obj, level);
        IF x.mode = OXB.SProc THEN StandProc(obj.val)
        ELSE selector(x);
          IF sym = OXS.becomes THEN (*assignment*)
            OXS.Get(sym); CheckReadOnly(x); expression(y);
            IF CompTypes(x.type, y.type, FALSE) THEN
              IF (x.type.form <= OXB.Pointer) OR (x.type.form = OXB.Proc) THEN OXG.Store(x, y)
              ELSE OXG.StoreStruct(x, y)
              END
            ELSIF (x.type.form = OXB.Array) & (y.type.form = OXB.Array) & (x.type.base = y.type.base) & (y.type.len < 0) THEN
              OXG.StoreStruct(x, y)
            ELSIF (x.type.form = OXB.Array) & (x.type.base.form = OXB.Char) & (y.type.form = OXB.String) THEN
              OXG.CopyString(x, y)
            ELSIF (x.type.form = OXB.Int) & (y.type.form = OXB.Int) THEN OXG.Store(x, y)  (*BYTE*)
            ELSIF (x.type.form = OXB.Char) & (y.type.form = OXB.String) & (y.b = 2) THEN
              OXG.StrToChar(y); OXG.Store(x, y)
            ELSE OXS.Mark("illegal assignment")
            END
          ELSIF sym = OXS.eql THEN OXS.Mark("should be :="); OXS.Get(sym); expression(y)
          ELSIF sym = OXS.lparen THEN (*procedure call*)
            OXS.Get(sym);
            IF (x.type.form = OXB.Proc) & (x.type.base.form = OXB.NoTyp) THEN
              OXG.PrepCall(x, rx); ParamList(x); OXG.Call(x, rx)
            ELSE OXS.Mark("not a procedure"); ParamList(x)
            END
          ELSIF x.type.form = OXB.Proc THEN (*procedure call without parameters*)
            IF x.type.nofpar > 0 THEN OXS.Mark("missing parameters") END ;
            IF x.type.base.form = OXB.NoTyp THEN OXG.PrepCall(x, rx); OXG.Call(x, rx) ELSE OXS.Mark("not a procedure") END
          ELSIF x.mode = OXB.Typ THEN OXS.Mark("illegal assignment")
          ELSE OXS.Mark("not a procedure")
          END
        END
      ELSIF sym = OXS.if THEN
        OXS.Get(sym); expression(x); CheckBool(x); OXG.CFJump(x);
        Check(OXS.then, "no THEN");
        StatSequence; L0 := 0;
        WHILE sym = OXS.elsif DO
          OXS.Get(sym); OXG.FJump(L0); OXG.Fixup(x); expression(x); CheckBool(x);
          OXG.CFJump(x); Check(OXS.then, "no THEN"); StatSequence
        END ;
        IF sym = OXS.else THEN OXS.Get(sym); OXG.FJump(L0); OXG.Fixup(x); StatSequence
        ELSE OXG.Fixup(x)
        END ;
        OXG.FixLink(L0); Check(OXS.end, "no END")
      ELSIF sym = OXS.while THEN
        OXS.Get(sym); L0 := OXG.Here(); expression(x); CheckBool(x); OXG.CFJump(x);
        Check(OXS.do, "no DO"); StatSequence; OXG.BJump(L0);
        WHILE sym = OXS.elsif DO
          OXS.Get(sym); OXG.Fixup(x); expression(x); CheckBool(x); OXG.CFJump(x);
          Check(OXS.do, "no DO"); StatSequence; OXG.BJump(L0)
        END ;
        OXG.Fixup(x); Check(OXS.end, "no END")
      ELSIF sym = OXS.repeat THEN
        OXS.Get(sym); L0 := OXG.Here(); StatSequence;
        IF sym = OXS.until THEN
          OXS.Get(sym); expression(x); CheckBool(x); OXG.CBJump(x, L0)
        ELSE OXS.Mark("missing UNTIL")
        END
      ELSIF sym = OXS.for THEN
        OXS.Get(sym);
        IF sym = OXS.ident THEN
          qualident(obj); OXG.MakeItem(x, obj, level); CheckInt(x); CheckReadOnly(x);
          IF sym = OXS.becomes THEN
            OXS.Get(sym); expression(y); CheckInt(y); OXG.For0(x, y); L0 := OXG.Here();
            Check(OXS.to, "no TO"); expression(z); CheckInt(z); obj.rdo := TRUE;
            IF sym = OXS.by THEN OXS.Get(sym); expression(w); CheckConst(w); CheckInt(w)
            ELSE OXG.MakeConstItem(w, OXB.intType, 1)
            END ;
            Check(OXS.do, "no DO"); OXG.For1(x, y, z, w, L1);
            StatSequence; Check(OXS.end, "no END");
            OXG.For2(x, y, w); OXG.BJump(L0); OXG.FixLink(L1); obj.rdo := FALSE
          ELSE OXS.Mark(":= expected")
          END
        ELSE OXS.Mark("identifier expected")
        END
      ELSIF sym = OXS.case THEN
        OXS.Get(sym);
        IF sym = OXS.ident THEN
          qualident(obj); orgtype := obj.type;
          IF (orgtype.form = OXB.Pointer) OR (orgtype.form = OXB.Record) & (obj.class = OXB.Par) THEN
            Check(OXS.of, "OF expected"); TypeCase(obj, x); L0 := 0;
            WHILE sym = OXS.bar DO
              OXS.Get(sym); OXG.FJump(L0); OXG.Fixup(x); obj.type := orgtype; TypeCase(obj, x)
            END ;
            OXG.Fixup(x); OXG.FixLink(L0); obj.type := orgtype
          ELSE OXS.Mark("numeric case not implemented");
            Check(OXS.of, "OF expected"); SkipCase;
            WHILE sym = OXS.bar DO SkipCase END
          END
        ELSE OXS.Mark("ident expected")
        END ;
        Check(OXS.end, "no END")
      END ;
      OXG.CheckRegs;
      IF sym = OXS.semicolon THEN OXS.Get(sym)
      ELSIF sym < OXS.semicolon THEN OXS.Mark("missing semicolon?")
      END
    UNTIL sym > OXS.semicolon
  END StatSequence;

  (* Types and declarations *)

(* begin-section-description
## ---------- Types and declarations
  end-section-description *)

  (* begin-procedure-description
---
**IdentList** matches a comma separated list of identifiers.
  end-procedure-description *)
  PROCEDURE IdentList(class: INTEGER; VAR first: OXB.Object);
    VAR obj: OXB.Object;
  BEGIN
    IF sym = OXS.ident THEN
      OXB.NewObj(first, OXS.id, class); OXS.Get(sym); CheckExport(first.expo);
      WHILE sym = OXS.comma DO
        OXS.Get(sym);
        IF sym = OXS.ident THEN OXB.NewObj(obj, OXS.id, class); OXS.Get(sym); CheckExport(obj.expo)
        ELSE OXS.Mark("ident?")
        END
      END;
      IF sym = OXS.colon THEN OXS.Get(sym) ELSE OXS.Mark(":?") END
    ELSE first := NIL
    END
  END IdentList;
  
  (* begin-procedure-description
---
**ArrayType** matches the definiton of an Array Type or marks an error.
  end-procedure-description *)
  PROCEDURE ArrayType(VAR type: OXB.Type);
    VAR x: OXG.Item; typ: OXB.Type; len: LONGINT;
  BEGIN NEW(typ); typ.form := OXB.NoTyp;
    expression(x);
    IF (x.mode = OXB.Const) & (x.type.form = OXB.Int) & (x.a >= 0) THEN len := x.a
    ELSE len := 1; OXS.Mark("not a valid length")
    END ;
    IF sym = OXS.of THEN OXS.Get(sym); Type(typ.base);
      IF (typ.base.form = OXB.Array) & (typ.base.len < 0) THEN OXS.Mark("dyn array not allowed") END
    ELSIF sym = OXS.comma THEN OXS.Get(sym); ArrayType(typ.base)
    ELSE OXS.Mark("missing OF"); typ.base := OXB.intType
    END ;
    typ.size := (len * typ.base.size + 3) DIV 4 * 4;
    typ.form := OXB.Array; typ.len := len; type := typ
  END ArrayType;

  (* begin-procedure-description
---
**RecordType** matches the definition of a Record Type or marks an error.
  end-procedure-description *)
  PROCEDURE RecordType(VAR type: OXB.Type);
    VAR obj, obj0, new, bot, base: OXB.Object;
      typ, tp: OXB.Type;
      offset, off, n: LONGINT;
  BEGIN NEW(typ); typ.form := OXB.NoTyp; typ.base := NIL; typ.mno := -level; typ.nofpar := 0; offset := 0; bot := NIL;
    IF sym = OXS.lparen THEN
      OXS.Get(sym); (*record extension*)
      IF level # 0 THEN OXS.Mark("extension of local types not implemented") END ;
      IF sym = OXS.ident THEN
        qualident(base);
        IF base.class = OXB.Typ THEN
          IF base.type.form = OXB.Record THEN typ.base := base.type
          ELSE typ.base := OXB.intType; OXS.Mark("invalid extension")
          END ;
          typ.nofpar := typ.base.nofpar + 1; (*"nofpar" here abused for extension level*)
          bot := typ.base.dsc; offset := typ.base.size
        ELSE OXS.Mark("type expected")
        END
      ELSE OXS.Mark("ident expected")
      END ;
      Check(OXS.rparen, "no )")
    END ;
    WHILE sym = OXS.ident DO  (*fields*)
      n := 0; obj := bot;
      WHILE sym = OXS.ident DO
        obj0 := obj;
        WHILE (obj0 # NIL) & (obj0.name # OXS.id) DO obj0 := obj0.next END ;
        IF obj0 # NIL THEN OXS.Mark("mult def") END ;
        NEW(new); OXS.CopyId(new.name); new.class := OXB.Fld; new.next := obj; obj := new; INC(n);
        OXS.Get(sym); CheckExport(new.expo);
        IF (sym # OXS.comma) & (sym # OXS.colon) THEN OXS.Mark("comma expected")
        ELSIF sym = OXS.comma THEN OXS.Get(sym)
        END
      END ;
      Check(OXS.colon, "colon expected"); Type(tp);
      IF (tp.form = OXB.Array) & (tp.len < 0) THEN OXS.Mark("dyn array not allowed") END ;
      IF tp.size > 1 THEN offset := (offset+3) DIV 4 * 4 END ;
      offset := offset + n * tp.size; off := offset; obj0 := obj;
      WHILE obj0 # bot DO obj0.type := tp; obj0.lev := 0; off := off - tp.size; obj0.val := off; obj0 := obj0.next END ;
      bot := obj;
      IF sym = OXS.semicolon THEN OXS.Get(sym) ELSIF sym # OXS.end THEN OXS.Mark(" ; or END") END
    END ;
    typ.form := OXB.Record; typ.dsc := bot; typ.size := (offset + 3) DIV 4 * 4; type := typ
  END RecordType;

  (* begin-procedure-description
---
**FPSection** matches the parameters to a function or marks an error.
  end-procedure-description *)
  PROCEDURE FPSection(VAR adr: LONGINT; VAR nofpar: INTEGER);
    VAR obj, first: OXB.Object; tp: OXB.Type;
      parsize: LONGINT; cl: INTEGER; rdo: BOOLEAN;
  BEGIN
    IF sym = OXS.var THEN OXS.Get(sym); cl := OXB.Par ELSE cl := OXB.Var END ;
    IdentList(cl, first); FormalType(tp, 0); rdo := FALSE;
    IF (cl = OXB.Var) & (tp.form >= OXB.Array) THEN cl := OXB.Par; rdo := TRUE END ;
    IF (tp.form = OXB.Array) & (tp.len < 0) OR (tp.form = OXB.Record) THEN
      parsize := 2*ccWordsize  (*open array or record, needs second word for length or type tag*)
    ELSE parsize := ccWordsize
    END ;
    obj := first;
    WHILE obj # NIL DO
      INC(nofpar); obj.class := cl; obj.type := tp; obj.rdo := rdo; obj.lev := level; obj.val := adr;
      adr := adr + parsize; obj := obj.next
    END ;
    IF adr >= 52 THEN OXS.Mark("too many parameters") END
  END FPSection;

  (* begin-procedure-description
---
**ProcedureType** matches a Procedure Type definition or marks an error.
  end-procedure-description *)
  PROCEDURE ProcedureType(ptype: OXB.Type; VAR parblksize: LONGINT);
    VAR obj: OXB.Object; size: LONGINT; nofpar: INTEGER;
  BEGIN ptype.base := OXB.noType; size := parblksize; nofpar := 0; ptype.dsc := NIL;
    IF sym = OXS.lparen THEN
      OXS.Get(sym);
      IF sym = OXS.rparen THEN OXS.Get(sym)
      ELSE FPSection(size, nofpar);
        WHILE sym = OXS.semicolon DO OXS.Get(sym); FPSection(size, nofpar) END ;
        Check(OXS.rparen, "no )")
      END ;
      IF sym = OXS.colon THEN  (*function*)
        OXS.Get(sym);
        IF sym = OXS.ident THEN
          qualident(obj); ptype.base := obj.type;
          IF ~((obj.class = OXB.Typ) & (obj.type.form IN {OXB.Byte .. OXB.Pointer, OXB.Proc})) THEN
            OXS.Mark("illegal function type")
          END
        ELSE OXS.Mark("type identifier expected")
        END
      END
    END ;
    ptype.nofpar := nofpar; parblksize := size
  END ProcedureType;

  (* begin-procedure-description
---
**FormalType0** matches the definition of a type or marks an error.
  end-procedure-description *)
  PROCEDURE FormalType0(VAR typ: OXB.Type; dim: INTEGER);
    VAR obj: OXB.Object; dmy: LONGINT;
  BEGIN
    IF sym = OXS.ident THEN
      qualident(obj);
      IF obj.class = OXB.Typ THEN typ := obj.type ELSE OXS.Mark("not a type"); typ := OXB.intType END
    ELSIF sym = OXS.array THEN
      OXS.Get(sym); Check(OXS.of, "OF ?");
      IF dim >= 1 THEN OXS.Mark("multi-dimensional open arrays not implemented") END ;
      NEW(typ); typ.form := OXB.Array; typ.len := -1; typ.size := 2*ccWordsize; 
      FormalType(typ.base, dim+1)
    ELSIF sym = OXS.procedure THEN
      OXS.Get(sym); OXB.OpenScope;
      NEW(typ); typ.form := OXB.Proc; typ.size := ccWordsize; dmy := 0; ProcedureType(typ, dmy);
      typ.dsc := OXB.topScope.next; OXB.CloseScope
    ELSE OXS.Mark("identifier expected"); typ := OXB.noType
    END
  END FormalType0;

  (* begin-procedure-description
---
**CheckRecLevel** ensures that the ptr base is global.
  end-procedure-description *)
  PROCEDURE CheckRecLevel(lev: INTEGER);
  BEGIN
    IF lev # 0 THEN OXS.Mark("ptr base must be global") END
  END CheckRecLevel;

  (* begin-procedure-description
---
**Type0** matches a type definition or marks an error.
  end-procedure-description *)
  PROCEDURE Type0(VAR type: OXB.Type);
    VAR dmy: LONGINT; obj: OXB.Object; ptbase: PtrBase;
  BEGIN type := OXB.intType; (*sync*)
    IF (sym # OXS.ident) & (sym < OXS.array) THEN OXS.Mark("not a type");
      REPEAT OXS.Get(sym) UNTIL (sym = OXS.ident) OR (sym >= OXS.array)
    END ;
    IF sym = OXS.ident THEN
      qualident(obj);
      IF obj.class = OXB.Typ THEN
        IF (obj.type # NIL) & (obj.type.form # OXB.NoTyp) THEN type := obj.type END
      ELSE OXS.Mark("not a type or undefined")
      END
    ELSIF sym = OXS.array THEN OXS.Get(sym); ArrayType(type)
    ELSIF sym = OXS.record THEN
      OXS.Get(sym); RecordType(type); Check(OXS.end, "no END")
    ELSIF sym = OXS.pointer THEN
      OXS.Get(sym); Check(OXS.to, "no TO");
      NEW(type);  type.form := OXB.Pointer; type.size := ccWordsize; type.base := OXB.intType;
      IF sym = OXS.ident THEN
        obj := OXB.thisObj();
        IF obj # NIL THEN
          IF (obj.class = OXB.Typ) & (obj.type.form IN {OXB.Record, OXB.NoTyp}) THEN
            CheckRecLevel(obj.lev); type.base := obj.type
          ELSIF obj.class = OXB.Mod THEN OXS.Mark("external base type not implemented")
          ELSE OXS.Mark("no valid base type")
          END
        ELSE CheckRecLevel(level); (*enter into list of forward references to be fixed in Declarations*)
          NEW(ptbase); OXS.CopyId(ptbase.name); ptbase.type := type; ptbase.next := pbsList; pbsList := ptbase
        END ;
        OXS.Get(sym)
      ELSE Type(type.base);
        IF (type.base.form # OXB.Record) OR (type.base.typobj = NIL) THEN OXS.Mark("must point to named record") END ;
        CheckRecLevel(level)
      END
    ELSIF sym = OXS.procedure THEN
      OXS.Get(sym); OXB.OpenScope;
      NEW(type); type.form := OXB.Proc; type.size := ccWordsize; dmy := 0;
      ProcedureType(type, dmy); type.dsc := OXB.topScope.next; OXB.CloseScope
    ELSE OXS.Mark("illegal type")
    END
  END Type0;

  (* begin-procedure-description
---
**Declarations** dispatches the definition of constants, types, and variables.
  end-procedure-description *)
  PROCEDURE Declarations(VAR varsize: LONGINT);
    VAR obj, first: OXB.Object;
      x: OXG.Item; tp: OXB.Type; ptbase: PtrBase;
      expo: BOOLEAN; id: OXS.Ident;
  BEGIN (*sync*) pbsList := NIL;
    IF (sym < OXS.const) & (sym # OXS.end) & (sym # OXS.return) THEN OXS.Mark("declaration?");
      REPEAT OXS.Get(sym) UNTIL (sym >= OXS.const) OR (sym = OXS.end) OR (sym = OXS.return)
    END ;
    IF sym = OXS.const THEN
      OXS.Get(sym);
      WHILE sym = OXS.ident DO
        OXS.CopyId(id); OXS.Get(sym); CheckExport(expo);
        IF sym = OXS.eql THEN OXS.Get(sym) ELSE OXS.Mark("= ?") END;
        expression(x);
        IF (x.type.form = OXB.String) & (x.b = 2) THEN OXG.StrToChar(x) END ;
        OXB.NewObj(obj, id, OXB.Const); obj.expo := expo;
        IF x.mode = OXB.Const THEN obj.val := x.a; obj.lev := x.b; obj.type := x.type
        ELSE OXS.Mark("expression not constant"); obj.type := OXB.intType
        END;
        Check(OXS.semicolon, "; missing")
      END
    END ;
    IF sym = OXS.type THEN
      OXS.Get(sym);
      WHILE sym = OXS.ident DO
        OXS.CopyId(id); OXS.Get(sym); CheckExport(expo);
        IF sym = OXS.eql THEN OXS.Get(sym) ELSE OXS.Mark("=?") END ;
        Type(tp);
        OXB.NewObj(obj, id, OXB.Typ); obj.type := tp; obj.expo := expo; obj.lev := level;
        IF tp.typobj = NIL THEN tp.typobj := obj END ;
        IF expo & (obj.type.form = OXB.Record) THEN obj.exno := exno; INC(exno) ELSE obj.exno := 0 END ;
        IF tp.form = OXB.Record THEN
          ptbase := pbsList;  (*check whether this is base of a pointer type; search and fixup*)
          WHILE ptbase # NIL DO
            IF obj.name = ptbase.name THEN ptbase.type.base := obj.type END ;
            ptbase := ptbase.next
          END ;
          IF level = 0 THEN OXG.BuildTD(tp, dc) END    (*type descriptor; len used as its address*)
        END ;
        Check(OXS.semicolon, "; missing")
      END
    END ;
    IF sym = OXS.var THEN
      OXS.Get(sym);
      WHILE sym = OXS.ident DO
        IdentList(OXB.Var, first); Type(tp);
        obj := first;
        WHILE obj # NIL DO
          obj.type := tp; obj.lev := level;
          IF tp.size > 1 THEN varsize := (varsize + 3) DIV 4 * 4 (*align*) END ;
          obj.val := varsize; varsize := varsize + obj.type.size;
          IF obj.expo THEN obj.exno := exno; INC(exno) END ;
          obj := obj.next
        END ;
        Check(OXS.semicolon, "; missing")
      END
    END ;
    varsize := (varsize + ccStackalign - 1) DIV ccStackalign * ccStackalign;
(*    varsize := (varsize + 3) DIV 4 * 4; *)
    ptbase := pbsList;
    WHILE ptbase # NIL DO
      IF ptbase.type.base.form = OXB.Int THEN OXS.Mark("undefined pointer base of") END ;
      ptbase := ptbase.next
    END ;
    IF (sym >= OXS.const) & (sym <= OXS.var) THEN OXS.Mark("declaration in bad order") END
  END Declarations;

  (* begin-procedure-description
---
**ProcedureDecl** matches the definition of a procedure or marks an error.
  end-procedure-description *)
  PROCEDURE ProcedureDecl;
    VAR proc: OXB.Object;
      type: OXB.Type;
      procid: OXS.Ident;
      x: OXG.Item;
      locblksize, parblksize, L: LONGINT;
      int: BOOLEAN;
  BEGIN (* ProcedureDecl *) int := FALSE; OXS.Get(sym); 
    IF sym = OXS.times THEN OXS.Get(sym); int := TRUE END ;
    IF sym = OXS.ident THEN
      OXS.CopyId(procid); OXS.Get(sym);
      OXB.NewObj(proc, OXS.id, OXB.Const);
      IF int THEN parblksize := 3 * ccWordsize ELSE parblksize := ccWordsize END ;
      NEW(type); type.form := OXB.Proc; type.size := ccWordsize;
      proc.type := type; proc.val := -1; proc.lev := level; 
      CheckExport(proc.expo);
      IF proc.expo THEN proc.exno := exno; INC(exno) END ;
      OXB.OpenScope; INC(level); type.base := OXB.noType;
      ProcedureType(type, parblksize);  (*formal parameter list*)
      Check(OXS.semicolon, "no ;"); locblksize := parblksize; 
      Declarations(locblksize);
      proc.val := OXG.Here() * 4; proc.type.dsc := OXB.topScope.next;
      IF sym = OXS.procedure THEN
        L := 0; OXG.FJump(L);
        REPEAT ProcedureDecl; Check(OXS.semicolon, "no ;") UNTIL sym # OXS.procedure;
        OXG.FixOne(L); proc.val := OXG.Here() * 4; proc.type.dsc := OXB.topScope.next
      END ;
      OXG.Enter(parblksize, locblksize, ccWordsize, int);
      IF sym = OXS.begin THEN OXS.Get(sym); StatSequence END ;
      IF sym = OXS.return THEN
        OXS.Get(sym); expression(x);
        IF type.base = OXB.noType THEN OXS.Mark("this is not a function")
        ELSIF ~CompTypes(type.base, x.type, FALSE) THEN OXS.Mark("wrong result type")
        END
      ELSIF type.base.form # OXB.NoTyp THEN
        OXS.Mark("function without result"); type.base := OXB.noType
      END ;
      OXG.Return(type.base.form, x, locblksize, int);
      OXB.CloseScope; DEC(level); Check(OXS.end, "no END");
      IF sym = OXS.ident THEN
        IF OXS.id # procid THEN OXS.Mark("no match") END ;
        OXS.Get(sym)
      ELSE OXS.Mark("no proc id")
      END
    ELSE OXS.Mark("proc id expected")
    END
  END ProcedureDecl;

  (* begin-procedure-description
---
**Import** consumes the names of modules imported by this module and ensures their compatibility or marks an error.
  end-procedure-description *)
  PROCEDURE Import;
    VAR impid, impid1: OXS.Ident;
  BEGIN
    IF sym = OXS.ident THEN
      OXS.CopyId(impid); OXS.Get(sym);
      IF sym = OXS.becomes THEN
        OXS.Get(sym);
        IF sym = OXS.ident THEN OXS.CopyId(impid1); OXS.Get(sym)
        ELSE OXS.Mark("id expected"); impid1 := impid
        END
      ELSE impid1 := impid
      END ;
      OXB.Import(impid, impid1, ccARCH)
    ELSE OXS.Mark("id expected")
    END
  END Import;

  (* begin-procedure-description
---
**Module** begins the recursive descent parsing of the source text and emits an object code file on completion or marks an error.
  end-procedure-description *)
  PROCEDURE Module;
    VAR key: LONGINT;
  BEGIN Texts.WriteString(W, "  compiling "); OXS.Get(sym);
    IF OXS.ccARCH = OXS.RISC5 THEN Texts.WriteString(W, " for RISC5 ") END; 
    IF OXS.ccARCH = OXS.X8664 THEN Texts.WriteString(W, " for X8664 ") END; 
    IF OXS.ccARCH = OXS.ARM64 THEN Texts.WriteString(W, " for ARM64 ") END; 
    IF OXS.ccARCH = OXS.ARM32 THEN Texts.WriteString(W, " for ARM32 ") END; 
    IF OXS.ccARCH = OXS.RISCV64 THEN Texts.WriteString(W, " for RISCV64 ") END; 
    IF OXS.ccARCH = OXS.RISCV32 THEN Texts.WriteString(W, " for RISCV32 ") END; 
    IF sym = OXS.package THEN
      OXS.Get(sym);
      dc := 0; version := 1;
      OXB.Clear; OXB.OpenScope;
      IF sym = OXS.ident THEN
        OXS.CopyId(modid); OXS.Get(sym);
        Texts.WriteString(W, modid); Texts.Append(Oberon.Log, W.buf)
      ELSE OXS.Mark("identifier expected")
      END ;
      Check(OXS.semicolon, "no ;");
      level := 0; exno := 1; key := 0;
      IF sym = OXS.import THEN
        OXS.Get(sym); Import;
        WHILE sym = OXS.comma DO OXS.Get(sym); Import END ;
        Check(OXS.semicolon, "; missing")
      END ;
      OXG.Open(version); Declarations(dc); OXG.SetDataSize((dc + 3) DIV 4 * 4);
      WHILE sym = OXS.procedure DO ProcedureDecl; Check(OXS.semicolon, "no ;") END ;
      OXG.Header;
      IF sym = OXS.begin THEN OXS.Get(sym); StatSequence END ;
      Check(OXS.end, "no END");
      IF sym = OXS.ident THEN
        IF OXS.id # modid THEN OXS.Mark("no match") END ;
        OXS.Get(sym)
      ELSE OXS.Mark("identifier missing")
      END ;
      IF sym # OXS.period THEN OXS.Mark("period missing") END ;
      IF (OXS.errcnt = 0) & (version # 0) THEN
        OXB.Export(modid, newSF, key, ccARCH);
        IF newSF THEN Texts.WriteString(W, " new symbol file") END
      END ;
      IF OXS.errcnt = 0 THEN
        OXG.Close(modid, key, exno, ccARCH);
        Texts.WriteInt(W, OXG.pc, 6); Texts.WriteInt(W, dc, 6); Texts.WriteHex(W, key)
      ELSE Texts.WriteLn(W); Texts.WriteString(W, "compilation FAILED")
      END ;
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
      OXB.CloseScope; pbsList := NIL
    ELSE OXS.Mark("must start with MODULE")
    END
  END Module;

(* begin-section-description
## ---------- Command Invocation
  end-section-description *)

  (* begin-procedure-description
---
**Option** checks if a new symbol file may be generated and which architecture to compile for.
  end-procedure-description *)
  PROCEDURE Option(VAR S: Texts.Scanner);
    VAR i: INTEGER;
  BEGIN newSF := FALSE;
    ccARCH := OXS.RISC5;
    ccWordsize := 4;
    ccStackalign := 4;
    WHILE S.nextCh = "/" DO
      Texts.Scan(S); Texts.Scan(S); 
      IF (S.class = Texts.Name) THEN 
          IF S.s[0] = "s" THEN newSF := TRUE END;
          IF S.s[0] = "r" THEN ccARCH := OXS.RISC5 END;
          IF S.s[0] = "I" THEN ccARCH := OXS.X8664; ccWordsize := 8; ccStackalign := 8; END;
          IF S.s[0] = "A" THEN ccARCH := OXS.ARM64; ccWordsize := 8; ccStackalign := 16; END;
          IF S.s[0] = "a" THEN ccARCH := OXS.ARM32 END;
          IF S.s[0] = "C" THEN ccARCH := OXS.CORTEX4 END;
          IF S.s[0] = "c" THEN ccARCH := OXS.CORTEX0 END;
          IF S.s[0] = "V" THEN ccARCH := OXS.RISCV64; ccWordsize := 8; ccStackalign := 8; END;
          IF S.s[0] = "v" THEN ccARCH := OXS.RISCV32 END;  
      END
    END
  END Option;

  (* begin-procedure-description
---
**Prep** locates the source code to a module, initializes the scanner, and begins parsing at 'Module'.
  end-procedure-description *)
  PROCEDURE Prep;
  BEGIN
          OXB.Init(ccWordsize);

          (*initialize universe with data types and in-line procedures;
            INTEGER and LONGINT are register size in 32 and 64 bit systems.
            REAL and LONGREAL resgister size in 32 and 64 bit systems.
            LED, ADC, SBC; LDPSR, LDREG, REG, COND are not in language definition*)

          OXB.Enter("UML",    OXB.SFunc, OXB.intType, 132);  (*functions*)
          OXB.Enter("SBC",    OXB.SFunc, OXB.intType, 122);
          OXB.Enter("ADC",    OXB.SFunc, OXB.intType, 112);
          OXB.Enter("ROR",    OXB.SFunc, OXB.intType, 92);
          OXB.Enter("ASR",    OXB.SFunc, OXB.intType, 82);
          OXB.Enter("LSL",    OXB.SFunc, OXB.intType, 72);
          OXB.Enter("LEN",    OXB.SFunc, OXB.intType, 61);
          OXB.Enter("CHR",    OXB.SFunc, OXB.charType, 51);
          OXB.Enter("ORD",    OXB.SFunc, OXB.intType, 41);
          OXB.Enter("FLT",    OXB.SFunc, OXB.realType, 31);
          OXB.Enter("FLOOR",  OXB.SFunc, OXB.intType, 21);
          OXB.Enter("ODD",    OXB.SFunc, OXB.boolType, 11);
          OXB.Enter("ABS",    OXB.SFunc, OXB.intType, 1);
          OXB.Enter("LED",    OXB.SProc, OXB.noType, 81);  (*procedures*)
          OXB.Enter("UNPK",   OXB.SProc, OXB.noType, 72);
          OXB.Enter("PACK",   OXB.SProc, OXB.noType, 62);
          OXB.Enter("NEW",    OXB.SProc, OXB.noType, 51);
          OXB.Enter("ASSERT", OXB.SProc, OXB.noType, 41);
          OXB.Enter("EXCL",   OXB.SProc, OXB.noType, 32);
          OXB.Enter("INCL",   OXB.SProc, OXB.noType, 22);
          OXB.Enter("DEC",    OXB.SProc, OXB.noType, 11);
          OXB.Enter("INC",    OXB.SProc, OXB.noType, 1);
          OXB.Enter("SET",    OXB.Typ,   OXB.setType, 0);   (*types*)
          OXB.Enter("BOOLEAN",OXB.Typ,   OXB.boolType, 0);
          OXB.Enter("BYTE",   OXB.Typ,   OXB.byteType, 0);
          OXB.Enter("CHAR",   OXB.Typ,   OXB.charType, 0);
          IF ccWordsize = 4 THEN OXB.Enter("LONGREAL", OXB.Typ, OXB.realType, 0) END;
          IF ccWordsize = 8 THEN OXB.Enter("LONGREAL", OXB.Typ, OXB.doubleType, 0) END;
                OXB.Enter("REAL",   OXB.Typ,   OXB.realType, 0);
          IF ccWordsize = 4 THEN OXB.Enter("LONGINT",  OXB.Typ, OXB.intType, 0) END;
          IF ccWordsize = 8 THEN OXB.Enter("LONGINT",  OXB.Typ, OXB.longType, 0) END;
                OXB.Enter("INTEGER",OXB.Typ,   OXB.intType, 0);
          IF ccWordsize = 8 THEN OXB.Enter("SHORTINT", OXB.Typ, OXB.shortType, 0) END;

          OXB.PrepSYSTEM;

          OXB.Enter("H",     OXB.SFunc, OXB.intType, 201);     (*functions*)
          OXB.Enter("COND",  OXB.SFunc, OXB.boolType, 191);
          OXB.Enter("SIZE",  OXB.SFunc, OXB.intType, 181);
          OXB.Enter("ADR",   OXB.SFunc, OXB.intType, 171);
          OXB.Enter("VAL",   OXB.SFunc, OXB.intType, 162);
          OXB.Enter("REG",   OXB.SFunc, OXB.intType, 151);
          OXB.Enter("BIT",   OXB.SFunc, OXB.boolType, 142);
          OXB.Enter("REGREG",OXB.SProc, OXB.noType, 212);  (*procedures*)
          OXB.Enter("LDREG", OXB.SProc, OXB.noType, 142);
          OXB.Enter("LDPSR", OXB.SProc, OXB.noType, 131);
          OXB.Enter("COPY",  OXB.SProc, OXB.noType, 123);
          OXB.Enter("PUT",   OXB.SProc, OXB.noType, 112);
          OXB.Enter("GET",   OXB.SProc, OXB.noType, 102);
  END Prep;



  (* begin-procedure-description
---
**Compile** locates the source code to a module, initializes the scanner, and begins parsing at 'Module'.
  end-procedure-description *)
  PROCEDURE Compile*;
    VAR beg, end, time: LONGINT;
      T: Texts.Text;
      S: Texts.Scanner;
  BEGIN 
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Char THEN
      IF S.codepoint = ORD("@") THEN
        Option(S); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN 
          Prep;
          NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
          expression := expression0; Type := Type0; FormalType := FormalType0;
          OXS.Init(T, beg, ccARCH, ccWordsize, ccStackalign); 
          Module 
        END
      ELSIF S.codepoint = ORD("^") THEN
        Option(S); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN
          Texts.OpenScanner(S, T, beg); Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, S.s); NEW(T); Texts.Open(T, S.s);
            IF T.len > 0 THEN 
              Prep;
              NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
              expression := expression0; Type := Type0; FormalType := FormalType0;
              OXS.Init(T, 0, ccARCH, ccWordsize, ccStackalign); 
              Module
            END
          END
        END
      END
    ELSE 
      WHILE S.class = Texts.Name DO
        NEW(T); Texts.Open(T, S.s);
        IF T.len > 0 THEN 
          Option(S); 
          Prep;
          NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
          expression := expression0; Type := Type0; FormalType := FormalType0;
          OXS.Init(T, 0, ccARCH, ccWordsize, ccStackalign); 
          Module
        ELSE Texts.WriteString(W, S.s); Texts.WriteString(W, " not found");
          Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
        END ;
        IF (T.len # 0) & (OXS.errcnt = 0) THEN Texts.Scan(S) ELSE S.class := 0 END
      END
    END ;
    Oberon.Collect(0)
  END Compile;

  (* begin-procedure-description
---
**The initialzation code for this module** opens a writer to print marked errors and initializes the Go parser state.
  end-procedure-description *)
BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "Integrated C Compiler  8.16.2021");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);

  OXS.EnterKW(OXS.if, "if",2);
  OXS.EnterKW(OXS.for, "for",3);
  OXS.EnterKW(OXS.int, "int",3);
  OXS.EnterKW(OXS.var, "var",3);
  OXS.EnterKW(OXS.else, "else",4);
  OXS.EnterKW(OXS.func, "func",4);
  OXS.EnterKW(OXS.void, "void",4);
  OXS.EnterKW(OXS.const, "const",5);
  OXS.EnterKW(OXS.notasymbol, "",6);
  OXS.EnterKW(OXS.return, "return",6);
  OXS.EnterKW(OXS.string, "string",6);
  OXS.EnterKW(OXS.package, "package",7);
  OXS.EnterKW(OXS.notasymbol, "",8);
  OXS.EnterKW(OXS.notasymbol, "",9);
  OXS.SetCommentStyle(OXS.cstyle);
  OXS.SetSigCR(FALSE);
  OXS.SetSemiCR(FALSE);
  OXS.SetRunes(FALSE);


(*  NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
    expression := expression0; Type := Type0; FormalType := FormalType0 *)
END CXP.
