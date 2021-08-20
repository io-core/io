Integrated Oberon
=================
 
<img align="right" src="https://github.com/charlesap/io/blob/main/images/cowhead.png"> Integrated Oberon builds on the RISC Oberon reboot of the classic operating system and language.
<hr>

The system documentation is here: [https://io-core.github.com/io](https://io-core.github.io/) including what it is, how to get it, install it, use it, develop it, talk about it...

Latest trimmed disk [io.img](https://github.com/io-core/io/blob/main/images/io.img) for full machine emulators like [this one in c](https://github.com/pdewacht/oberon-risc-emu)

Latest trimmed disk [io-pv.img](https://github.com/io-core/io/blob/main/images/io-pv.img) for paravirualized emulators like [this one in Javascript](https://schierlm.github.io/OberonEmulator/)

Latest full disk [io-full.img.zip](https://github.com/io-core/io/blob/main/images/io-full.img.zip) for FPGAs implementing RISC5 like [this one with 32MB SDRAM](https://www.crowdsupply.com/radiona/ulx3s)


Go to the [Wiki](https://github.com/io-core/io/wiki) for more community content.

Fork this repo, make pull requests! Help integrate modern capabilities into Oberon, a classic
operating system and language.

tl;dr--

This repo uses submodules, to get the whole thing:
```
git clone --recursive https://github.com/io-core/io
```
After cloning the submodules may not be checked out to 'main' so after the above command you should:
```
cd io; bash makemain.sh
```

