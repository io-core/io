Integrated Oberon
=================

<img src="https://github.com/charlesap/io/blob/master/cowhead.png">

For more information go to the <a href="https://github.com/io-core/io/wiki">io project wiki</a>

This project may eventually integrate modern capabilities into Oberon, a classic
operating system and language.

To run the risc v5 emulator (REM) you can download the binary for your platform or you can compile from source.

# Emulated - Binary
* Download the Linux REM binary, Mac REM binary, or Windows REM binary
* Download the RISC os disc image
* Download the RISC os firmware file
* run the emulator -- ./rem -c 1 -v 0 -i Oberon-2016-08-02.dsk -d opengl -m -
# Emulated - From Source
* install go
* go get the risc emulator (rem) project dependencies
* git clone https://github.com/io-core/io.git
* go build rem.go
* run the emulator -- ./rem -c 1 -v 0 -i Oberon-2016-08-02.dsk -d opengl -m -



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

