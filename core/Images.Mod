MODULE Images; (*CP 2.2019*)

  IMPORT SYSTEM, Files, Fonts, Bitmaps;

  CONST BmpFileId = 04D42H;
        JpgFileId = 0D8FFH;
	PngFileId = 08950H;
        PctFileId = 0F003H;

    bmp* = 0; jpg* = 1; png* = 2; pct* = 3; (*filetypes*)
    replace* = 0; insert* = 1; delete* = 2; unmark* = 3;  (*op-codes*)

  TYPE 
    Method* = POINTER TO MethodDesc;
    Layer* = POINTER TO LayerDesc;
    LayerDesc* = RECORD
      x*, y*, w*, h*, d*, p*: INTEGER;
      sx*, sy*: REAL;
      sw*, sh*: INTEGER;
      selected*, marked*: BOOLEAN;
      do*: Method;
      next: Layer
    END;

    Image* = POINTER TO ImageDesc;
    Notifier* = PROCEDURE (I: Image; op: INTEGER; beg, end: LONGINT);
    ImageDesc* = RECORD
      len*: LONGINT;
      changed*: BOOLEAN;
      flattened*: BOOLEAN;
      sel*, first: Layer;
      notify*: Notifier
    END;

    Msg* = RECORD END ;
    WidMsg* = RECORD (Msg) w*: INTEGER END ;
    ColorMsg* = RECORD (Msg) col*: INTEGER END ;
    FontMsg* = RECORD (Msg) fnt*: Fonts.Font END ;
    

    bmpHeaderEntry = RECORD
        a: INTEGER;
        b: INTEGER;
        c: INTEGER;
        d: INTEGER
    END;

    jpgHeaderEntry = RECORD
        a: INTEGER;
        b: INTEGER;
        c: INTEGER;
        d: INTEGER
    END;

    pngHeaderEntry = RECORD
        a: INTEGER;
        b: INTEGER;
        c: INTEGER;
        d: INTEGER
    END;

    MethodDesc* = RECORD
(*        module*, allocator*: Name;
        new*: Modules.Command;             *)
        copy*: PROCEDURE (from, to: Layer);
        draw*, change*: PROCEDURE (L: Layer; VAR msg: Msg);
        selectable*: PROCEDURE (L: Layer; x, y: INTEGER): BOOLEAN;
        read*: PROCEDURE (L: Layer; VAR R: Files.Rider); (*; VAR C: Context); *)
        write*: PROCEDURE (L: Layer; cno: INTEGER; VAR R: Files.Rider); (*; VAR C: Context);*)
        print*: PROCEDURE (L: Layer; x, y: INTEGER)
      END ;

    
VAR 
  
  res*: INTEGER;
  width: INTEGER;
  new: Layer;
  LineMethod*, CapMethod*, MacMethod* : Method;

  PROCEDURE New*(l: Layer);
  BEGIN new := l
  END New;

  PROCEDURE Add*(I: Image; L: Layer);
  BEGIN L.marked := FALSE; L.selected := TRUE; L.next := I.first;
    I.first := L; I.sel := L; I.changed := TRUE
  END Add;

  PROCEDURE ThisLayer*(I: Image; x, y: INTEGER): Layer;
    VAR L: Layer;
  BEGIN L := I.first;
    WHILE (L # NIL) & ~L.do.selectable(L, x ,y) DO L := L.next END ;
    RETURN L
  END ThisLayer;

  PROCEDURE SelectLayer*(I: Image; L: Layer);
  BEGIN
    IF L # NIL THEN L.selected := TRUE; I.sel := L END
  END SelectLayer;

  PROCEDURE SelectArea*(I: Image; x0, y0, x1, y1: INTEGER);
    VAR L: Layer; t: INTEGER;
  BEGIN L := I.first;
    IF x1 < x0 THEN t := x0; x0 := x1; x1 := t END ;
    IF y1 < y0 THEN t := y0; y0 := y1; y1 := t END ;
    WHILE L # NIL DO
      IF (x0 <= L.x) & (L.x + L.w <= x1) & (y0 <= L.y) & (L.y + L.h <= y1) THEN
        L.selected := TRUE; I.sel := L
      END ;
      L := L.next
    END ;
    IF I.sel # NIL THEN  END
  END SelectArea;

  PROCEDURE Draw*(I: Image; VAR M: Msg);
    VAR L: Layer;
  BEGIN L := I.first;
    WHILE L # NIL DO L.do.draw(L, M); L := L.next END
  END Draw;

(*
  PROCEDURE List*(I: Image);
    VAR L: Layer; tag: INTEGER;
  BEGIN L := I.first;
    WHILE L # NIL DO
      Texts.Write(XW, 9X); Texts.WriteHex(XW, ORD(L)); Texts.Write(XW, 9X);
      Texts.WriteInt(XW, L.x, 5); Texts.WriteInt(XW, L.y, 5); Texts.WriteInt(XW, L.w, 5); Texts.WriteInt(XW, L.h, 5);
      Texts.Write(XW, "/"); SYSTEM.GET(ORD(L)-8, tag); Texts.WriteHex(XW, tag);
      SYSTEM.GET(ORD(L)-4, tag); Texts.WriteHex(XW, tag); Texts.WriteLn(XW); L := L.next
    END ;
    Texts.Append(Oberon.Log, XW.buf)
  END List;
*)

  (*----------------procedures operating on selection -------------------*)

  PROCEDURE Deselect*(I: Image);
    VAR L: Layer;
  BEGIN L := I.first; I.sel := NIL; 
    WHILE L # NIL DO L.selected := FALSE; L := L.next END
  END Deselect;

  PROCEDURE DrawSel*(I: Image; VAR M: Msg);
    VAR L: Layer;
  BEGIN L := I.first;
    WHILE L # NIL DO
      IF L.selected THEN L.do.draw(L, M) END ;
      L := L.next
    END
  END DrawSel;

  PROCEDURE Change*(I: Image; VAR M: Msg);
    VAR L: Layer;
  BEGIN L := I.first; I.changed := TRUE;
    WHILE L # NIL DO
      IF L.selected THEN L.do.change(L, M) END ;
      L := L.next
    END
  END Change;



  PROCEDURE WriteFile*(I: Image; name: ARRAY OF CHAR);
    VAR F: Files.File; W: Files.Rider; 
  BEGIN F := Files.New(name); Files.Set(W, F, 0); 
  (*  Files.Write(W, GraphFileId); InitContext(C); StoreElems(W, C, G.first);  *)
    Files.Register(F)
  END WriteFile;


  PROCEDURE SetWidth*(w: INTEGER);
  BEGIN width := w
  END SetWidth;


  PROCEDURE LoadBmpLayer(VAR R: Files.Rider; VAR flyr: Layer);
    VAR lyr: Layer; b: BYTE;
  BEGIN lyr := NIL; Files.ReadByte(R, b);
    flyr := lyr
  END LoadBmpLayer;

  PROCEDURE LoadJpgLayer(VAR R: Files.Rider; VAR flyr: Layer);
    VAR lyr: Layer; b: BYTE;
  BEGIN lyr := NIL; Files.ReadByte(R, b);
    flyr := lyr
  END LoadJpgLayer;

  PROCEDURE LoadPngLayer(VAR R: Files.Rider; VAR flyr: Layer);
    VAR lyr: Layer; b: BYTE;
  BEGIN lyr := NIL; Files.ReadByte(R, b);
    flyr := lyr
  END LoadPngLayer;

  PROCEDURE LoadPctLayer(VAR R: Files.Rider; VAR flyr: Layer);
    VAR lyr: Layer; b: BYTE;
  BEGIN lyr := NIL; Files.ReadByte(R, b);
    flyr := lyr
  END LoadPctLayer;

  PROCEDURE Open*(I: Image; name: ARRAY OF CHAR);
    VAR tag: CHAR;
          b: BYTE;
          i: INTEGER;
      F: Files.File; R: Files.Rider; 
  BEGIN I.first := NIL; I.sel := NIL; I.changed := FALSE; F := Files.Old(name);
    IF F # NIL THEN
      Files.Set(R, F, 0);
      Files.ReadByte(R, b); i:=b;
      Files.ReadByte(R, b); i:=i+(b*100H);
      IF i = BmpFileId THEN
        LoadBmpLayer(R, I.first); res := 0
      ELSIF i = JpgFileId THEN
        LoadJpgLayer(R, I.first); res := 0
      ELSIF i = PngFileId THEN
        LoadPngLayer(R, I.first); res := 0
      ELSE (*image file not understood*)
        res := 1
      END
    ELSE res := 2
    END
  END Open;



  PROCEDURE Delete*(I: Image);
    VAR L, pred: Layer;
  BEGIN I.sel := NIL; I.changed := TRUE; L := I.first;
    WHILE (L # NIL) & L.selected DO L := L.next END ;
    I.first := L;
    IF L # NIL THEN
      pred := L; L := L.next;
      WHILE L # NIL DO
        IF L.selected THEN pred.next := L.next ELSE pred := L END ;
        L := L.next
      END
    END
  END Delete;






  PROCEDURE InstallDrawMethods*(drawLine, drawCaption, drawMacro: PROCEDURE (L: Layer; VAR msg: Msg));
  BEGIN LineMethod.draw := drawLine; CapMethod.draw := drawCaption; MacMethod.draw := drawMacro
  END InstallDrawMethods;

BEGIN 
END Images.

