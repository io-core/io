(* begin-module-short-description
Tests the Unit Test module
end-module-short-description *)

(* begin-module-use-description
Module TestTest handles:

* Nothing yet. Testing the tests eventually.

end-module-use-description *)
MODULE TestTest; 
  IMPORT Test;

  CONST 

  TYPE 

  VAR 

  (* begin-procedure-description
---
**TestBuild** performs a build test of a module.
  end-procedure-description *)
  PROCEDURE TestBuild*;
  BEGIN 
  END TestBuild;

  (* begin-procedure-description
---
**TestLoad** performs a load test of a module.
  end-procedure-description *)
  PROCEDURE TestLoad*;
  BEGIN 
  END TestLoad;

  (* begin-procedure-description
---
**TestQuick** performs quick tests of a module's exported procedures.
  end-procedure-description *)
  PROCEDURE TestQuick*;
  BEGIN 
  END TestQuick;

  (* begin-procedure-description
---
**TestPerf** performs benchmark tests of a module's exported procedures.
  end-procedure-description *)
  PROCEDURE TestPerf*;
  BEGIN 
  END TestPerf;

  (* begin-procedure-description
---
**TestFuzz** performs fuzz tests of a module's exported procedures.
  end-procedure-description *)
  PROCEDURE TestFuzz*;
  BEGIN 
  END TestFuzz;

  (* begin-procedure-description
---
**TestExamples** verifies the output module's exported procedures on example uses.
  end-procedure-description *)
  PROCEDURE TestExamples*;
  BEGIN 
  END TestExamples;

  (* begin-procedure-description
---
**TestAll** performs all of a module's tests.
  end-procedure-description *)
  PROCEDURE TestAll*;
  BEGIN 
  END TestAll;

END TestTest.
