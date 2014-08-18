MODULE O7X; (* NW  10.10.2013 CP 6.3.2014 common code generator resources*)

  IMPORT O7S, O7B;
    CONST maxCode* = 8000; maxStrx* = 2400; maxTD* = 120; 
    TYPE 

    Item* = RECORD
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
   Target* = POINTER TO TargetDesc;   TargetDesc* = RECORD     arch*: CHAR;     pc*, varsize*: LONGINT;   (*program counter, data index*) 
    tdx*, strx*: LONGINT; 
    entry*: LONGINT;   (*main entry point*) 
    RH*: LONGINT;  (*available registers R[0] ... R[H-1]*) 
    curSB*: LONGINT;  (*current static base in SB*) 
    fixorgP*, fixorgD*, fixorgT*: LONGINT;   (*origins of lists of locations to be fixed up by loader*)
     check*, inhibitCalls*: BOOLEAN;  (*emit run-time checks*)
     version*: INTEGER;  (* 0 = RISC-0, 1 = RISC-5 *)
     
    opmap*: ARRAY 16 OF INTEGER;  (*machine values of operations*) 
    relmap*: ARRAY 6 OF INTEGER;  (*condition codes for relations*) 
    code*: ARRAY maxCode OF LONGINT; 
    data*: ARRAY maxTD OF LONGINT;  (*type descriptors*)
     str*: ARRAY maxStrx OF CHAR;     Put0* : PROCEDURE(target: Target; u, op, a, b, c: LONGINT);     Put1* : PROCEDURE(target: Target; u, op, a, b, im: LONGINT);     Put1a* : PROCEDURE(target: Target; op, a, b, im: LONGINT);     Put2* : PROCEDURE(target: Target; op, a, b, off: LONGINT);     Put3* : PROCEDURE(target: Target; op, cond, off: LONGINT);     Close* : PROCEDURE(VAR target: Target; modid: O7S.Ident; key, nofent: LONGINT);   END;
END O7X.
