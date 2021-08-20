(* begin-package-description
The ArgParse package provides a parser for command-line options and arguments.

end-package-description *)

(* begin-module-short-description
Argument Parsing
end-module-short-description *)

(* begin-module-use-description
Module ArgParse handles:

* The ArgParse package provides a parser for command-line options and arguments.

Ideally this package will grow to encompass functionality similar to ArgParse in Python and Go.
As for now this package is quite basic.

end-module-use-description *)
MODULE ArgParse; 
  IMPORT Texts, Oberon;

  CONST 
    optextlen = 32;

  TYPE 
    Arg = POINTER TO ArgDesc;
    ArgDesc = RECORD
      next: Arg;
      text: ARRAY optextlen OF CHAR;
      opt: SET
    END;

  VAR 

  (* begin-procedure-description
---
**ArgOpt** checks for options to an argument, returns a set of those found. Provides classic Oberon style slash options.
  end-procedure-description *)
  PROCEDURE Option(VAR S: Texts.Scanner; o: ARRAY OF CHAR): SET;
    VAR i: INTEGER;
        s: SET;
  BEGIN 
    s:={};
    WHILE S.nextCh = "/" DO
      Texts.Scan(S); Texts.Scan(S);
      IF (S.class = Texts.Name) THEN
      END
    END
  RETURN s
  END Option;

  (* begin-procedure-description
---
**ArgParse** collects the arguments to a command.
  end-procedure-description *)
  PROCEDURE ArgParse*(VAR W:Texts.Writer; o: ARRAY OF CHAR; VAR e: SET);
    VAR beg, end, time: LONGINT;
      T: Texts.Text;
      S: Texts.Scanner;
  BEGIN
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Char THEN
      IF S.codepoint = ORD("@") THEN
        e:=Option(S,o); Oberon.GetSelection(T, beg, end, time);
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
        e:=Option(S,o); Oberon.GetSelection(T, beg, end, time);
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
      ELSIF S.codepoint = ORD("-") THEN
        IF S.codepoint = ORD("-") THEN  (* single dash argument *)
        ELSE                            (* double dash argument *)
        END
      END
    ELSE
      WHILE S.class = Texts.Name DO
        NEW(T); Texts.Open(T, S.s);
        IF T.len > 0 THEN
          e:=Option(S,o);
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

BEGIN 
END ArgParse.
