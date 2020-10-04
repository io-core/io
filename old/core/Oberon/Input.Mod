MODULE Input; (*NW 5.10.86 / 15.11.90 Ceres-2; PDR 21.4.12 / NW 15.5.2013 Ceres-4*)
              (*CP 12.2018 changed to adopt NL instead of CR *)
              (* Adapted for a customizable framebuffer size -- see git history *)
              (*MS 1.2019 adapted for Unicode*)

  IMPORT SYSTEM;

  CONST msAdr = -40; kbdAdr = -36;
  VAR kbdCode: BYTE; (*last keyboard code read*)
    Recd, Up, Shift, Ctrl, Ext: BOOLEAN;
    KTabAdr: INTEGER;  (*keyboard code translation table*)
    MW, MH, MX, MY: INTEGER; (*mouse limits and coords*)
    MK: SET; (*mouse keys*)

(*FIFO implemented in hardware, because every read must be handled,
  including tracking the state of the Shift and Ctrl keys*)

  PROCEDURE Peek();
  BEGIN
    IF SYSTEM.BIT(msAdr, 28) THEN
      SYSTEM.GET(kbdAdr, kbdCode);
      IF kbdCode = 0F0H THEN Up := TRUE
      ELSIF kbdCode = 0E0H THEN Ext := TRUE
      ELSE
        IF (kbdCode = 12H) OR (kbdCode = 59H) THEN (*shift*) Shift := ~Up
        ELSIF kbdCode = 14H THEN (*ctrl*) Ctrl := ~Up
        ELSIF ~Up THEN Recd := TRUE (*real key going down*)
        END ;
        Up := FALSE; Ext := FALSE
      END
    END;
  END Peek;

  PROCEDURE Available*(): INTEGER;
  BEGIN Peek();
    RETURN ORD(Recd)
  END Available;

  PROCEDURE ReadUnicode*(VAR codepoint: INTEGER);
  VAR ch: CHAR;
  BEGIN
    WHILE ~Recd DO Peek() END ;
    IF Shift OR Ctrl THEN INC(kbdCode, 80H) END; (*ctrl implies shift*)
  (* ch := kbdTab[kbdCode]; *)
    SYSTEM.GET(KTabAdr + kbdCode, ch);
    IF Ctrl THEN ch := CHR(ORD(ch) MOD 20H) END;
    Recd := FALSE;
    codepoint := ORD(ch);
  END ReadUnicode;

  PROCEDURE Mouse*(VAR keys: SET; VAR x, y: INTEGER);
    VAR w: INTEGER;
  BEGIN SYSTEM.GET(msAdr, w);
    keys := SYSTEM.VAL(SET, w DIV 1000000H MOD 8);
    x := w MOD 1000H; y := (w DIV 1000H) MOD 1000H;
    IF x >= MW THEN x := MW-1 END;
    IF y >= MH THEN y := MH-1 END
  END Mouse;

  PROCEDURE SetMouseLimits*(w, h: INTEGER);
  BEGIN MW := w; MH := h
  END SetMouseLimits;

  PROCEDURE Init*;
  BEGIN Up := FALSE; Shift := FALSE; Ctrl := FALSE; Recd := FALSE;
    KTabAdr := SYSTEM.ADR($
      00 00 00 00 00 1A 00 00  00 00 00 00 00 09 60 00
      00 00 00 00 00 71 31 00  00 00 7A 73 61 77 32 00
      00 63 78 64 65 34 33 00  00 20 76 66 74 72 35 00
      00 6E 62 68 67 79 36 00  00 00 6D 6A 75 37 38 00
      00 2C 6B 69 6F 30 39 00  00 2E 2F 6C 3B 70 2D 00
      00 00 27 00 5B 3D 00 00  00 00 0A 5D 00 5C 00 00
      00 00 00 00 00 00 08 00  00 00 00 00 00 00 00 00
      00 7F 00 00 00 00 1B 00  00 00 00 00 00 00 00 00
      00 00 00 00 00 00 00 00  00 00 00 00 00 09 7E 00
      00 00 00 00 00 51 21 00  00 00 5A 53 41 57 40 00
      00 43 58 44 45 24 23 00  00 20 56 46 54 52 25 00
      00 4E 42 48 47 59 5E 00  00 00 4D 4A 55 26 2A 00
      00 3C 4B 49 4F 29 28 00  00 3E 3F 4C 3A 50 5F 00
      00 00 22 00 7B 2B 00 00  00 00 0D 7D 00 7C 00 00
      00 00 00 00 00 00 08 00  00 00 00 00 00 00 00 00
      00 7F 00 00 00 00 1B 00  00 00 00 00 00 00 00 00$)
  END Init;

BEGIN Init
END Input.


(*----Attest-0.1.0------------------------------------------------------------------------*)
(* signed                                                                                 *)
(* 2018-12-03 08:16:28                                                                    *)
(*----------------------------------------------------------------------------------------*)
(* Xqx3slMIZw4WElmuQXBm3wL1SzgSMgPlAbnyJoAuRh+VyxD7KYLItYZAerewBePgrKyhnnniEb/QbxOH9zViXH *)
(* KTRCORzFsftqoIKGZbhxVNcTPUuCiE2K3EpuB6TX05ZBCioeMHmeVvc6naAWh0xaGbj2mva4hg8YgXgQfdHGe4 *)
(* 7/HkcSrQGx9sKHj3yrLO/BVsP1B7KAuRBGLzHr8KihjSpKPrQXpJUZzJzZd0LCqY4mN3S8Lv1skudrYRQTc/8n *)
(* MZjNAYCL/ComUoHsOaw1YE3zerLlTaV/ZF0fInPmf5Fm8MGI9/vxTigcxqiZQvmcRs4nObd2o4tuDlzL8exQ== *)
(*----------------------------------------------------------------------------------------*)
(* ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsrtAUhLbs/ELXgH3OJs0SKh7tSQE/gkPavHv4//tsLucTAN *)
(* C4mEjbjxKtFlZjji89GGvatnGu3DvAAz60VNEGBccezdn4rkcNpceKQe2KE2Kb13KM6VmrNl4Gj3+C278u0yKx *)
(* l07WpQCYJ1x6WU8Tnrs5oRSGvHzJVvkxbH7YfymnoXbDg2j8cWYX+zNR/aYvcX+6isZmqRDg+qZ1CK45UL0sO9 *)
(* GcSFyey3fGigzWGvBx9JujvsxL6aqX7yY+WtCbApeGLN4HYtrn4ueuKAQND5EYo0SEI2m+STt5eCdDBLFhG0jD *)
(* 5MO6T7o//Mg8qDeuiY5wpbcQdpVWmdWQQxMT chuck@kuracali.com                                *)
(*----------------------------------------------------------------------------------------*)
