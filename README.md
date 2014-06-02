Integraged Oberon
=================

This project may eventually integrate modern capabilities into a classic
operating system and language (Oberon.)

Meanwhile, Linker.Mod (in oberon-risc-ethz) allows OberonV5 (2013) for RISC
to compile its own boot track from source code to a binary file, making the
system almost self-hosted. An additional tool is required to install the boot
track.

Using Linker.Mod
----------------

* Retrieve, compile, and execute Peter De Wachter's Oberon Risc Emulator
  from https://github.com/pdewacht/oberon-risc-emu
* From within the emulator execute the `PCLink1.Run` command
* Retrieve Linker.Mod and from another command prompt on the host and then
  issue the command `./pcreceive.sh Linker.Mod`
* Add a trailing /s to the Compile command (e.g. `ORP.Compile ^/s`)
* Type and then highlight the text 'Linker.Mod'
* Execute the `ORP.Compile ^/s` command.
* Type and then execute the command `Linker.Link Modules`
* From the command prompt on the host issue the command 
  `./pcsend.sh Modules.bin`

You can apply the newly compiled boot track to an existing floppy image
using the dd command, for example:

`dd if=Modules.bin of=RISC-INSTALLTEST.img bs=512 seek=524292 conv=notrunc`

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
