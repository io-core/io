//
// Copyright © 2014 Peter De Wachter, 2017 Charles Perkins
//
// Permission to use, copy, modify, and/or distribute this software for any purpose with
// or without fee is hereby granted, provided that the above copyright notice and this
// permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO
// THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT
// SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR
// ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
// CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
// OR PERFORMANCE OF THIS SOFTWARE.
//



package main

import (
        "./frfs"
        "./cdisp"
        "./odisp"
	"./risc5"
	"./board"

	"fmt"
//	"time"
	"flag"
	"context"
	"os/signal"
	"os"
	"os/exec"
//	"io/ioutil"
//	"strings"
//	"strconv"
//	"github.com/davecheney/profile"
)




func grabControlC(mb *board.BOARD){
	if mb.FrameDevice == "console" {

	  ctx := context.Background()
	  // trap Ctrl+C and call cancel on the context
	  ctx, cancel := context.WithCancel(ctx)
	  fsc := make(chan os.Signal, 1)
	  signal.Notify(fsc, os.Interrupt)
	  defer func() {
		signal.Stop(fsc)
		cancel()
	  }()

	  go func() {
		select {
		case <-fsc:
	          cmd := exec.Command("stty", "sane")
	          cmd.Stdin = os.Stdin
	          _, _ = cmd.Output()
		  os.Exit(0)
		case <-ctx.Done():
		}
		cancel()
	  }()

          cmd := exec.Command("stty", "-echo")
          cmd.Stdin = os.Stdin
           _, _ = cmd.Output()
	}
}

var vChan chan [2]uint32

func main() {
//        defer profile.Start(profile.CPUProfile).Stop()

//        risc.halt = false
//	risc.pause = true
		
        imagePtr := flag.String("i", "RISC.img", "Disk image to boot")
        devicePtr := flag.String("d", "console", "Device to render to, e.g. X or console")
        mountpoint := flag.String("m", "/mnt/risc", "Mount Point for fuse filesystem")
        corecount := flag.Int("c", 5, "Number of cores")
        verbosity := flag.Int("v", 5, "verbosity level")
	
	flag.Parse()

	var mb *board.BOARD
	mb = new(board.BOARD)
	var cores []risc5.CORE
	cores = make([]risc5.CORE,*corecount)
	mb.DiskImage=*imagePtr
        mb.FrameDevice=*devicePtr
	verbose := false
	if *verbosity > 0 { verbose = true }
	

//        risc.diskImage=*imagePtr
//	risc.frameDevice=*devicePtr

	grabControlC(mb)

        vChan = make(chan [2]uint32 )
	readyChan := make(chan [2]uint32 )

	mb.Opendisk()	
        frfs.ServeRFS( mountpoint, mb.Disk.File, mb.Disk.Offset )

	go func(){
	
		rc := <- readyChan
		fmt.Println("video x",rc[0],"y",rc[1])
		mb.Reset( uint32(rc[0]), uint32(rc[1]) , vChan, verbose )
		for i:=0;i<*corecount;i++{ cores[i].Reset(i,verbose) }
		
		step:=0
		for {
	            for i:=0;i<*corecount;i++{ cores[i].Step(mb,verbose) }
	    	    step++
	        }
		os.Exit(0)
	}()

        if mb.FrameDevice == "console" {
	  cdisp.Initfb( vChan, &mb.Mouse, &mb.Key_buf, &mb.Key_cnt, &mb.Fbw, &mb.Fbh, verbose, readyChan )
	}else if mb.FrameDevice == "opengl" {
	  odisp.Initfb( vChan, &mb.Mouse, &mb.Key_buf, &mb.Key_cnt, &mb.Fbw, &mb.Fbh, verbose, readyChan )
	}
	



}
