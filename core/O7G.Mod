MODULE O7G; (* NW  10.10.2013 CP 2014,2018 RISC code generator in Oberon-07*)
  IMPORT SYSTEM, Files, O7S, O7B, OXG, Or32G, Oa32G, Oi32G; (*, Ov32G, Or64G, Oa64G, Oi64G, Ov64G; *)
  (*Retargeting Code generator for Oberon compiler.
     Procedural interface to Parser O7P; result in array "code".
     Procedure Close writes code-files*)

  CONST WordSize* = 4; 
  VAR arch: CHAR;

  PROCEDURE GetPC*(): LONGINT;
  VAR t: LONGINT;
  BEGIN
      IF arch = 0X THEN t:= Or32G.GetPC() END;
      IF arch = 1X THEN t:= Oa32G.GetPC() END;
      IF arch = 2X THEN t:= Oi32G.GetPC() END 
 (*   IF arch = 3X THEN t:= Ov32G.GetPC() END;
      IF arch = 4X THEN t:= Or64G.GetPC() END;
      IF arch = 5X THEN t:= Oa64G.GetPC() END;
      IF arch = 6X THEN t:= Oi64G.GetPC() END;
      IF arch = 7X THEN t:= Ov64G.GetPC() END *)
    RETURN t 
  END GetPC;

  PROCEDURE CheckRegs*;
  BEGIN 
    IF arch = 0X THEN Or32G.CheckRegs END;
    IF arch = 1X THEN Oa32G.CheckRegs END;
    IF arch = 2X THEN Oi32G.CheckRegs END
  END CheckRegs;

  PROCEDURE FixLink*(L: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.FixLink(L) END;
    IF arch = 1X THEN Oa32G.FixLink(L) END;
    IF arch = 2X THEN Oi32G.FixLink(L) END
  END FixLink;

  PROCEDURE MakeConstItem*(VAR x: OXG.Item; typ: O7B.Type; val: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.MakeConstItem( x, typ, val ) END;
    IF arch = 1X THEN Oa32G.MakeConstItem( x, typ, val ) END;
    IF arch = 2X THEN Oi32G.MakeConstItem( x, typ, val ) END
  END MakeConstItem;

  PROCEDURE MakeRealItem*(VAR x: OXG.Item; val: REAL);
  BEGIN
    IF arch = 0X THEN Or32G.MakeRealItem( x, val ) END;
    IF arch = 1X THEN Oa32G.MakeRealItem( x, val ) END;
    IF arch = 2X THEN Oi32G.MakeRealItem( x, val ) END
  END MakeRealItem;

  PROCEDURE MakeStringItem*(VAR x: OXG.Item; len: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.MakeStringItem( x, len ) END;
    IF arch = 1X THEN Oa32G.MakeStringItem( x, len ) END;
    IF arch = 2X THEN Oi32G.MakeStringItem( x, len ) END
  END MakeStringItem;

  PROCEDURE MakeItem*(VAR x: OXG.Item; y: O7B.Object; curlev: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.MakeItem( x, y, curlev ) END;
    IF arch = 1X THEN Oa32G.MakeItem( x, y, curlev ) END;
    IF arch = 2X THEN Oi32G.MakeItem( x, y, curlev ) END
  END MakeItem;

  PROCEDURE Field*(VAR x: OXG.Item; y: O7B.Object);
  BEGIN;
    IF arch = 0X THEN Or32G.Field( x, y ) END;
    IF arch = 1X THEN Oa32G.Field( x, y ) END;
    IF arch = 2X THEN Oi32G.Field( x, y ) END
  END Field;

  PROCEDURE Index*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Index( x, y ) END;
    IF arch = 1X THEN Oa32G.Index( x, y ) END;
    IF arch = 2X THEN Oi32G.Index( x, y ) END
  END Index;

  PROCEDURE DeRef*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.DeRef( x ) END;
    IF arch = 1X THEN Oa32G.DeRef( x ) END;
    IF arch = 2X THEN Oi32G.DeRef( x ) END
  END DeRef;

  PROCEDURE BuildTD*(T: O7B.Type; VAR dc: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.BuildTD( T, dc ) END;
    IF arch = 1X THEN Oa32G.BuildTD( T, dc ) END;
    IF arch = 2X THEN Oi32G.BuildTD( T, dc ) END
  END BuildTD;

  PROCEDURE TypeTest*(VAR x: OXG.Item; T: O7B.Type; varpar, isguard: BOOLEAN);
  BEGIN
    IF arch = 0X THEN Or32G.TypeTest( x, T, varpar, isguard ) END;
    IF arch = 1X THEN Oa32G.TypeTest( x, T, varpar, isguard ) END;
    IF arch = 2X THEN Oi32G.TypeTest( x, T, varpar, isguard ) END
  END TypeTest;

  PROCEDURE Not*(VAR x: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.Not( x ) END;
    IF arch = 1X THEN Oa32G.Not( x ) END;
    IF arch = 2X THEN Oi32G.Not( x ) END
  END Not;

  PROCEDURE And1*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.And1( x ) END;
    IF arch = 1X THEN Oa32G.And1( x ) END;
    IF arch = 2X THEN Oi32G.And1( x ) END
  END And1;

  PROCEDURE And2*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.And2( x, y ) END;
    IF arch = 1X THEN Oa32G.And2( x, y ) END;
    IF arch = 2X THEN Oi32G.And2( x, y ) END
  END And2;

  PROCEDURE Or1*(VAR x: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.Or1( x ) END;
    IF arch = 1X THEN Oa32G.Or1( x ) END;
    IF arch = 2X THEN Oi32G.Or1( x ) END
  END Or1;

  PROCEDURE Or2*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Or2( x, y ) END;
    IF arch = 1X THEN Oa32G.Or2( x, y ) END;
    IF arch = 2X THEN Oi32G.Or2( x, y ) END
  END Or2;

  PROCEDURE Neg*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Neg( x ) END;
    IF arch = 1X THEN Oa32G.Neg( x ) END;
    IF arch = 2X THEN Oi32G.Neg( x ) END
  END Neg;

  PROCEDURE AddOp*(op: LONGINT; VAR x, y: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.AddOp( op, x, y ) END;
    IF arch = 1X THEN Oa32G.AddOp( op, x, y ) END;
    IF arch = 2X THEN Oi32G.AddOp( op, x, y ) END
  END AddOp;

  PROCEDURE MulOp*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.MulOp( x, y ) END;
    IF arch = 1X THEN Oa32G.MulOp( x, y ) END;
    IF arch = 2X THEN Oi32G.MulOp( x, y ) END
  END MulOp;

  PROCEDURE DivOp*(op: LONGINT; VAR x, y: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.DivOp( op, x, y ) END;
    IF arch = 1X THEN Oa32G.DivOp( op, x, y ) END;
    IF arch = 2X THEN Oi32G.DivOp( op, x, y ) END
  END DivOp;

  PROCEDURE RealOp*(op: INTEGER; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.RealOp( op, x, y ) END;
    IF arch = 1X THEN Oa32G.RealOp( op, x, y ) END;
    IF arch = 2X THEN Oi32G.RealOp( op, x, y ) END
  END RealOp;

  PROCEDURE Singleton*(VAR x: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.Singleton( x ) END;
    IF arch = 1X THEN Oa32G.Singleton( x ) END;
    IF arch = 2X THEN Oi32G.Singleton( x ) END
  END Singleton;

  PROCEDURE Set*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Set( x, y ) END;
    IF arch = 1X THEN Oa32G.Set( x, y ) END;
    IF arch = 2X THEN Oi32G.Set( x, y ) END
  END Set;

  PROCEDURE In*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.In( x, y ) END;
    IF arch = 1X THEN Oa32G.In( x, y ) END;
    IF arch = 2X THEN Oi32G.In( x, y ) END
  END In;

  PROCEDURE SetOp*(op: LONGINT; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.SetOp( op, x, y ) END;
    IF arch = 1X THEN Oa32G.SetOp( op, x, y ) END;
    IF arch = 2X THEN Oi32G.SetOp( op, x, y ) END
  END SetOp;

  PROCEDURE IntRelation*(op: INTEGER; VAR x, y: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.IntRelation( op, x, y ) END;
    IF arch = 1X THEN Oa32G.IntRelation( op, x, y ) END;
    IF arch = 2X THEN Oi32G.IntRelation( op, x, y ) END
  END IntRelation;

  PROCEDURE SetRelation*(op: INTEGER; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.SetRelation( op, x, y ) END;
    IF arch = 1X THEN Oa32G.SetRelation( op, x, y ) END;
    IF arch = 2X THEN Oi32G.SetRelation( op, x, y ) END
  END SetRelation;

  PROCEDURE RealRelation*(op: INTEGER; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.RealRelation( op, x, y ) END;
    IF arch = 1X THEN Oa32G.RealRelation( op, x, y ) END;
    IF arch = 2X THEN Oi32G.RealRelation( op, x, y ) END
  END RealRelation;

  PROCEDURE StringRelation*(op: INTEGER; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.StringRelation( op, x, y ) END;
    IF arch = 1X THEN Oa32G.StringRelation( op, x, y ) END;
    IF arch = 2X THEN Oi32G.StringRelation( op, x, y ) END
  END StringRelation;

  PROCEDURE StrToChar*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.StrToChar( x ) END;
    IF arch = 1X THEN Oa32G.StrToChar( x ) END;
    IF arch = 2X THEN Oi32G.StrToChar( x ) END
  END StrToChar;

  PROCEDURE Store*(VAR x, y: OXG.Item);
  BEGIN 
    IF arch = 0X THEN Or32G.Store( x, y ) END;
    IF arch = 1X THEN Oa32G.Store( x, y ) END;
    IF arch = 2X THEN Oi32G.Store( x, y ) END
  END Store;

  PROCEDURE StoreStruct*(VAR x, y: OXG.Item); 
  BEGIN
    IF arch = 0X THEN Or32G.StoreStruct(x,y) END;
    IF arch = 1X THEN Oa32G.StoreStruct(x,y) END;
    IF arch = 2X THEN Oi32G.StoreStruct(x,y) END
  END StoreStruct;

  PROCEDURE CopyString*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.CopyString(x,y) END;
    IF arch = 1X THEN Oa32G.CopyString(x,y) END;
    IF arch = 2X THEN Oi32G.CopyString(x,y) END
  END CopyString;

  PROCEDURE VarParam*(VAR x: OXG.Item; ftype: O7B.Type);
  BEGIN
    IF arch = 0X THEN Or32G.VarParam(x,ftype) END;    IF arch = 1X THEN Oa32G.VarParam(x,ftype) END;    IF arch = 2X THEN Oi32G.VarParam(x,ftype) END  END VarParam;

  PROCEDURE ValueParam*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.ValueParam(x) END;
    IF arch = 1X THEN Oa32G.ValueParam(x) END;
    IF arch = 2X THEN Oi32G.ValueParam(x) END
  END ValueParam;

  PROCEDURE OpenArrayParam*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.OpenArrayParam(x) END;
    IF arch = 1X THEN Oa32G.OpenArrayParam(x) END;
    IF arch = 2X THEN Oi32G.OpenArrayParam(x) END
  END OpenArrayParam;

  PROCEDURE StringParam*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.StringParam(x) END;
    IF arch = 1X THEN Oa32G.StringParam(x) END;
    IF arch = 2X THEN Oi32G.StringParam(x) END
  END StringParam;

  PROCEDURE For0*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.For0(x,y) END;
    IF arch = 1X THEN Oa32G.For0(x,y) END;
    IF arch = 2X THEN Oi32G.For0(x,y) END
  END For0;

  PROCEDURE For1*(VAR x, y, z, w: OXG.Item; VAR L: LONGINT);
  BEGIN 
    IF arch = 0X THEN Or32G.For1(x,y,z,w,L) END;
    IF arch = 1X THEN Oa32G.For1(x,y,z,w,L) END;
    IF arch = 2X THEN Oi32G.For1(x,y,z,w,L) END
  END For1;

  PROCEDURE For2*(VAR x, y, w: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.For2(x,y,w) END;
    IF arch = 1X THEN Oa32G.For2(x,y,w) END;
    IF arch = 2X THEN Oi32G.For2(x,y,w) END
  END For2;

  PROCEDURE Here*(): LONGINT;
    VAR t: LONGINT;
  BEGIN
    IF arch = 0X THEN t:=Or32G.Here() END;
    IF arch = 1X THEN t:=Oa32G.Here() END;
    IF arch = 2X THEN t:=Oi32G.Here() END;
    RETURN t
  END Here;

  PROCEDURE FJump*(VAR L: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.FJump(L) END;
    IF arch = 1X THEN Oa32G.FJump(L) END;
    IF arch = 2X THEN Oi32G.FJump(L) END
  END FJump;

  PROCEDURE CFJump*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.CFJump(x) END;
    IF arch = 1X THEN Oa32G.CFJump(x) END;
    IF arch = 2X THEN Oi32G.CFJump(x) END
  END CFJump;

  PROCEDURE BJump*(L: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.BJump(L) END;
    IF arch = 1X THEN Oa32G.BJump(L) END;
    IF arch = 2X THEN Oi32G.BJump(L) END
  END BJump;

  PROCEDURE CBJump*(VAR x: OXG.Item; L: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.CBJump(x,L) END;
    IF arch = 1X THEN Oa32G.CBJump(x,L) END;
    IF arch = 2X THEN Oi32G.CBJump(x,L) END
  END CBJump;

  PROCEDURE Fixup*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Fixup(x) END;
    IF arch = 1X THEN Oa32G.Fixup(x) END;
    IF arch = 2X THEN Oi32G.Fixup(x) END
  END Fixup;

  PROCEDURE PrepCall*(VAR x: OXG.Item; VAR r: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.PrepCall(x,r) END;
    IF arch = 1X THEN Oa32G.PrepCall(x,r) END;
    IF arch = 2X THEN Oi32G.PrepCall(x,r) END
  END PrepCall;

  PROCEDURE Call*(VAR x: OXG.Item; r: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.Call(x,r) END;
    IF arch = 1X THEN Oa32G.Call(x,r) END;
    IF arch = 2X THEN Oi32G.Call(x,r) END
  END Call;

  PROCEDURE Enter*(parblksize, locblksize: LONGINT; int: BOOLEAN);
  BEGIN
    IF arch = 0X THEN Or32G.Enter(parblksize,locblksize,int) END;
    IF arch = 1X THEN Oa32G.Enter(parblksize,locblksize,int) END;
    IF arch = 2X THEN Oi32G.Enter(parblksize,locblksize,int) END
  END Enter;

  PROCEDURE Return*(form: INTEGER; VAR x: OXG.Item; size: LONGINT; int: BOOLEAN);
  BEGIN
    IF arch = 0X THEN Or32G.Return(form,x,size,int) END;
    IF arch = 1X THEN Oa32G.Return(form,x,size,int) END;
    IF arch = 2X THEN Oi32G.Return(form,x,size,int) END
  END Return;

  PROCEDURE Increment*(upordown: LONGINT; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Increment(upordown,x,y) END;
    IF arch = 1X THEN Oa32G.Increment(upordown,x,y) END;
    IF arch = 2X THEN Oi32G.Increment(upordown,x,y) END
  END Increment;

  PROCEDURE Include*(inorex: LONGINT; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Include(inorex,x,y) END;
    IF arch = 1X THEN Oa32G.Include(inorex,x,y) END;
    IF arch = 2X THEN Oi32G.Include(inorex,x,y) END
  END Include;

  PROCEDURE Assert*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Assert(x) END;
    IF arch = 1X THEN Oa32G.Assert(x) END;
    IF arch = 2X THEN Oi32G.Assert(x) END
  END Assert; 

  PROCEDURE New*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.New(x) END;
    IF arch = 1X THEN Oa32G.New(x) END;
    IF arch = 2X THEN Oi32G.New(x) END
  END New;

  PROCEDURE Pack*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Pack(x,y) END;
    IF arch = 1X THEN Oa32G.Pack(x,y) END;
    IF arch = 2X THEN Oi32G.Pack(x,y) END
  END Pack;

  PROCEDURE Unpk*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Unpk(x,y) END;
    IF arch = 1X THEN Oa32G.Unpk(x,y) END;
    IF arch = 2X THEN Oi32G.Unpk(x,y) END
  END Unpk;

  PROCEDURE Led*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Led(x) END;
    IF arch = 1X THEN Oa32G.Led(x) END;
    IF arch = 2X THEN Oi32G.Led(x) END
  END Led;

  PROCEDURE Get*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Get(x,y) END;
    IF arch = 1X THEN Oa32G.Get(x,y) END;
    IF arch = 2X THEN Oi32G.Get(x,y) END
  END Get;

  PROCEDURE Put*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Put(x,y) END;
    IF arch = 1X THEN Oa32G.Put(x,y) END;
    IF arch = 2X THEN Oi32G.Put(x,y) END
  END Put;

  PROCEDURE Copy*(VAR x, y, z: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Copy(x,y,z) END;
    IF arch = 1X THEN Oa32G.Copy(x,y,z) END;
    IF arch = 2X THEN Oi32G.Copy(x,y,z) END
  END Copy;

  PROCEDURE LDPSR*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.LDPSR(x) END;
    IF arch = 1X THEN Oa32G.LDPSR(x) END;
    IF arch = 2X THEN Oi32G.LDPSR(x) END
  END LDPSR;

  PROCEDURE LDREG*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.LDREG(x,y) END;
    IF arch = 1X THEN Oa32G.LDREG(x,y) END;
    IF arch = 2X THEN Oi32G.LDREG(x,y) END
  END LDREG;

  PROCEDURE Abs*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Abs(x) END;
    IF arch = 1X THEN Oa32G.Abs(x) END;
    IF arch = 2X THEN Oi32G.Abs(x) END
  END Abs;

  PROCEDURE Odd*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Odd(x) END;
    IF arch = 1X THEN Oa32G.Odd(x) END;
    IF arch = 2X THEN Oi32G.Odd(x) END
  END Odd;

  PROCEDURE Floor*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Floor(x) END;
    IF arch = 1X THEN Oa32G.Floor(x) END;
    IF arch = 2X THEN Oi32G.Floor(x) END
  END Floor;

  PROCEDURE Float*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Float(x) END;
    IF arch = 1X THEN Oa32G.Float(x) END;
    IF arch = 2X THEN Oi32G.Float(x) END
  END Float;

  PROCEDURE Ord*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Ord(x) END;
    IF arch = 1X THEN Oa32G.Ord(x) END;
    IF arch = 2X THEN Oi32G.Ord(x) END
  END Ord;

  PROCEDURE Len*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Len(x) END;
    IF arch = 1X THEN Oa32G.Len(x) END;
    IF arch = 2X THEN Oi32G.Len(x) END
  END Len;

  PROCEDURE Shift*(fct: LONGINT; VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Shift(fct,x,y) END;
    IF arch = 1X THEN Oa32G.Shift(fct,x,y) END;
    IF arch = 2X THEN Oi32G.Shift(fct,x,y) END
  END Shift;

  PROCEDURE ADC*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.ADC(x,y) END;
    IF arch = 1X THEN Oa32G.ADC(x,y) END;
    IF arch = 2X THEN Oi32G.ADC(x,y) END
  END ADC;

  PROCEDURE SBC*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.SBC(x,y) END;
    IF arch = 1X THEN Oa32G.SBC(x,y) END;
    IF arch = 2X THEN Oi32G.SBC(x,y) END
  END SBC;

  PROCEDURE UML*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.UML(x,y) END;
    IF arch = 1X THEN Oa32G.UML(x,y) END;
    IF arch = 2X THEN Oi32G.UML(x,y) END
  END UML;

  PROCEDURE Bit*(VAR x, y: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Bit(x,y) END;
    IF arch = 1X THEN Oa32G.Bit(x,y) END;
    IF arch = 2X THEN Oi32G.Bit(x,y) END
  END Bit;

  PROCEDURE Register*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Register(x) END;
    IF arch = 1X THEN Oa32G.Register(x) END;
    IF arch = 2X THEN Oi32G.Register(x) END
  END Register;

  PROCEDURE H*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.H(x) END;
    IF arch = 1X THEN Oa32G.H(x) END;
    IF arch = 2X THEN Oi32G.H(x) END
  END H;

  PROCEDURE Adr*(VAR x: OXG.Item);
  BEGIN 
    IF arch = 0X THEN Or32G.Adr(x) END;
    IF arch = 1X THEN Oa32G.Adr(x) END;
    IF arch = 2X THEN Oi32G.Adr(x) END;
  END Adr;

  PROCEDURE Condition*(VAR x: OXG.Item);
  BEGIN
    IF arch = 0X THEN Or32G.Condition(x) END;
    IF arch = 1X THEN Oa32G.Condition(x) END;
    IF arch = 2X THEN Oi32G.Condition(x) END
  END Condition;

  PROCEDURE Open*(v: INTEGER);
  BEGIN
    IF arch = 0X THEN Or32G.Open(v) END;
    IF arch = 1X THEN Oa32G.Open(v) END;
    IF arch = 2X THEN Oi32G.Open(v) END
  END Open;

  PROCEDURE SetDataSize*(dc: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.SetDataSize(dc) END;
    IF arch = 1X THEN Oa32G.SetDataSize(dc) END;
    IF arch = 2X THEN Oi32G.SetDataSize(dc) END
  END SetDataSize;

  PROCEDURE Header*;
  BEGIN
    IF arch = 0X THEN Or32G.Header; END;
    IF arch = 1X THEN Oa32G.Header; END;
    IF arch = 2X THEN Oi32G.Header; END
  END Header;

  PROCEDURE Close*(VAR modid: O7S.Ident; key, nofent: LONGINT);
  BEGIN
    IF arch = 0X THEN Or32G.Close(modid,key,nofent) END;
    IF arch = 1X THEN Oa32G.Close(modid,key,nofent) END;
    IF arch = 2X THEN Oi32G.Close(modid,key,nofent) END
  END Close;

  PROCEDURE SetArch*( a : CHAR );
  BEGIN
    arch:=a
  END SetArch;

BEGIN
  arch := 0X;
END O7G.
