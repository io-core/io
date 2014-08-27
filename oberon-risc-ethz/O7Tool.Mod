MODULE O7Tool;  (*NW 18.2.2013*)
  IMPORT SYSTEM, Fonts, Files, Texts,  Viewers, MenuViewers, TextFrames, Oberon, O7B, Or32G, Oa32G;
  CONST r32 = 0; r64 = 1; a32 = 2; a64 = 3; i32 = 4; i64 = 5;

  VAR W: Texts.Writer;
  (*  arch: INTEGER; *)
    T: Texts.Text; V: MenuViewers.Viewer;
    Form: INTEGER;  (*result of ReadType*)
    r32mnemo0, r32mnemo1: ARRAY 16, 4 OF CHAR;  (*risc mnemonics*)
    a32mnemo0, a32cc : ARRAY 16, 4 OF CHAR;  (*arm32 mnemonics*)
  PROCEDURE OpenViewer(T: Texts.Text; title: ARRAY OF CHAR);
    VAR X, Y: INTEGER;
  BEGIN 
    Oberon.AllocateUserViewer(0, X, Y);
    V := MenuViewers.New(
        TextFrames.NewMenu(title, "System.Close  System.Copy  System.Grow  System.Clear  Edit.Search  Edit.Store"),
        TextFrames.NewText(T, 0), TextFrames.menuH, X, Y)
  END OpenViewer;
  PROCEDURE Clear*;  (*used to clear output*)
    VAR buf: Texts.Buffer;
  BEGIN NEW(buf); Texts.OpenBuf(buf); Texts.Delete(T, 0, T.len, buf)
  END Clear;
  PROCEDURE Recall*;
    VAR M: Viewers.ViewerMsg;
  BEGIN
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END Recall;

  PROCEDURE Read(VAR R: Files.Rider; VAR n: INTEGER);
    VAR b: BYTE;
  BEGIN Files.ReadByte(R, b);
    IF b < 80H THEN n := b ELSE n := b - 100H END
  END Read;

  PROCEDURE ReadType(VAR R: Files.Rider);
    VAR key, len, lev, size, off: INTEGER;
      ref, mno, class, form, readonly: INTEGER;
      name, modname: ARRAY 32 OF CHAR;
  BEGIN Read(R, ref); Texts.Write(W, " "); Texts.Write(W, "[");
    IF ref < 0 THEN Texts.Write(W, "^"); Texts.WriteInt(W, -ref, 1)
    ELSE Texts.WriteInt(W, ref, 1);
      Read(R, form); Texts.WriteString(W, "  form = "); Texts.WriteInt(W, form, 1);
      IF form = O7B.Pointer THEN ReadType(R)
      ELSIF form = O7B.Array THEN
        ReadType(R); Files.ReadNum(R, len); Files.ReadNum(R, size);
        Texts.WriteString(W, "  len = "); Texts.WriteInt(W, len, 1);
        Texts.WriteString(W, "  size = "); Texts.WriteInt(W, size, 1)
      ELSIF form = O7B.Record THEN
        ReadType(R);  (*base type*)
        Files.ReadNum(R, off); Texts.WriteString(W, "  exno = "); Texts.WriteInt(W, off, 1); 
        Files.ReadNum(R, off); Texts.WriteString(W, "  extlev = "); Texts.WriteInt(W, off, 1);
        Files.ReadNum(R, size); Texts.WriteString(W, "  size = "); Texts.WriteInt(W, size, 1);
        Texts.Write(W, " "); Texts.Write(W, "{"); Read(R, class);
        WHILE class # 0 DO (*fields*)
          Files.ReadString(R, name);
          IF name[0] # 0X THEN Texts.Write(W, " "); Texts.WriteString(W, name); ReadType(R)
          ELSE Texts.WriteString(W, " --")
          END ;
          Files.ReadNum(R, off); Texts.WriteInt(W, off, 4); Read(R, class)
        END ;
        Texts.Write(W, "}")
      ELSIF form = O7B.Proc THEN
        ReadType(R); Texts.Write(W, "("); Read(R, class);
        WHILE class # 0 DO
          Texts.WriteString(W, " class = "); Texts.WriteInt(W, class, 1); Read(R, readonly);
          IF readonly = 1 THEN Texts.Write(W, "#") END ;
          ReadType(R); Read(R, class)
        END ;
        Texts.Write(W, ")")
      END ;
      Files.ReadString(R, modname);
      IF modname[0] # 0X THEN
        Files.ReadInt(R, key); Files.ReadString(R, name);
        Texts.Write(W, " "); Texts.WriteString(W, modname); Texts.Write(W, "."); Texts.WriteString(W, name);
        Texts.WriteHex(W, key)
      END
    END ;
    Form := form; Texts.Write(W, "]")
  END ReadType;

  PROCEDURE DecSym*;  (*decode symbol file*)
    VAR class, typno, k: INTEGER;
      name: ARRAY 32 OF CHAR;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      Texts.WriteString(W, "OR-decode "); Texts.WriteString(W, S.s);
      Texts.WriteLn(W); Texts.Append(T, W.buf);
      F := Files.Old(S.s);
      IF F # NIL THEN
        Files.Set(R, F, 0); Files.ReadInt(R, k); Files.ReadInt(R, k);
        Files.ReadString(R, name); Texts.WriteString(W, name); Texts.WriteHex(W, k);
        Read(R, class); Texts.WriteInt(W, class, 3); (*sym file version*)
        IF class = O7B.versionkey THEN
          Texts.WriteLn(W); Read(R, class);
          WHILE class # 0 DO
            Texts.WriteInt(W, class, 4); Files.ReadString(R, name); Texts.Write(W, " "); Texts.WriteString(W, name);
            ReadType(R);
            IF class = O7B.Typ THEN
              Texts.Write(W, "("); Read(R, class);
              WHILE class # 0 DO  (*pointer base fixup*)
                Texts.WriteString(W, " ->"); Texts.WriteInt(W, class, 4); Read(R, class)
              END ;
              Texts.Write(W, ")")
            ELSIF (class = O7B.Const) OR (class = O7B.Var) THEN
              Files.ReadNum(R, k); Texts.WriteInt(W, k, 5);  (*Reals, Strings!*)
            END ;
            Texts.WriteLn(W); Texts.Append(T, W.buf);
            Read(R, class)
          END
        ELSE Texts.WriteString(W, " bad symfile version")
        END
      ELSE Texts.WriteString(W, " not found")
      END ;
      Texts.WriteLn(W); Texts.Append(T, W.buf)
    END
  END DecSym;
  
(* ---------------------------------------------------*)

  PROCEDURE r32WriteReg(r: LONGINT);
  BEGIN Texts.Write(W, " ");
    IF r < 10 THEN Texts.WriteString(W, " R"); Texts.WriteInt(W, r MOD 10H, 1)
    ELSIF r = 10 THEN Texts.WriteString(W, "R"); Texts.WriteInt(W, r MOD 10H, 1)
    ELSIF r = 11 THEN Texts.WriteString(W, "R"); Texts.WriteInt(W, r MOD 10H, 1)
    ELSIF r = 12 THEN Texts.WriteString(W, " MT")
    ELSIF r = 13 THEN Texts.WriteString(W, " SB")
    ELSIF r = 14 THEN Texts.WriteString(W, " SP")
    ELSE Texts.WriteString(W, "LNK")
    END
  END r32WriteReg;

  PROCEDURE r32opcode(w: LONGINT);
    VAR k, op, u, a, b, c: LONGINT;
  BEGIN
      k := w DIV 40000000H MOD 4;
      a := w DIV 1000000H MOD 10H;
      b := w DIV 100000H MOD 10H;
      op := w DIV 10000H MOD 10H;
      u := w DIV 20000000H MOD 2;
      IF k = 0 THEN
        Texts.WriteString(W, r32mnemo0[op]);
        IF u = 1 THEN Texts.Write(W, "'") END ;
        r32WriteReg(a); r32WriteReg(b); Texts.WriteString(W, "    "); r32WriteReg(w MOD 10H)
      ELSIF k = 1 THEN
        Texts.WriteString(W, r32mnemo0[op]);
        IF u = 1 THEN Texts.Write(W, "'") END ;
        r32WriteReg(a); r32WriteReg(b); w := w MOD 10000H;
        IF w >= 8000H THEN w := w - 10000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 2 THEN  (*LDR/STR*)
        IF u = 1 THEN Texts.WriteString(W, "STR") ELSE Texts.WriteString(W, "LDR") END ;
        r32WriteReg(a); r32WriteReg(b); w := w MOD 100000H;
        IF w >= 80000H THEN w := w - 100000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 3 THEN  (*Branch instr*)
        Texts.Write(W, "B");
        IF ODD(w DIV 10000000H) THEN Texts.Write(W, "L") END ;
        Texts.WriteString(W, r32mnemo1[a]);
        IF ~ODD(w DIV 10000000H) THEN Texts.Write(W, " ") END ;
        IF u = 0 THEN 
         Texts.WriteString(W, "          "); r32WriteReg(w MOD 10H) 
        ELSE
          w := w MOD 100000H;
          IF w >= 80000H THEN w := w - 100000H END ;
          Texts.WriteInt(W, w, 14)
        END
      END
  END r32opcode;

  PROCEDURE a32WriteReg(r: LONGINT);
  BEGIN Texts.Write(W, " ");
    IF r < 10 THEN Texts.WriteString(W, "R"); Texts.WriteInt(W, r MOD 10H, 1)
    ELSIF r = 10 THEN Texts.WriteString(W, "MT")
    ELSIF r = 11 THEN Texts.WriteString(W, "SB")
    ELSIF r = 12 THEN Texts.WriteString(W, "FP")
    ELSIF r = 13 THEN Texts.WriteString(W, "SP")
    ELSIF r = 14 THEN Texts.WriteString(W, "LR")
    ELSE Texts.WriteString(W, "PC")
    END
  END a32WriteReg;


  PROCEDURE a32opcode(w: LONGINT);
        CONST
  (*opcode formats*)
   DPfmt = 0; MULfmt = 1; MULLfmt = 2; SDSfmt = 3; BEfmt = 4; HDTRfmt = 5; HDTIfmt = 6;
   SDTfmt = 7; UNDfmt = 8; BDTfmt = 9; BRfmt = 10; CDTfmt = 11; CDOfmt = 12; CRTfmt = 13; SWIfmt = 14;
		VAR cc, a, b, c, d, e, f, g, i, fmt: LONGINT; regset: SET; sign : LONGINT;
	BEGIN

        fmt := Oa32G.opFormat( w );

        IF   fmt=DPfmt THEN
                    i := w DIV 200000H MOD 10H;
                   Texts.WriteString(W, a32mnemo0[i]);
                   a32WriteReg( w DIV 1000H MOD 10H);
                   IF i # 13 THEN
                     a32WriteReg( w DIV 10000H MOD 10H)
                   END;
                   IF ODD(w DIV 2000000H) THEN (* immediate *)
                     IF w DIV 100H MOD 10H # 0 THEN
                       Texts.WriteString(W, " (");
                       Texts.WriteInt(W,  w  MOD 100H ,0);
                       Texts.WriteString(W, " ror ");
                       Texts.WriteInt(W,  w  DIV 100H MOD 10H ,0);
                       Texts.WriteString(W, ")");
                     ELSE
                       Texts.WriteString(W, " ");
                       Texts.WriteInt(W,  w  MOD 100H ,0);
                     END
                  ELSE (* register *)
                     IF w DIV 100H MOD 10H # 0 THEN
                       Texts.WriteString(W, " (");
                       a32WriteReg(  w  MOD 10H );
                       Texts.WriteString(W, " shft ");
                       Texts.WriteInt(W,  w  DIV 10H MOD 100H ,0);
                       Texts.WriteString(W, ")");
                     ELSE
                       a32WriteReg(  w  MOD 10H );
                     END
                  END
        ELSIF  fmt=MULfmt  THEN
                    Texts.WriteString(W, " mul ");
        ELSIF fmt=MULLfmt  THEN
                      Texts.WriteString(W, " mull ");
        ELSIF fmt=SDSfmt    THEN
                      Texts.WriteString(W, " SDS ");
        ELSIF fmt=BEfmt    THEN
                      Texts.WriteString(W, " BE ");
        ELSIF fmt=HDTRfmt THEN
                      Texts.WriteString(W, " HDTR ");
        ELSIF fmt=HDTIfmt THEN
                      Texts.WriteString(W, " HDTI ");
        ELSIF  fmt=SDTfmt THEN
          IF ODD( w DIV 100000H ) THEN
                      Texts.WriteString(W, "LDR");
          ELSE
                      Texts.WriteString(W, "STR");
          END;
                   a32WriteReg( w DIV 1000H MOD 10H);
                   a32WriteReg( w DIV 10000H MOD 10H);
                     Texts.WriteString(W, " ");               
          IF ODD( w DIV 800000H ) THEN
                     Texts.WriteInt(W,  w  MOD 1000H ,0);
          ELSE
                     Texts.WriteInt(W,  - ( w  MOD 1000H ) ,0);
          END
        ELSIF  fmt=UNDfmt THEN
                      Texts.WriteString(W, " UND ");
        ELSIF  fmt=BDTfmt THEN
                      Texts.WriteString(W, " BDT ");
        ELSIF  fmt=BRfmt THEN
          IF ODD( w DIV 1000000H ) THEN
                     Texts.WriteString(W, "BL")
          ELSE
                     Texts.WriteString(W, "B ")
          END;
          Texts.WriteString(W, a32cc[ w DIV 10000000H  MOD 10H ]);
          Texts.WriteInt(W,  w  DIV 10H MOD 1000000H ,0);
        ELSIF  fmt=CDTfmt THEN
                     Texts.WriteString(W, " CDT ");
        ELSIF fmt=CDOfmt THEN
                     Texts.WriteString(W, " CDO ");
        ELSIF fmt=CRTfmt THEN
                     Texts.WriteString(W, " CRT ");
        ELSIF fmt=SWIfmt  THEN
                    Texts.WriteString(W, " SWI ");
        ELSE
                    Texts.WriteString(W, " UNK ");
        END

  END a32opcode;


  PROCEDURE opcode(w: LONGINT; arch: INTEGER);
  BEGIN 
    IF arch = a32 THEN
      a32opcode( w )
    ELSIF arch = r32 THEN
      r32opcode( w ) 
    ELSE
      r32opcode( w ) 
    END
  END opcode;


  PROCEDURE Sync(VAR R: Files.Rider);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); Texts.WriteString(W, "Sync "); Texts.Write(W, ch); Texts.WriteLn(W)
  END Sync;
  
  PROCEDURE Write(VAR R: Files.Rider; x: INTEGER);
  BEGIN Files.WriteByte(R, x)  (* -128 <= x < 128 *)
  END Write;

  PROCEDURE getArch( s: ARRAY OF CHAR; VAR ext: ARRAY OF CHAR; VAR arch: INTEGER);  VAR i: INTEGER;  BEGIN        arch := r32;
        i:= 0; WHILE s[i] # 0X DO INC(i) END; ext[3]:=s[i]; ext[3]:=s[i]; ext[2]:=s[i-1]; ext[1]:=s[i-2]; ext[0]:=s[i-3];
        IF ext = "r64" THEN arch := r64; Texts.WriteString(W, " (r64) ") END;
        IF ext = "a32" THEN arch := a32; Texts.WriteString(W, " (a32) ") END;
        IF ext = "a64" THEN arch := a64; Texts.WriteString(W, " (a64) ") END;
        IF ext = "i32" THEN arch := i32; Texts.WriteString(W, " (i32) ") END;
        IF ext = "i64" THEN arch := i64; Texts.WriteString(W, " (i64) ") END;
        IF arch = r32 THEN Texts.WriteString(W, " (r32) ") END;
  END getArch;

  PROCEDURE DecObj*;   (*decode object file*)
    VAR class, i, n, key, size, fix, adr, data, len, arch: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      ext: ARRAY 4 OF CHAR;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      Texts.SetFont(W, Fonts.This("Courier10.Scn.Fnt"));
      Texts.WriteString(W, "decoding "); Texts.WriteString(W, S.s); F := Files.Old(S.s);
      IF F # NIL THEN        getArch( S.s, ext, arch );
        Files.Set(R, F, 0); Files.ReadString(R, name); Texts.WriteLn(W); Texts.WriteString(W, name);
        Files.ReadInt(R, key);  Texts.WriteString(W, "  Key: "); Texts.WriteHex(W, key); 
        Read(R, class); Texts.WriteString(W, "  Class: "); Texts.WriteInt(W, class, 4); (*version*)
        Files.ReadInt(R, size); Texts.WriteString(W, "  Size: "); Texts.WriteInt(W, size, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "imports:"); Texts.WriteLn(W); Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X);  Files.ReadInt(R, key); Texts.WriteHex(W, key);  Texts.WriteString(W, "  "); 
          Texts.WriteString(W, name ); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "type descriptors"); Texts.WriteLn(W);
        Files.ReadInt(R, n); n := n DIV 4; i := 0;
        WHILE i < n DO Files.ReadInt(R, data); Texts.WriteHex(W, data); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "data"); Files.ReadInt(R, data); Texts.WriteInt(W, data, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "strings"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO Files.Read(R, ch); Texts.Write(W, ch); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "code"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, data); Texts.WriteInt(W, i, 4); Texts.Write(W, 9X); Texts.WriteHex(W, i*4);
          Texts.Write(W, 9X); Texts.WriteHex(W, data);
          Texts.Write(W, 9X); opcode(data,arch); Texts.WriteLn(W); INC(i)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "commands:"); Texts.WriteLn(W);
        Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X); Texts.WriteString(W, name);
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 5); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "entries"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 6); INC(i)
        END ;
        Texts.WriteLn(W);
      (* Sync(R); *)
        Texts.WriteString(W, "pointer refs"); Texts.WriteLn(W); Files.ReadInt(R, adr);
        WHILE adr # -1 DO Texts.WriteInt(W, adr, 6); Files.ReadInt(R, adr) END ;
        Texts.WriteLn(W);
      (* Sync(R); *)
        Files.ReadInt(R, data); Texts.WriteString(W, "fixP = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "fixD = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "fixT = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "entry = "); Texts.WriteHex(W, data); Texts.WriteLn(W);
        Files.Read(R, ch);
        IF ch # "O" THEN Texts.WriteString(W, "format eror"); Texts.WriteLn(W) END
      (* Sync(R); *)
      ELSE Texts.WriteString(W, " not found"); Texts.WriteLn(W)
      END ;
      Texts.Append(T, W.buf)
    END
  END DecObj;  PROCEDURE CmpObj*;   (*Compare object files*)
    VAR class, i, n, key, size, fix, adr, data, len, arch, n2, class2, key2, size2, fix2, adr2, data2, len2, arch2: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      name2: ARRAY 32 OF CHAR;
      ext: ARRAY 4 OF CHAR;
      ext2: ARRAY 4 OF CHAR;
      F: Files.File; R: Files.Rider;
      F2: Files.File; R2: Files.Rider;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      Texts.SetFont(W, Fonts.This("Courier10.Scn.Fnt"));
      Texts.WriteString(W, "comparing "); Texts.WriteString(W, S.s); F := Files.Old(S.s);
      IF F # NIL THEN        getArch(S.s, ext, arch);        Texts.Scan(S);        IF S.class = Texts.Name THEN
          Texts.WriteString(W, " to "); Texts.WriteString(W, S.s); F2 := Files.Old(S.s);
          IF F2 # NIL THEN            getArch(S.s, ext2, arch2);          END;        END;        Files.Set(R, F, 0); Files.ReadString(R, name);         Files.Set(R2, F2, 0); Files.ReadString(R2, name2);         Texts.WriteLn(W);         Texts.WriteString(W, name);  Files.ReadInt(R, key);  Texts.WriteString(W, "  Key: "); Texts.WriteHex(W, key); 
        Read(R, class); Texts.WriteString(W, "  Class: "); Texts.WriteInt(W, class, 4); (*version*)
        Files.ReadInt(R, size); Texts.WriteString(W, "  Size: "); Texts.WriteInt(W, size, 6);         Texts.WriteString(W, "  ::::::::::::::::::  ");         Texts.WriteString(W, name2);  Files.ReadInt(R2, key2);  Texts.WriteString(W, "  Key: "); Texts.WriteHex(W, key2); 
        Read(R2, class2); Texts.WriteString(W, "  Class: "); Texts.WriteInt(W, class2, 4); (*version*)
        Files.ReadInt(R2, size2); Texts.WriteString(W, "  Size: "); Texts.WriteInt(W, size2, 6);         Texts.WriteLn(W);
        Texts.WriteString(W, "(1) imports:"); Texts.WriteLn(W); Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X);  Files.ReadInt(R, key); Texts.WriteHex(W, key);  Texts.WriteString(W, "  "); 
          Texts.WriteString(W, name ); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;        Texts.WriteLn(W);        Texts.WriteString(W, "(2) imports:"); Texts.WriteLn(W); Files.ReadString(R2, name2);
        WHILE name2[0] # 0X DO
          Texts.Write(W, 9X);  Files.ReadInt(R2, key2); Texts.WriteHex(W, key2);  Texts.WriteString(W, "  "); 
          Texts.WriteString(W, name2 ); Texts.WriteLn(W);
          Files.ReadString(R2, name2)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "(1)type descriptors"); Texts.WriteLn(W);
        Files.ReadInt(R, n); n := n DIV 4; i := 0;
        WHILE i < n DO Files.ReadInt(R, data); Texts.WriteHex(W, data); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "(1)data"); Files.ReadInt(R, data); Texts.WriteInt(W, data, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "(2)strings"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO Files.Read(R, ch); Texts.Write(W, ch); INC(i) END ;
        Texts.WriteLn(W);        Texts.WriteString(W, "(2)type descriptors"); Texts.WriteLn(W);
        Files.ReadInt(R2, n); n := n DIV 4; i := 0;
        WHILE i < n DO Files.ReadInt(R2, data2); Texts.WriteHex(W, data2); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "(2)data"); Files.ReadInt(R2, data2); Texts.WriteInt(W, data2, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "(2)strings"); Texts.WriteLn(W);
        Files.ReadInt(R2, n); i := 0;
        WHILE i < n DO Files.Read(R2, ch); Texts.Write(W, ch); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "code"); Texts.WriteLn(W);
        Files.ReadInt(R, n); Files.ReadInt(R2, n2); i := 0;
        WHILE ((i < n) OR (i < n2))DO          IF i < n THEN
            Files.ReadInt(R, data); Texts.WriteInt(W, i, 4); Texts.Write(W, 9X); Texts.WriteHex(W, i*4);
            Texts.Write(W, 9X); Texts.WriteHex(W, data);
            Texts.Write(W, 9X); opcode(data,arch)          ELSE Texts.WriteString(W, "                                                     ") END;          IF i < n2 THEN            Files.ReadInt(R2, data2); 
            Texts.Write(W, 9X); Texts.WriteHex(W, data2);
            Texts.Write(W, 9X); opcode(data2,arch2);           END;          IF data # data2 THEN IF arch = arch2 THEN Texts.Write(W,9X);Texts.Write(W,"*") END END;          Texts.WriteLn(W);           INC(i)
        END ;      (* Sync(R); *)
        Texts.WriteString(W, "(1)commands:"); Texts.WriteLn(W);
        Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X); Texts.WriteString(W, name);
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 5); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;        Texts.WriteString(W, "(2)commands:"); Texts.WriteLn(W);
        Files.ReadString(R2, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X); Texts.WriteString(W, name);
          Files.ReadInt(R2, adr); Texts.WriteInt(W, adr, 5); Texts.WriteLn(W);
          Files.ReadString(R2, name)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "(1)entries"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 6); INC(i)
        END ;
        Texts.WriteLn(W);        Texts.WriteString(W, "(2)entries"); Texts.WriteLn(W);
        Files.ReadInt(R2, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R2, adr); Texts.WriteInt(W, adr, 6); INC(i)
        END ;
        Texts.WriteLn(W);
      (* Sync(R); *)
        Texts.WriteString(W, "(1)pointer refs"); Texts.WriteLn(W); Files.ReadInt(R, adr);
        WHILE adr # -1 DO Texts.WriteInt(W, adr, 6); Files.ReadInt(R, adr) END ;
        Texts.WriteLn(W);        Texts.WriteString(W, "(2)pointer refs"); Texts.WriteLn(W); Files.ReadInt(R2, adr);
        WHILE adr # -1 DO Texts.WriteInt(W, adr, 6); Files.ReadInt(R2, adr) END ;
        Texts.WriteLn(W);

      (* Sync(R); *)
        Files.ReadInt(R, data); Texts.WriteString(W, "fixP = "); Texts.WriteInt(W, data, 8); Texts.WriteString(W,"   ::::::::   ");
        Files.ReadInt(R2, data); Texts.WriteString(W, "fixP = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "fixD = "); Texts.WriteInt(W, data, 8); Texts.WriteString(W,"   ::::::::   ");
        Files.ReadInt(R2, data); Texts.WriteString(W, "fixD = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "fixT = "); Texts.WriteInt(W, data, 8); Texts.WriteString(W,"   ::::::::   ");
        Files.ReadInt(R2, data); Texts.WriteString(W, "fixT = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "entry = "); Texts.WriteHex(W, data); Texts.WriteString(W,"   ::::::::   ");
        Files.ReadInt(R2, data); Texts.WriteString(W, "entry = "); Texts.WriteHex(W, data); Texts.WriteLn(W);
        Files.Read(R, ch); 
        IF ch # "O" THEN Texts.WriteString(W, "(1)format eror"); Texts.WriteLn(W) END;
        Files.Read(R2, ch); 
        IF ch # "O" THEN Texts.WriteString(W, "(2)format eror"); Texts.WriteLn(W) END
      (* Sync(R); *)
      ELSE Texts.WriteString(W, " not found"); Texts.WriteLn(W)
      END ;
      Texts.Append(T, W.buf)
    END
  END CmpObj;

BEGIN Texts.OpenWriter(W); T := TextFrames.Text(""); OpenViewer(T, "Tools.Text");
  Texts.SetFont(W, Fonts.This("Courier10.Scn.Fnt"));
  Texts.WriteString(W, "O7Tool 19.8.2014");
  Texts.WriteLn(W); Texts.Append(T, W.buf);
  r32mnemo0[0] := "MOV";
  r32mnemo0[1] := "LSL";
  r32mnemo0[2] := "ASR";
  r32mnemo0[3] := "ROR";
  r32mnemo0[4] := "AND";
  r32mnemo0[5] := "ANN";
  r32mnemo0[6] := "IOR";
  r32mnemo0[7] := "XOR";
  r32mnemo0[8] := "ADD";
  r32mnemo0[9] := "SUB";
  r32mnemo0[10] := "MUL";
  r32mnemo0[11] := "DIV";
  r32mnemo0[12] := "FAD";
  r32mnemo0[13] := "FSB";
  r32mnemo0[14] := "FML";
  r32mnemo0[15] := "FDV";
  r32mnemo1[3] := "   ";
  r32mnemo1[4] := "   ";
  r32mnemo1[7] := "   ";
  r32mnemo1[11] := "   ";
  r32mnemo1[13] := "   ";
  r32mnemo1[0] := "MI ";
  r32mnemo1[8] := "PL ";
  r32mnemo1[1] := "EQ ";
  r32mnemo1[9] := "NE ";
  r32mnemo1[2] := "LS ";
  r32mnemo1[10] := "HI ";
  r32mnemo1[5] := "LT ";
  r32mnemo1[13] := "GE ";
  r32mnemo1[6] := "LE ";
  r32mnemo1[14] := "GT ";
  r32mnemo1[15] := "NO ";
  a32mnemo0[0] := "AND";
  a32mnemo0[1] := "EOR";
  a32mnemo0[2] := "SUB";
  a32mnemo0[3] := "RSB";
  a32mnemo0[4] := "ADD";
  a32mnemo0[5] := "ADC";
  a32mnemo0[6] := "SBC";
  a32mnemo0[7] := "RSC";
  a32mnemo0[8] := "TST";
  a32mnemo0[9] := "TEQ";
  a32mnemo0[10] := "CMP";
  a32mnemo0[11] := "CMN";
  a32mnemo0[12] := "ORR";
  a32mnemo0[13] := "MOV";
  a32mnemo0[14] := "BIC";
  a32mnemo0[15] := "MVN";
  a32cc[0] := "EQ ";
  a32cc[1] := "NE ";
  a32cc[2] := "CS ";
  a32cc[3] := "CC ";
  a32cc[4] := "MI ";
  a32cc[5] := "PL ";
  a32cc[6] := "VS ";
  a32cc[7] := "VC ";
  a32cc[8] := "HI ";
  a32cc[9] := "LS ";
  a32cc[10] := "GE ";
  a32cc[11] := "LT ";
  a32cc[12] := "GT ";
  a32cc[13] := "LE ";
  a32cc[14] := "AL ";
  a32cc[15] := "XX ";

END O7Tool.

