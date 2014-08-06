MODULE Clock; (*CP 6.7.14 *)
 IMPORT SYSTEM;

  CONST lclkAdr = -32; hclkAdr = -28;

PROCEDURE Read*(): INTEGER;
  VAR lowVal: INTEGER;
  BEGIN
    SYSTEM.GET(lclkAdr,lowVal);
    RETURN lowVal
  END Read;

END Clock.
