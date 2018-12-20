cp ../core/font8x16.pcf mnt/
cp ../core/ol*.pcf mnt/
cp ../core/XF.Tool mnt/

#inner core
cat ../core/Kernel.Mod > mnt/Kernel.Mod
cat ../core/FileDir.Mod > mnt/FileDir.Mod
cat ../core/Files.Mod > mnt/Files.Mod
cat ../core/Modules.Mod > mnt/Modules.Mod

#outer core
cat ../core/Input.Mod > mnt/Input.Mod
cat ../core/Display.Mod > mnt/Display.Mod
cat ../core/Viewers.Mod > mnt/Viewers.Mod
cat ../core/Oberon.Mod > mnt/Oberon.Mod
cat ../core/MenuViewers.Mod > mnt/MenuViewers.Mod
cat ../core/Fonts.Mod > mnt/Fonts.Mod
cat ../core/Texts.Mod > mnt/Texts.Mod
cat ../core/Graphics.Mod > mnt/Graphics.Mod
cat ../core/TextFrames.Mod > mnt/TextFrames.Mod
cat ../core/GraphicFrames.Mod > mnt/GraphicFrames.Mod 

#independent utilities
cat ../core/Edit.Mod > mnt/Edit.Mod 
cat ../core/ORS.Mod > mnt/ORSLF.Mod # not yet... need original line endings 
cat ../core/ORP.Mod > mnt/ORP.Mod 
cat ../core/ORG.Mod > mnt/ORG.Mod
cat ../core/ORC.Mod > mnt/ORC.Mod
cat ../core/ORB.Mod > mnt/ORB.Mod
cat ../core/Tools.Mod > mnt/Tools.Mod
cat ../core/ORTool.Mod > mnt/ORTool.Mod

