Integrated Oberon
=================

<img src="https://github.com/charlesap/io/blob/master/cowhead.png">
<a href="https://travis-ci.org/io-core/io">Travis CI Status for io-core/io</a> <img src="https://travis-ci.org/io-core/io.svg?branch=master">

For more information go to the <a href="https://github.com/io-core/io/wiki">io project wiki</a>

This project may eventually integrate modern capabilities into Oberon, a classic
operating system and language.

To run the risc v5 emulator (REM) you can download the binary for your platform or you can compile from source.

# Emulated - Binary
* Download the <a href="https://github.com/io-core/io/raw/master/rem/rem.amd64">Linux REM binary</a>, <a href="https://github.com/io-core/io/raw/master/rem/rem.darwin">Mac REM binary</a>, or Windows REM binary
* Make the binary exeutable (e.g. chmod 755 rem.amd64 or chmod 755 rem.darwin)
* Download the <a href="https://github.com/io-core/io/raw/master/rem/Oberon-2016-08-02.dsk">RISC os disc image</a>
* Download the <a href="https://github.com/io-core/io/raw/master/rem/risc-boot.inc">RISC os firmware file</a>
* run the emulator -- ./rem.amd64 -c 1 -v 0 -i Oberon-2016-08-02.dsk -d opengl -m - -g 1024x768x1
# Emulated - From Source
* install go
* go get the risc emulator (rem) project dependencies

- go get github.com/go-gl/gl/v3.2-core/gl
- go get github.com/go-gl/glfw/v3.2/glfw
- go get github.com/go-gl/mathgl/mgl32
- go get github.com/blackspace/gofb/framebuffer
- go get golang.org/x/net/context
- go get bazil.org/fuse
- go get bazil.org/fuse/fs
- go get bazil.org/fuse/fuseutil


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

