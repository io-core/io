System.Open ^  System.Recall  System.Watch  System.CollectEdit.Open ^  Edit.RecallEdit.ChangeFont font8x16.pcf
Edit.ChangeFont font12x24.pcf
Edit.ChangeFont spleen16x32.pcf
Edit.ChangeFont olcursor.pcf
Edit.ChangeFont olgl10.pcfEdit.ChangeFont Syntax14.Scn.Fnt

ORP.Compile Fonts.Mod/s Texts.Mod/s ~
ORP.Compile Input.Mod/s Display.Mod/s Viewers.Mod/s~
ORP.Compile Oberon.Mod/s MenuViewers.Mod/s Graphics.Mod/s~
ORP.Compile GraphicFrames.Mod/s TextFrames.Mod/s System.Mod/s ~
ORP.Compile ORS.Mod/s ORB.Mod/s ORG.Mod/s ORP.Mod/s ~
ORP.Compile Edit.Mod/s Tools.Mod/s ORTool.Mod/s ~

System.Directory ^  *.Mod  *.Bak  *.Tool  *.Text  *.Scn.Fnt  *.smb  *.rsc *.txt *.bin

ORP.Compile @  ORP.Compile @/s  ORP.Compile ^
ORP.Compile Modules.Mod Kernel.Mod FileDir.Mod Files.Mod ~

System.Free ~
System.Open Draw.Tool
System.CopyFiles ~
System.RenameFiles ~
System.DeleteFiles ~

System.ShowModules  System.ShowCommands ^ 

PCLink1.Run
Hilbert.Draw  Sierpinski.Draw  Blink.Run  Stars.Open

Tools.Inspect 0
Tools.Sector 1
Tools.ShowFile sequence.bin  Tools.Recall  Tools.Clear
      
Fonts.Mod