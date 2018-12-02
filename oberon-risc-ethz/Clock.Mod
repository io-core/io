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

(*----Attest-0.1.0------------------------------------------------------------------------*)
(* signed                                                                                 *)
(* 2018-12-02 08:40:21                                                                    *)
(*----------------------------------------------------------------------------------------*)
(* C/ZDwxz6f9bzTcmSrV0/8zzV6iDh/ztOgs38WZpL/+zTpDwhLfobD0nnQQiwJl61fByV5uQPxNg35c4WYy6xcJ *)
(* pDJK6XsmnUKHSQnL/Hzl9Or53D8YJL0FjR51BIxeZgwqF2le2GWzdR5snBK8w8UH+8f9XhXR45mZskl1hCQDXE *)
(* pMZSAKJoWz7o7dRUcgOtkiJzkEfD6ukG0SwK4fip/TvLyDcRrndA4crGLFrIlPkk3OKEUJxlp+tYt4NPsB/SvC *)
(* ltbM2jqQ2PlAgD+NGO5mk3bFE4x8MxCuAXfTSc7rcHScTfJiq5kGL396IA4BlMdi0NwYvaBDfE4XnQ40SMcA== *)
(*----------------------------------------------------------------------------------------*)
(* ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsrtAUhLbs/ELXgH3OJs0SKh7tSQE/gkPavHv4//tsLucTAN *)
(* C4mEjbjxKtFlZjji89GGvatnGu3DvAAz60VNEGBccezdn4rkcNpceKQe2KE2Kb13KM6VmrNl4Gj3+C278u0yKx *)
(* l07WpQCYJ1x6WU8Tnrs5oRSGvHzJVvkxbH7YfymnoXbDg2j8cWYX+zNR/aYvcX+6isZmqRDg+qZ1CK45UL0sO9 *)
(* GcSFyey3fGigzWGvBx9JujvsxL6aqX7yY+WtCbApeGLN4HYtrn4ueuKAQND5EYo0SEI2m+STt5eCdDBLFhG0jD *)
(* 5MO6T7o//Mg8qDeuiY5wpbcQdpVWmdWQQxMT chuck@kuracali.com                                *)
(*----------------------------------------------------------------------------------------*)
