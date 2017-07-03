//
// Copyright © 2017 Charles Perkins
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

package xdisp

import (
	"unsafe"
	"time"
	"log"
	"github.com/fogleman/gg"
//        "os"
//        "fmt"
	"github.com/veandco/go-sdl2/sdl"	



)

const XWidth=	   1280+256
const XHeight=	   768


type mmsg struct {
        a byte
        b int16
        c int16
}

type kmsg struct {
        a byte
}

var dc *gg.Context
var window *sdl.Window
var xi *sdl.Surface
var xt *sdl.Texture
var xr *sdl.Renderer
var pixels []uint32
var texture *sdl.Texture
var xfbinit bool = false


func Initfb(vChan chan [2]uint32, mouse *uint32, key_buf *[16]byte, key_cnt *uint32 ) (uint32, uint32){

        var fbw, fbh uint32


        mChan := make(chan mmsg)
        kChan := make(chan kmsg)

                fbw=uint32(XWidth)
                fbh=uint32(XHeight)-1


	        go func() {

		   var event sdl.Event
	             kc := []byte      {    0,   0,   0,   0,0x1C,0x32,0x21,0x23,0x24,0x2B,
		     	   	       	 0x34,0x33,0x43,0x3B,0x42,0x4B,0x3A,0x31,0x44,0x4D, 
		     	   	       	 0x15,0x2D,0x1B,0x2C,0x3C,0x2A,0x1D,0x22,0x35,0x1A, 
		     	   	       	 0x16,0x1E,0x26,0x25,0x2E,0x36,0x3D,0x3E,0x46,0x45, 
		     	   	       	 0x5A,0x76,0x66,0x0D,0x29,0x4E,0x55,0x54,0x5B,0x5D, 
		     	   	       	 0x5D,0x4C,0x52,0x0E,0x41,0x49,0x4A,0x05,0x06,0x04,
		     	   	       	 0x14,0x12,0x11,0x1F,0x14,0x59,0x11,0x27,   0,   0 }
		   var running bool
		   var mbl,mbm,mbr uint8
		   running = true
		   for running {
		       for event = sdl.PollEvent(); event != nil; event = sdl.PollEvent() {
		       	   switch t := event.(type) {
			   case *sdl.QuitEvent:
				running = false
	//			risc.halt = true

			   case *sdl.MouseMotionEvent: 
				mChan <- mmsg{ 8  | (mbm << 2) | (mbr << 1) | mbl,int16(t.X),int16(int32(fbh)-t.Y)}
			   case *sdl.MouseButtonEvent: 
				switch t.Button {
				case 1:
				     mbl = t.State
				case 2:
				     mbm = t.State
				case 3:
				     mbr = t.State
				}
				mChan <- mmsg{ 8 | (mbm << 2) | (mbr << 1) | mbl ,int16(t.X),int16(int32(fbh)-t.Y)}
			    
			   case *sdl.KeyDownEvent:
			   	k:= t.Keysym.Scancode
				if k > 223 { k = (k - 224) + 60 }
			   	if k < 68 {
				  kChan <- kmsg{ kc[k] }
			   	}
			   case *sdl.KeyUpEvent:
			   	k:= t.Keysym.Scancode
				if k > 223 { k = (k - 224) + 60 }
			   	if k < 68 { 
			   	  kChan <- kmsg{ 0xF0 }
				  kChan <- kmsg{ kc[k] }
				}

			}
		   }
		}
	        }()
        go func() {

          for {
            m := <- mChan
            mmf:=m.a & 8
	    var mx, my int32
            if mmf != 8 {
              if m.b > 3 || m.b < -3 {
                 m.b = m.b*2
              }
              mx = int32(*mouse & 0x00000FFF )+int32(m.b)
              if m.c > 3 || m.b < -3 {
                 m.c = m.c*2
              } 
              my = int32((*mouse & 0x00FFF000) >> 12)+int32(m.c)
           }else{
              mx = int32(m.b)
              my = int32(m.c)
	    }
            mbl := m.a & 1
            mbm :=  (m.a & 4 ) >> 2
            mbr :=  (m.a & 2 ) >> 1
            *mouse=uint32(mbr)<<24|uint32(mbm)<<25|uint32(mbl)<<26| (uint32(my)<<12 & 0x00FFF000) | (uint32(mx) & 0x00000FFF)
          }
        }()
        go func() {

          for {
            m := <- kChan
            key_buf[*key_cnt]=m.a
            *key_cnt++
          }
        }()

        fbchg:=false
        go func() {

               sdl.Init(sdl.INIT_EVERYTHING)
	       window, err := sdl.CreateWindow("test", sdl.WINDOWPOS_UNDEFINED,
               sdl.WINDOWPOS_UNDEFINED, XWidth, XHeight, sdl.WINDOW_SHOWN)
    	       if err != nil {
                  log.Fatal(err)
    	       }
//    defer window.Destroy()
      	       xr, err = sdl.CreateRenderer(window, -1, 0)
    	       if err != nil {
                 log.Fatal(err)
    	       }
//    defer renderer.Destroy()
      	       texture, err = xr.CreateTexture(sdl.PIXELFORMAT_ARGB8888,
               sdl.TEXTUREACCESS_STATIC, XWidth, XHeight)
    	       if err != nil {
                 log.Fatal(err)
    	       }
//    defer texture.Destroy()
      	       pixels = make([]uint32, XWidth*XHeight)
	       xfbinit = true
		sdl.ShowCursor(sdl.DISABLE)
          
          for {
                v := <- vChan 
	        address:=v[0]
	        value:=v[1]
    	        for pi:=0;pi<32;pi++{
			pxcx:=uint32(0x00FFFFFF)
			if value & (1 << uint32(pi) ) != 0 { 
			    pxcx = uint32(0)
			}
	
			fbo:=((address)-(0x000E7F00))/4        
        		fby:=fbo/(fbw/32)
			fbx:=((fbo*32)%fbw)+uint32(pi)
        		if int(fby) < int(fbh) && int(fbx) < int(fbw) {
          	   	    
          	   	   
          	  		pixels[((fbh-fby)*XWidth)+fbx] = pxcx
				fbchg = true 
	  	   	    
        		}
	        }
	  }
	}()
        go func() {

           
	      for {
			if xfbinit {
			   if fbchg {
			          fbchg = false
        	  		  texture.Update(nil, unsafe.Pointer(&pixels[0]), XWidth*4)
        	  		  window.UpdateSurface()

        	  //		  xr.Clear()
        	  		  xr.Copy(texture, nil, nil)
        	  		  xr.Present()
		           }
		        }
				  time.Sleep(50000)
		        
	      }
	   
        }()

	go func() {
	  
	  
             for {
	        if fbchg {
        	  fbchg = false
		  xr.Present()
      		}
		time.Sleep(10 * time.Millisecond)
	      }
	  


	}()

	return fbw, fbh       
}

