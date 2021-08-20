(* begin-package-description
The Test package manages:

* Unit test definitions
* Automatic running of tests
* Performance instrumentation
* Performance testing reporting
* Fuzz definition
* Fuzz testing and reporting

The Test package supports the following test categories:

1. Build Test -- Does it compile?
2. Load Test -- Does it load?
3. Function Test -- Does it produce expected outputs for specific inputs?
4. Fuzz Test -- Does it operate in an expected manner on randomly generated inputs?
4. Performance Test -- Does it perform as expected on specific inputs?

Build tests show compilation errors.

Load tests verify compatibility with installed module binaries.

Function tests include module unit tests, integration tests, and regression tests.

Fuzz tests expand the envelope of function tests.

Performance tests benchmark and profile the execution of module code.

Tests for a particular "Module.Mod" are contained in a "ModuleTests.Mod" file. Tests exercise the 
public interface of a module and may simply be not delivered or loaded in production.

end-package-description *)

(* begin-module-short-description
Unit test definition, execution, and reporting
end-module-short-description *)

(* begin-module-use-description
Module Test handles:

* Nothing yet. Bug reporting eventually.

end-module-use-description *)
MODULE Test; 
  IMPORT SYSTEM, Texts, Oberon, Performance, Fuzzing;

  CONST 

  TYPE 

  VAR 
    W: Texts.Writer;


  (* begin-procedure-description
---
**Option** checks if a new symbol file may be generated and which architecture to compile for.
  end-procedure-description *)
  PROCEDURE Option(VAR S: Texts.Scanner);
    VAR i: INTEGER;
  BEGIN 
(*
    newSF := FALSE;
*)
    WHILE S.nextCh = "/" DO
      Texts.Scan(S); Texts.Scan(S);
      IF (S.class = Texts.Name) THEN
(*
          IF S.s[0] = "s" THEN newSF := TRUE END;
*)
      END
    END
  END Option;

  (* begin-procedure-description
---
**ArgParse** locates the source code to a module, initializes the scanner, and begins parsing at 'Module'.
  end-procedure-description *)
  PROCEDURE ArgParse*;
    VAR beg, end, time: LONGINT;
      T: Texts.Text;
      S: Texts.Scanner;
  BEGIN
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Char THEN
      IF S.codepoint = ORD("@") THEN
        Option(S); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN
(*
          OXB.Init(ccWordsize);
          NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
          expression := expression0; Type := Type0; FormalType := FormalType0;
          OXS.Init(T, beg, ccARCH, ccWordsize, ccStackalign);
          Module
*)
        END
      ELSIF S.codepoint = ORD("^") THEN
        Option(S); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN
(*
          Texts.OpenScanner(S, T, beg); Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, S.s); NEW(T); Texts.Open(T, S.s);
            IF T.len > 0 THEN
              OXB.Init(ccWordsize);
              NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
              expression := expression0; Type := Type0; FormalType := FormalType0;
              OXS.Init(T, 0, ccARCH, ccWordsize, ccStackalign);
              Module
            END
          END
*)
        END
      END
    ELSE
      WHILE S.class = Texts.Name DO
        NEW(T); Texts.Open(T, S.s);
        IF T.len > 0 THEN
          Option(S);
(*
          OXB.Init(ccWordsize);
          NEW(dummy); dummy.class := OXB.Var; dummy.type := OXB.intType;
          expression := expression0; Type := Type0; FormalType := FormalType0;
          OXS.Init(T, 0, ccARCH, ccWordsize, ccStackalign);
          Module
*)
        ELSE Texts.WriteString(W, S.s); Texts.WriteString(W, " not found");
          Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
        END ;
        IF (T.len # 0) (* & (OXS.errcnt = 0) *) THEN Texts.Scan(S) ELSE S.class := 0 END
      END
    END ;
    Oberon.Collect(0)
  END ArgParse;


  (* begin-procedure-description
---
**Build** performs a build test of a module.
  end-procedure-description *)
  PROCEDURE Build*;
  BEGIN ArgParse
  END Build;

  (* begin-procedure-description
---
**Load** performs a load test of a module.
  end-procedure-description *)
  PROCEDURE Load*;
  BEGIN ArgParse 
  END Load;

  (* begin-procedure-description
---
**Quick** performs quick tests of a module's exported procedures.
  end-procedure-description *)
  PROCEDURE Quick*;
  BEGIN ArgParse 
  END Quick;

  (* begin-procedure-description
---
**Full** performs full tests of a module's exported procedures excepting perf and fuzz.
  end-procedure-description *)
  PROCEDURE Full*;
  BEGIN ArgParse 
  END Full;

  (* begin-procedure-description
---
**Perf** performs benchmark tests of a module's exported procedures.
  end-procedure-description *)
  PROCEDURE Perf*;
  BEGIN ArgParse 
  END Perf;

  (* begin-procedure-description
---
**Fuzz** performs fuzz tests of a module's exported procedures.
  end-procedure-description *)
  PROCEDURE Fuzz*;
  BEGIN ArgParse 
  END Fuzz;

  (* begin-procedure-description
---
**Examples** verifies the output module's exported procedures on example uses.
  end-procedure-description *)
  PROCEDURE Examples*;
  BEGIN ArgParse 
  END Examples;

  (* begin-procedure-description
---
**All** performs all of a module's tests.
  end-procedure-description *)
  PROCEDURE All*;
  BEGIN ArgParse 
  END All;
BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "IO Testing Framework  3.30.2021");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
END Test.
