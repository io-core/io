MODULE OXG; (* NW  10.10.2013 CP 6.3.2014 common code generator resources*)
  IMPORT O7B;

    TYPE Item* = RECORD
      mode*: INTEGER;
      type*: O7B.Type;
      a*, b*, r*: LONGINT;
      rdo*: BOOLEAN  (*read only*)
    END ;

  (* Item forms and meaning of fields:
    mode    r      a       b
    --------------------------------
    Const   -     value (proc adr)   (immediate value)
    Var     base   off     -               (direct adr)
    Par      -     off0     off1         (indirect adr)
    Reg    regno
    RegI   regno   off     -
    Cond  cond   Fchain  Tchain  *)


END OXG.
