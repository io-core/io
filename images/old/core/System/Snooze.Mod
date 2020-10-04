MODULE Snooze;   (*CP 11.2018*)
  IMPORT SYSTEM, Oberon;
  VAR z: INTEGER;
    T: Oberon.Task;
  
  PROCEDURE Yes*;
  BEGIN Oberon.Install(T)
  END Yes;

  PROCEDURE No*;
  BEGIN Oberon.Remove(T)
  END No;

  PROCEDURE Snoozer;
  BEGIN z := 1-z; LED(z);
     SYSTEM.PUT(-64,1000)
  END Snoozer;

BEGIN z := 0; T := Oberon.NewTask(Snoozer, 500)
END Snooze.

(*----Attest-0.1.0------------------------------------------------------------------------*)
(* signed                                                                                 *)
(* 2018-12-02 09:30:08                                                                    *)
(*----------------------------------------------------------------------------------------*)
(* h+i9uOp+6s/8DPALfW7n9OGhQvK0Np4djm7dgy3AFO9uF+CsLRlzXHaNdA9RrdIHec1+lvcpiEO+xo1n2Nqayj *)
(* H9G3akBp4DQL+RkPxXDyD05oRHlptbe715RqV8DNjsHK9xDpguZbrPnsQ2tEeZA36Nk2rNDMmCmibk2KmUZqhQ *)
(* FzOVDp8JyytETWP9bQrVImrTT0Sb9olw27pIv3XgkbKHt7ZYa3+bfrMx2NtlaN1q5lpOAhjys0PitqtKtPdBe5 *)
(* UjLVqO3UqEQL0I+HxsI0JIOdX0CdV6eRGEpsLo/ResVaI7gGYD0z5hUOePxtCQUPuIYtJ8MrKXBL/20sYlhw== *)
(*----------------------------------------------------------------------------------------*)
(* ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsrtAUhLbs/ELXgH3OJs0SKh7tSQE/gkPavHv4//tsLucTAN *)
(* C4mEjbjxKtFlZjji89GGvatnGu3DvAAz60VNEGBccezdn4rkcNpceKQe2KE2Kb13KM6VmrNl4Gj3+C278u0yKx *)
(* l07WpQCYJ1x6WU8Tnrs5oRSGvHzJVvkxbH7YfymnoXbDg2j8cWYX+zNR/aYvcX+6isZmqRDg+qZ1CK45UL0sO9 *)
(* GcSFyey3fGigzWGvBx9JujvsxL6aqX7yY+WtCbApeGLN4HYtrn4ueuKAQND5EYo0SEI2m+STt5eCdDBLFhG0jD *)
(* 5MO6T7o//Mg8qDeuiY5wpbcQdpVWmdWQQxMT chuck@kuracali.com                                *)
(*----------------------------------------------------------------------------------------*)
