MODULE Images; (*CP 2.2019*)

  IMPORT SYSTEM, Files, Bitmaps;

  CONST BmpFileId = 04D42H;
        JpgFileId = 0D8FFH;
	PngFileId = 08950H;
        PctFileId = 0F003H;

    bmp* = 0; jpg* = 1; png* = 2; pct* = 3; (*filetypes*)
    replace* = 0; insert* = 1; delete* = 2; unmark* = 3;  (*op-codes*)

  TYPE 
    Layer = POINTER TO LayerDesc;
    LayerDesc = RECORD
      x*, y*, w*, h*, d*, p*: INTEGER;
      sx*, sy*: REAL;
      sw*, sh*: INTEGER;
      selectd*, marked*: BOOLEAN;
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

    
VAR 
  
  res*: INTEGER;



  PROCEDURE WriteFile*(I: Image; name: ARRAY OF CHAR);
    VAR F: Files.File; W: Files.Rider; 
  BEGIN F := Files.New(name); Files.Set(W, F, 0); 
  (*  Files.Write(W, GraphFileId); InitContext(C); StoreElems(W, C, G.first);  *)
    Files.Register(F)
  END WriteFile;




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

BEGIN 
END Images.
