Integraged Oberon
=================

This project may eventually integrate modern capabilities into Oberon, a classic
operating system and language.

Meanwhile Linker.Mod (in oberon-risc-ethz) allows OberonV5 (2013) for RISC
to compile its own boot track from source code to a binary file, making the
system almost self-hosted. An additional tool is required to install the boot
track.

Using Linker.Mod
----------------

* Retrieve and compile Peter De Wachter's Oberon Risc Emulator
  (https://github.com/pdewacht/oberon-risc-emu)
* Retrieve a disk image from http://projectoberon.com (in S3RISCinstall.zip)
* Run the emulator: ./risc RISC.img
* From within the emulator execute the `PCLink1.Run` command
* Retrieve Linker.Mod and upload it (`./pcreceive.sh Linker.Mod` on the host)
* Obtain FileDir.Mod, Files.Mod, Kernel.Mod, and Modules.Mod and upload those as well.
* In the RISC emulator add a trailing /s to the Compile command 
  (e.g. `ORP.Compile ^/s`)
* Highlight '*.Mod' in the RISC emulator and execute the `System.Directory ^` command.
* Highlight `Tools.Mod` and then execute the `ORP.Compile ^/s` command.
* Execute the `Tools.Inspect 0` command. Observe that the last number of line E0 is `00000000`
* Highlight `FileDir.Mod` and then execute the `ORP.Compile ^/s` command.
* Do the same for `Files.Mod`, `Kernel.Mod`, and `Modules.Mod`.
* Type and then highlight the text 'Linker.Mod'
* Execute the `ORP.Compile ^/s` command.
* Type and then execute the command `Linker.Link Modules`
* From the command prompt on the host issue the command 
  `./pcsend.sh Modules.bin`

You can apply the newly compiled boot track to an existing floppy image
using the dd command, for example:

* `cp RISC.img RISC-INSTALLTEST.img`
* `dd if=Modules.bin of=RISC-INSTALLTEST.img bs=512 seek=524292 conv=notrunc`

You should then be able to run the emulator using the modified disk image and when you issue
the `Tools.Inspect 0` command you should observe `12345678` on the last line.

Copyright
---------

Copyright © 2014 Charles Perkins

Permission to use, copy, modify, and/or distribute this software for
any purpose with or without fee is hereby granted, provided that the
above copyright notice and this permission notice appear in all
copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
