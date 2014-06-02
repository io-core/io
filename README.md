Integrated Oberon
=================

This project may eventually integrate modern capabilities into Oberon, a classic
operating system and language.

Meanwhile Linker.Mod (in oberon-risc-ethz) allows OberonV5 (2013) for RISC
to compile its own boot track from source code to a binary file, making the
system almost self-hosted. An additional tool (such as 'dd' on the host) is 
required to install the boot
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

Portions Copyright © 2014 Charles Perkins

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



ETH Oberon
Copyright (c) 1990-2003, Computer Systems Institute, ETH Zurich
All rights reserved.

Redistribution and use in source and binary forms, with or
without modification, are permitted provided that the following
conditions are met:

o Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

o Redistributions in binary form must reproduce the above
  copyright notice, this list of conditions and the following
  disclaimer in the documentation and/or other materials
  provided with the distribution.

o Neither the name of the ETH Zurich nor the names of its
  contributors may be used to endorse or promote products
  derived from this software without specific prior written
  permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE ETH OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.
