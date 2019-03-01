MODULE ImageFrames; (*CP 2.2019*)

  IMPORT SYSTEM, Display, Viewers, Input, Fonts, Texts, Images, Oberon, MenuViewers;

  CONST (*update message ids*)
    drawlayer = 1; drawlayers = 2; drawlayerd = 3;
    drawnorm = 4; drawsel = 5; drawdel = 6;

    markW = 5;

  TYPE
    Frame* = POINTER TO FrameDesc;
    Location* = POINTER TO LocDesc;

    LocDesc* = RECORD
        x*, y*: INTEGER;
        next*: Location
      END ;

    FrameDesc* = RECORD (Display.FrameDesc)
        image*: Images.Image;
        Xg*, Yg*: INTEGER;  (*pos rel to image origin*)
        X1*, Y1*: INTEGER;  (*right and upper margins*)
        x*, y*, col*: INTEGER;  (*x = X + Xg, y = Y + Yg*)
        marked*, ticked*: BOOLEAN;
        mark*: LocDesc
      END ;

    DrawMsg* = RECORD (Images.Msg)
        f*: Frame;
        x*, y*, col*, mode*: INTEGER
      END ;

    UpdateMsg = RECORD (Display.FrameMsg)
        id: INTEGER;
        image: Images.Image;
        lyr: Images.Layer
      END ;

    ChangedMsg = RECORD (Display.FrameMsg)
        f: Frame;
        image: Images.Image;
        mode: INTEGER
      END ;

    SelQuery = RECORD (Display.FrameMsg)
        f: Frame; time: LONGINT
      END ;

    FocusQuery = RECORD (Display.FrameMsg)
        f: Frame
      END ;

    PosQuery = RECORD (Display.FrameMsg)
        f: Frame; x, y: INTEGER
      END ;

    DispMsg = RECORD (Display.FrameMsg)
        x1, y1, w: INTEGER;
        pat: INTEGER;
        image: Images.Image
      END ;

  VAR Crosshair*: Oberon.Marker;
    tack*, dotted*, dotted1*: INTEGER;  (*patterns*)
    (* newcap: Graphics.Caption; *)
    TBuf: Texts.Buffer;
    DW, DH, CL: INTEGER;
    W: Texts.Writer;

  (*Exported procedures:
    Restore, Focus, Selected, This, Draw, DrawNorm, Erase,
    DrawObj, EraseObj, Change, Defocus, Deselect, Macro, Open*)

  PROCEDURE SetChangeMark(F: Frame; col: INTEGER); (*set mark in corner of frame*)
  BEGIN
    IF F.H > 16 THEN
      IF col = 0 THEN Display.ReplConst(Display.black, F.X+F.W-12, F.Y+F.H-12, 8, 8, Display.replace)
      ELSE Display.CopyPattern(Display.white, Display.block, F.X+F.W-12, F.Y+F.H-12, Display.paint)
      END
    END
  END SetChangeMark;

  PROCEDURE Restore*(F: Frame);
    VAR x, x0, y: INTEGER; M: DrawMsg;
  BEGIN F.X1 := F.X + F.W; F.Y1 := F.Y + F.H;
    F.x := (F.X + F.Xg) DIV 16 * 16; F.y := (F.Y + F.Yg) DIV 16 * 16; F.marked := FALSE; F.mark.next := NIL;
    Oberon.RemoveMarks(F.X, F.Y, F.W, F.H); Display.ReplConst(F.col, F.X, F.Y, F.W, F.H, 0);
    IF F.ticked THEN
      x0 := (F.X + 15) DIV 16 * 16; y := (F.Y + 15) DIV 16 * 16;
      WHILE y < F.Y1 DO
        x := x0;
        WHILE x < F.X1 DO Display.Dot(Display.white, x, y, Display.replace); INC(x, 16) END ;
        INC(y, 16)
      END
    END ;
    M.f := F; M.x := F.x; M.y := F.y; M.col := 0; M.mode := 0; Graphics.Draw(F.image, M);
    IF F.image.changed THEN SetChangeMark(F, 1) END
  END Restore;

  PROCEDURE FlipCross(X, Y: INTEGER);
  BEGIN
    IF X < CL THEN
      IF X < 7 THEN X := 7 ELSIF X > DW - 7 THEN X := DW - 7 END
    ELSE
      IF X < CL + 7 THEN X := CL + 7 ELSIF X > CL + DW - 7 THEN X := CL + DW - 7 END
    END;
    IF Y < 7 THEN Y := 7 ELSIF Y > DH THEN Y := DH - 7 END;
    Display.CopyPattern(Display.white, Display.cross, X-7, Y-7, Display.invert)
  END FlipCross;

  PROCEDURE Focus*(): Frame;
    VAR FQ: FocusQuery;
  BEGIN FQ.f := NIL; Viewers.Broadcast(FQ); RETURN FQ.f
  END Focus;

  PROCEDURE Selected*(): Frame;
    VAR SQ: SelQuery;
  BEGIN SQ.f := NIL; SQ.time := 0; Viewers.Broadcast(SQ); RETURN SQ.f
  END Selected;

  PROCEDURE This*(x, y: INTEGER): Frame;
    VAR PQ: PosQuery;
  BEGIN PQ.f := NIL; PQ.x := x; PQ.y := y; Viewers.Broadcast(PQ); RETURN PQ.f
  END This;

  PROCEDURE Mark(F: Frame; mode: INTEGER);
    VAR CM: ChangedMsg;
  BEGIN CM.f := F; CM.image := F.image; CM.mode := mode; Viewers.Broadcast(CM)
  END Mark;

  PROCEDURE Draw*(F: Frame);
    VAR UM: UpdateMsg;
  BEGIN UM.id := drawsel; UM.image := F.image; Viewers.Broadcast(UM)
  END Draw;

  PROCEDURE DrawNorm(F: Frame);
    VAR UM: UpdateMsg;
  BEGIN UM.id := drawnorm; UM.image := F.image; Viewers.Broadcast(UM)
  END DrawNorm;

  PROCEDURE Erase*(F: Frame);
    VAR UM: UpdateMsg;
  BEGIN UM.id := drawdel; UM.image := F.image; Viewers.Broadcast(UM); Mark(F, 1)
  END Erase;

  PROCEDURE DrawLayer*(F: Frame; lyr: Image.Layer);
    VAR UM: UpdateMsg;
  BEGIN UM.id := drawobj; UM.image := F.image; UM.obj := obj; Viewers.Broadcast(UM)
  END DrawObj;

  PROCEDURE EraseLayer*(F: Frame; lyr: Image.Layer);
    VAR UM: UpdateMsg;
  BEGIN UM.id := drawobjd; UM.image := F.image; UM.obj := obj; Viewers.Broadcast(UM)
  END EraseObj;

  PROCEDURE Change*(F: Frame; VAR msg: Image.Msg);
  BEGIN
    IF F # NIL THEN Erase(F); Image.Change(F.image, msg); Draw(F) END
  END Change;

  PROCEDURE FlipMark(x, y: INTEGER);
  BEGIN
    Display.ReplConst(Display.white, x-7, y, 15, 1, 2);
    Display.ReplConst(Display.white, x, y-7, 1, 15, 2)
  END FlipMark;

  PROCEDURE Defocus*(F: Frame);
    VAR m: Location;
  BEGIN newcap := NIL;
    IF F.marked THEN
      FlipMark(F.mark.x, F.mark.y); m := F.mark.next;
      WHILE m # NIL DO FlipMark(m.x, m.y); m := m.next END ;
      F.marked := FALSE; F.mark.next := NIL
    END
  END Defocus;

  PROCEDURE Deselect*(F: Frame);
    VAR UM: UpdateMsg;
  BEGIN
    IF F # NIL THEN
      UM.id := drawnorm; UM.image := F.image; Viewers.Broadcast(UM);
      Image.Deselect(F.image)
    END
  END Deselect;

  PROCEDURE Edit(F: Frame; x0, y0: INTEGER; k0: SET);
(*    VAR obj: Graphics.Object;
      x1, y1, w, h, t: INTEGER;
      beg, end, time: LONGINT;
      k1, k2: SET;
      mark, newmark: Location;
      T: Texts.Text;
      Fd: Frame;
      G: Graphics.Graph;  *)
  BEGIN (* k1 := k0; G := F.graph;
    REPEAT Input.Mouse(k2, x1, y1); k1 := k1 + k2;
      DEC(x1, (x1-F.x) MOD 4); DEC(y1, (y1-F.y) MOD 4);
      Oberon.DrawMouse(Crosshair, x1, y1)
    UNTIL  k2 = {};
    Oberon.FadeMouse;
    IF k0 = {2} THEN (*left key*)
      w := ABS(x1-x0); h := ABS(y1-y0);
      IF k1 = {2} THEN
        IF (w < 7) & (h < 7) THEN (*set mark*)
          IF (x1 - markW >= F.X) & (x1 + markW < F.X1) &
            (y1 - markW >= F.Y) & (y1 + markW < F.Y1) THEN
            Defocus(F); Oberon.PassFocus(Viewers.This(F.X, F.Y));
            F.mark.x := x1; F.mark.y := y1; F.marked := TRUE; FlipMark(x1, y1)
          END
        ELSE (*draw line*) Deselect(F);
          IF w < h THEN
            IF y1 < y0 THEN y0 := y1 END ;
            NewLine(F, G, x0, y0, Graphics.width, h)
          ELSE
            IF x1 < x0 THEN x0 := x1 END ;
            NewLine(F, G, x0, y0, w, Graphics.width)
          END ;
          Draw(F)
        END
      ELSIF k1 = {2, 1} THEN (*copy text selection to mark*)
        Deselect(F); Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN
          DrawObj(F, CaptionCopy(F, x1, y1, T, beg, end)); Mark(F, 1)
        END
      ELSIF k1 = {2, 0} THEN
        IF F.marked THEN (*set secondary mark*)
            NEW(newmark); newmark.x := x1; newmark.y := y1; newmark.next := NIL;
          FlipMark(x1, y1); mark := F.mark.next;
          IF mark = NIL THEN F.mark.next := newmark ELSE
            WHILE mark.next # NIL DO mark := mark.next END ;
            mark.next := newmark
          END
        END
      END
    ELSIF k0 = {1} THEN (*middle key*)
      IF k1 = {1} THEN (*move*)
        IF (x0 # x1) OR (y0 # y1) THEN
          Fd := This(x1, y1); Erase(F);
          IF Fd = F THEN Graphics.Move(G, x1-x0, y1-y0)
          ELSIF (Fd # NIL) & (Fd.graph = G) THEN
            Graphics.Move(G, (x1-Fd.x-x0+F.x) DIV 4 * 4, (y1-Fd.y-y0+F.y) DIV 4 * 4)
          END ;
          Draw(F); Mark(F, 1)
        END
      ELSIF k1 = {1, 2} THEN (*copy*)
        Fd := This(x1, y1);
        IF Fd # NIL THEN DrawNorm(F);
          IF Fd = F THEN Graphics.Copy(G, G, x1-x0, y1-y0)
          ELSE Deselect(Fd);
            Graphics.Copy(G, Fd.graph, (x1-Fd.x-x0+F.x) DIV 4 * 4, (y1-Fd.y-y0+F.y) DIV 4 * 4)
          END ;
          Draw(Fd); Mark(F, 1)
        END
      ELSIF k1 = {1, 0} THEN (*shift graph*)
        INC(F.Xg, x1-x0); INC(F.Yg, y1-y0); Restore(F)
      END
    ELSIF k0 = {0} THEN (*right key: select*)
      newcap := NIL;
      IF k1 = {0} THEN Deselect(F) END ;
      IF (ABS(x0-x1) < 7) & (ABS(y0-y1) < 7) THEN
        obj := Graphics.ThisObj(G, x1 - F.x, y1 - F.y);
        IF obj # NIL THEN Graphics.SelectObj(G, obj); DrawObj(F, obj) END
      ELSE
        IF x1 < x0 THEN t := x0; x0 := x1; x1 := t END ;
        IF y1 < y0 THEN t := y0; y0 := y1; y1 := t END ;
        Graphics.SelectArea(G, x0 - F.x, y0 - F.y, x1 - F.x, y1 - F.y); Draw(F)
      END
    END  *)
  END Edit;


  PROCEDURE NewCaption(F: Frame; col: INTEGER; font: Fonts.Font);
  BEGIN (* Texts.Write(W, 0AX);
    NEW(newcap); newcap.x := F.mark.x - F.x; newcap.y := F.mark.y - F.y + font.minY;
    newcap.w := 0; newcap.h := font.height; newcap.col := col;
    newcap.pos := Graphics.T.len + 1; newcap.len := 0; newcap.do := Graphics.CapMethod;
    Graphics.Add(F.graph, newcap); W.fnt := font; ; Mark(F, 1)  *)
  END NewCaption;

  PROCEDURE InsertChar(F: Frame; codepoint: INTEGER);
 (*   VAR w1, h1: INTEGER; DM: DispMsg; *)
  BEGIN (* DM.graph := F.graph;
    Fonts.GetUniPat(W.fnt, codepoint, DM.w, DM.x1, DM.y1, w1, h1, DM.pat); DEC(DM.y1, W.fnt.minY);
    IF newcap.x + newcap.w + DM.w + F.x < F.X1 THEN
      Viewers.Broadcast(DM); INC(newcap.w, DM.w); INC(newcap.len, Texts.UnicodeWidth(codepoint)); Texts.WriteUnicode(W, codepoint)
    END ;
    Texts.Append(Graphics.T, W.buf) *)
  END InsertChar;

  PROCEDURE DeleteChar(F: Frame);
  (*  VAR w1, h1, charlen, codepoint, pos: INTEGER; ch: CHAR;
      DM: DispMsg; R: Texts.Reader; *)
  BEGIN (* DM.graph := F.graph;
    IF newcap.len > 0 THEN
      charlen := 0; (*backspace*)
      pos := Graphics.T.len;
      REPEAT INC(charlen);
        Texts.OpenReader(R, Graphics.T, pos-charlen);
        Texts.Read(R, ch);
      UNTIL (ch < 80X) OR (ch >= 0C0X); (* skip over continuation *)
      Texts.OpenReader(R, Graphics.T, pos-charlen);
      Texts.ReadUnicode(R, codepoint);
      IF codepoint >= ORD(" ") THEN
        Fonts.GetUniPat(R.fnt, codepoint, DM.w, DM.x1, DM.y1, w1, h1, DM.pat);
        DEC(newcap.w, DM.w); DEC(newcap.len, charlen); DEC(DM.y1, R.fnt.minY);
        Viewers.Broadcast(DM); Texts.Delete(Graphics.T, pos-charlen, pos, TBuf)
      END
    END *)
  END DeleteChar;

  PROCEDURE GetSelection(F: Frame; VAR text: Texts.Text; VAR beg, end, time: LONGINT);
 (*   VAR obj: Graphics.Object; *)
  BEGIN (* obj := F.graph.sel;
    IF (obj # NIL) & (F.graph.time >= time) THEN
      CASE obj OF Graphics.Caption:
        beg := obj.pos; end := obj.pos + obj.len; text := Graphics.T; time := F.graph.time
      END
    END *)
  END GetSelection;

  PROCEDURE Handle*(G: Display.Frame; VAR M: Display.FrameMsg);
    VAR x, y, h: INTEGER;
      DM: DispMsg; dM: DrawMsg;
      G1: Frame;
  BEGIN  (*
    CASE G OF Frame:
      CASE M OF
      Oberon.InputMsg:
        IF M.id = Oberon.track THEN
          x := M.X - (M.X - G.x) MOD 4; y := M.Y - (M.Y - G.y) MOD 4;
          IF M.keys # {} THEN Edit(G, x, y, M.keys) ELSE Oberon.DrawMouse(Crosshair, x, y) END
        ELSIF M.id = Oberon.consume THEN
          IF M.codepoint = 7FH THEN (*DEL*)
            Erase(G); Graphics.Delete(G.graph); Mark(G, 1)
          ELSIF (M.codepoint >= 20H) THEN
            IF newcap # NIL THEN InsertChar(G, M.codepoint); Mark(G, 1)
            ELSIF G.marked THEN
              Defocus(G); Deselect(G); NewCaption(G, M.col, M.fnt); InsertChar(G, M.codepoint)
            END
          ELSIF (M.codepoint = ORD(08X)) & (newcap # NIL) THEN DeleteChar(G); Mark(G, 1)
          END
        END
      | UpdateMsg:
          IF M.graph = G.graph THEN
            dM.f := G; dM.x := G.x; dM.y := G.y; dM.col := 0;
            IF M.id = drawobj THEN dM.mode := 0; M.obj.do.draw(M.obj, dM)
            ELSIF M.id = drawobjs THEN dM.mode := 1; M.obj.do.draw(M.obj, dM)
            ELSIF M.id = drawobjd THEN dM.mode := 3; M.obj.do.draw(M.obj, dM)
            ELSIF M.id = drawsel THEN  dM.mode := 0; Graphics.DrawSel(G.graph, dM)
            ELSIF M.id = drawnorm THEN dM.mode := 2; Graphics.DrawSel(G.graph, dM)
            ELSIF M.id = drawdel THEN dM.mode := 3; Graphics.DrawSel(G.graph, dM)
            END
          END
      | ChangedMsg:
          IF M.graph = G.graph THEN SetChangeMark(G, M.mode) END
      | SelQuery:
          IF (G.graph.sel # NIL) & (M.time < G.graph.time) THEN M.f := G(Frame); M.time := G.graph.time END
      | FocusQuery: IF G.marked THEN M.f := G END
      | PosQuery: IF (G.X <= M.x) & (M.x < G.X1) & (G.Y <= M.y) & (M.y < G.Y1) THEN M.f := G END
      | DispMsg:
        DM := M;
        x := G.x + newcap.x + newcap.w; y := G.y + newcap.y;
        IF (DM.graph = G.graph) & (x >= G.X) & (x + DM.w < G.X1) & (y >= G.Y) & (y < G.Y1) THEN
          Display.CopyPattern(Oberon.CurCol, DM.pat, x + DM.x1, y + DM.y1, 2);
          Display.ReplConst(Display.white, x, y, DM.w, newcap.h, 2)
        END
      | Oberon.ControlMsg:
          IF M.id = Oberon.neutralize THEN
            Oberon.RemoveMarks(G.X, G.Y, G.W, G.H); Defocus(G); DrawNorm(G); Graphics.Deselect(G.graph)
          ELSIF M.id = Oberon.defocus THEN Defocus(G)
          END
      | Oberon.SelectionMsg: GetSelection(G, M.text, M.beg, M.end, M.time)
      | Oberon.CopyMsg: Oberon.RemoveMarks(G.X, G.Y, G.W, G.H); Defocus(G); NEW(G1); G1^ := G^; M.F := G1
      | MenuViewers.ModifyMsg: G.Y := M.Y; G.H := M.H; Restore(G)
      END
    END  *)
  END Handle;

  PROCEDURE Store*(F: Frame; name: ARRAY OF CHAR);
  BEGIN (* Mark(F, 0); Graphics.WriteFile(F.graph, name) *)
  END Store;

  (*------------------- Draw Methods -----------------------*)

  PROCEDURE ReplConst*(F: Frame; col, x, y, w, h, mode: INTEGER);
  BEGIN
    IF x < F.X THEN DEC(w, F.X-x); x := F.X END ;
    IF x+w >= F.X1 THEN w := F.X1 - x END ;
    IF y < F.Y THEN DEC(h, F.Y-y); y := F.Y END ;
    IF y+h >= F.Y1 THEN h := F.Y1 - y END ;
    Display.ReplConst(col, x, y, w, h, mode)
  END ReplConst;

  PROCEDURE ReplPattern*(F: Frame; col, patadr, x, y, w, h, mode: INTEGER);
  BEGIN
    IF x < F.X THEN DEC(w, F.X-x); x := F.X END ;
    IF x+w >= F.X1 THEN w := F.X1 - x END ;
    IF y < F.Y THEN DEC(h, F.Y-y); y := F.Y END ;
    IF y+h >= F.Y1 THEN h := F.Y1 - y END ;
    Display.ReplPattern(col, patadr, x, y, w, h, mode)
  END ReplPattern;

  PROCEDURE DrawLine(obj: Graphics.Object; VAR M: Graphics.Msg);
    (*M.mode = 0: draw according to state,
        = 1: normal -> selected,
        = 2: selected -> normal,
        = 3: erase*)
    VAR x, y, w, h, col: INTEGER; f: Frame;
  BEGIN
    CASE M OF DrawMsg:
      x := obj.x + M.x; y := obj.y + M.y; w := obj.w; h := obj.h; f := M.f;
      IF (x+w > f.X) & (x < f.X1) & (y+h > f.Y) & (y < f.Y1) THEN
        col := Display.white;
        IF (M.mode = 0) & obj.selected OR (M.mode = 1) THEN
          ReplPattern(f, col, Display.grey, x, y, w, h, Display.replace)
        ELSIF M.mode IN {0, 2} THEN ReplConst(f, col, x, y, w, h, Display.replace)
        ELSIF M.mode = 3 THEN ReplConst(f, Display.black, x, y, w, h, Display.replace)  (*erase*)
        END
      END
    END
  END DrawLine;

  PROCEDURE DrawCaption(obj: Graphics.Object; VAR M: Graphics.Msg);
    VAR x, y, dx, x0, x1, y0, y1, w, h, w1, h1, col, codepoint: INTEGER;
      f: Frame;
      pat: INTEGER; fnt: Fonts.Font;
      R: Texts.Reader;
  BEGIN
    CASE M OF DrawMsg:
      x := obj.x + M.x; y := obj.y + M.y; w := obj.w; h := obj.h; f := M.f;
      IF (f.X <= x) & (x <= f.X1) & (f.Y <= y) & (y+h <= f.Y1) THEN
        IF x+w > f.X1 THEN w := f.X1-x END ;
        Texts.OpenReader(R, Graphics.T, obj(Graphics.Caption).pos); Texts.ReadUnicode(R, codepoint);
        IF M.mode = 0 THEN
          IF codepoint >= ORD(" ") THEN
            fnt := R.fnt; x0 := x; y0 := y - fnt.minY;
            REPEAT Fonts.GetUniPat(fnt, codepoint, dx, x1, y1, w1, h1, pat);
              IF x0+x1+w1 <= f.X1 THEN
                Display.CopyPattern(col, pat, x0+x1, y0+y1, Display.paint); INC(x0, dx); Texts.ReadUnicode(R, codepoint)
              ELSE codepoint := 0
              END
            UNTIL codepoint < ORD(" ");
            IF obj.selected THEN ReplConst(f, Display.white, x, y, w, h, Display.invert) END
          END
        ELSIF M.mode IN {1, 2} THEN ReplConst(f, Display.white, x, y, w, h, Display.invert)
        ELSIF M.mode = 3 THEN ReplConst(f, Display.black, x, y, w, h, Display.replace)
        END
      END
    END
  END DrawCaption;


  PROCEDURE DrawMacro(obj: Graphics.Object; VAR M: Graphics.Msg);
    VAR x, y, w, h: INTEGER;
      f: Frame; M1: DrawMsg;
  BEGIN
    CASE M OF DrawMsg:
      x := obj.x + M.x; y := obj.y + M.y; w := obj.w; h := obj.h; f := M.f;
      IF (x+w > f.X) & (x < f.X1) & (y+h > f.Y) & (y < f.Y1) THEN
        M1.x := x; M1.y := y;
        IF M.mode = 0 THEN
          M1.f := f; M1.col := obj.col; M1.mode := 0; Graphics.DrawMac(obj(Graphics.Macro).mac, M1);
          IF obj.selected THEN ReplPattern(f, Display.white, dotted, x, y, w, h, Display.invert) END
        ELSIF M.mode IN {1, 2} THEN ReplPattern(f, Display.white, dotted, x, y, w, h, Display.invert)
        ELSIF M.mode = 3 THEN ReplConst(f, Display.black, x, y, w, h, Display.replace)
        END
      END
    END
  END DrawMacro;

  (*---------------------------------------------------------------*)

  PROCEDURE Open*(G: Frame; image: Images.Image);
  BEGIN G.image := image; G.Xg := 0; G.Yg := 0; G.x := G.X; G.y := G.Y;
    G.col := Display.black; G.marked := FALSE;
    G.mark.next := NIL; G.ticked := TRUE; G.handle := Handle
  END Open;

BEGIN DW := Display.Width - 8; DH := Display.Height - 8; CL := 0;
  Texts.OpenWriter(W);
  tack := SYSTEM.ADR($0707 4122 1408 1422 4100$);
  dotted := SYSTEM.ADR($2004 0000 1111 1111 0000 0000 0000 0000 0000 0000$);
  dotted1 := SYSTEM.ADR($2004 0000 1111 1111 0000 0000 4444 4444 0000 0000$);
  Crosshair.Fade := FlipCross; Crosshair.Draw := FlipCross;
  Images.InstallDrawMethods(DrawLine, DrawCaption, DrawMacro)
END ImageFrames.

