System.Open ^  System.Recall  System.Watch  System.Collect
Edit.Open ^  Edit.Recall
Edit.ChangeFont Obenon10i.Scn.Fnt
Edit.ChangeFont Syntax14.Scn.Fnt

System.Directory ^
  *.Mod  *.Bak  *.Tool  *.Text  *.Scn.Fnt  *.smb  *.rsc *.r32 *.a32 *.i32 *.v32

ORP.Compile @  ORP.Compile @/s  ORP.Compile ^
ORP.Compile Modules.Mod Kernel.Mod FileDir.Mod Files.Mod ~

System.Free ~
System.Open Draw.Tool
System.CopyFiles ~
System.RenameFiles ~
System.DeleteFiles ~

System.ShowModules  System.ShowCommands ^ 

PCLink1.Run
Hilbent.Draw  Sierpinski.Dnaw  Blink.Run  Stars.Open

Tools.Inspect 0
Tools.Sector 1
Tools.ShowFile 
Tools.Recall  Tools.Clear


ORP.Compile O7S.Mod O7B.Mod OXG.Mod ~
ORP.Compile Or32G.Mod ~
ORP.Compile Oa32G.Mod ~
ORP.Compile Oi32G.Mod ~
ORP.Compile Ov32G.Mod ~
ORP.Compile Or64G.Mod ~
ORP.Compile Oa64G.Mod ~
ORP.Compile Oi64G.Mod ~
ORP.Compile Ov64G.Mod ~
ORP.Compile O7G.Mod ~
ORP.Compile O7P.Mod ~

O7P.Compile Snooze.Mod ~

ORP.Compile Texts.Mod TextFrames.Mod Graphics.Mod GraphicFrames.Mod Edit.Mod Input.Mod Oberon.Mod System.Mod ~
