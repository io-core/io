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
        "github.com/io-core/io/rem/frfs"
        "github.com/io-core/io/rem/cdisp"
        "github.com/io-core/io/rem/odisp"
	"github.com/io-core/io/rem/risc5"
	"github.com/io-core/io/rem/board"

	"fmt"
	"time"
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
var piChan chan [2]uint32

func main() {
//        defer profile.Start(profile.CPUProfile).Stop()

//        risc.halt = false
//	risc.pause = true
		
        imagePtr := flag.String("i", "RISC.img", "Disk image to boot")
        devicePtr := flag.String("d", "opengl", "Device to render to, e.g. 'opengl' (X) or 'console' or 'headless'")
        mountpoint := flag.String("f", "-", "Mount Point for fuse filesystem")
        memPtr := flag.Int("m", 0, "Megabytes of RAM, 0 for default of 1.5MB")
        corecount := flag.Int("c", 1, "Number of cores")
        verbosity := flag.Int("v", 0, "Verbosity level")
        geometry := flag.String("g", "1024x768x1m", "Geometry (<width>x<height>x<bpp>m|c)")
	haltPtr := flag.Bool("halt", false, "Begin in halt state")	
        hidpiPtr := flag.Bool("hidpi", false, "high dpi")

	flag.Parse()

	mlim:=*memPtr
	if mlim == 0 {
	  mlim = 0x00180000/4         // 1.5MB
	}else{
          mlim = 0x00100000 * mlim / 4
	}

	var mb *board.BOARD
	mb = new(board.BOARD)
        mb.RAM = make([]uint32,mlim)
        mb.Mlim = uint32(mlim)
	var cores []risc5.CORE
	cores = make([]risc5.CORE,*corecount)
	mb.DiskImage=*imagePtr
        mb.FrameDevice=*devicePtr
	verbose := false
	if *verbosity > 0 { verbose = true }

	if 1==2 {fmt.Println(*memPtr)}	

//        risc.diskImage=*imagePtr
//	risc.frameDevice=*devicePtr

	grabControlC(mb)

        vChan = make(chan [2]uint32 )
        piChan = make(chan [2]uint32 )
	readyChan := make(chan [2]uint32 )

	mb.Opendisk()	
        frfs.ServeRFS( mountpoint, mb.Disk.File, mb.Disk.Offset )

	go func(){
	
		rc := <- readyChan
		fmt.Println("video x",rc[0],"y",rc[1])
		mb.Reset( uint32(rc[0]), uint32(rc[1]), vChan, piChan, verbose )
		for i:=0;i<*corecount;i++{ cores[i].Reset(i,verbose) }
		
		step:=0
		for {
			if *haltPtr {
				time.Sleep(100 * time.Millisecond)
			}else{
				mb.Tick++
	            		for i:=0;i<*corecount;i++{ cores[i].Step(mb,verbose) }
	    	    		step++
			}
	        }
		os.Exit(0)
	}()


        if mb.FrameDevice == "console" {
	  cdisp.Initfb( vChan, &mb.Mouse, &mb.Key_buf, &mb.Key_cnt, &mb.Fbw, &mb.Fbh, verbose, readyChan, *geometry, &mb.DisplayStart, *hidpiPtr )
	}else if mb.FrameDevice == "opengl" {
	  odisp.Initfb( vChan, &mb.Mouse, &mb.Key_buf, &mb.Key_cnt, &mb.Fbw, &mb.Fbh, verbose, readyChan, *geometry, &mb.DisplayStart, *hidpiPtr )
        }else if mb.FrameDevice == "headless" {
          readyChan <- [2]uint32{1024,768}
          for {}
	}
	



}

