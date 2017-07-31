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

package cdisp

import (
	"os"
	"fmt"
	"gofb/framebuffer"


)



type mmsg struct {
	a byte
	b int16
	c int16
}

type kmsg struct {
        a byte
}

var fb *framebuffer.Framebuffer

func Initfb( vChan chan [2]uint32, mouse *uint32, key_buf *[16]byte, key_cnt, fbw, fbh *uint32 ) {

//	var fbchg bool
        mChan := make(chan mmsg)
        kChan := make(chan kmsg)
       

                fb = framebuffer.NewFramebuffer()

                fb.Init()

                const S = 1024
                *fbw=uint32(fb.Xres)
                *fbh=uint32(fb.Yres)-1
//                risc.fbw=1024
//                risc.fbh=768

	fmt.Println("Opening Mouse")
                fm, err := os.Open("/dev/input/mice")
                if err != nil { fmt.Println(err) }
                go func() {
                    for {
                        b1 := make([]byte, 3)
                        _, err := fm.Read(b1)
                      if err != nil {
                        fmt.Println(err)
                        mChan <- mmsg{0,0,0}
                        return
                      }
                      mChan <- mmsg{ b1[0] & 247 ,int16(int8(b1[1])),int16(int8(b1[2]))}
                    }
                }()

        fmt.Println("Opening Keyboard")
                fk, err := os.Open("/dev/input/by-path/platform-i8042-serio-0-event-kbd")
                go func() {
                    var kstate [256]byte
                     kc := []byte      {   0,0x76,0x16,0x1e,0x26,0x25,0x2e,0x36,0x3d,0x3e,
                                        0x46,0x45,0x4e,0x55,0x66,0x0d,0x15,0x1d,0x24,0x2d,
                                        0x2c,0x35,0x3c,0x43,0x44,0x4D,0x54,0x5b,0x5a,0x14,
                                        0x1c,0x1b,0x23,0x2b,0x34,0x33,0x3b,0x42,0x4b,0x4c,
                                        0x52,0x0e,0x12,0x5d,0x1a,0x22,0x21,0x2a,0x32,0x31,
                                        0x3a,0x41,0x49,0x4a,0x59,  55,0x11,0x29,  58,  59,
                                        60,61,62,63,64,65,66,67,68,69,
                                        70,71,72,73,74,75,76,77,78,79,
                                        80,81,82,83,84,85,86,87,88,89 }
                    for {
                        b2 := make([]byte, 24)
                        _, err := fk.Read(b2)
                      if err != nil {
                        fmt.Println(err)
                        kChan <- kmsg{0}
                        return
                      }
                      if b2[16]==4 && b2[18]==4 && b2[20]<88 && kstate[b2[20]]!=1{
                        kstate[b2[20]]=1
                        kChan <- kmsg{kc[b2[20]]}
                      }else if b2[16]==1 && b2[20]==0 && b2[18]<88{
                        kstate[b2[18]]=0
                        kChan <- kmsg{ 0xF0 }
                        kChan <- kmsg{kc[b2[18]]}
                      }
                    }
                }()

        fmt.Println("Launching Mouse Handler")

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

        fmt.Println("Launching Keyboard Handler")

        go func() {

          for {
            m := <- kChan
            key_buf[*key_cnt]=m.a
            *key_cnt++
          }
        }()

     //   fbchg = false

        fmt.Println("Launching Graphics Update Handler")
    //    go func() {
          for {
                v := <- vChan
                address:=v[0]
                value:=v[1]
                for pi:=0;pi<32;pi++{
                        pxcr:=uint32(238)
                        pxcg:=uint32(223)
                        pxcb:=uint32(204)
 //                       pxcx:=uint32(0x00FFFFFF)
                        if value & (1 << uint32(pi) ) != 0 {
                            pxcr = uint32(0)
                            pxcg = uint32(0)
                            pxcb = uint32(0)
//                            pxcx = uint32(0)
                        }

                        fbo:=((address)-(0x000E7F00))/4
                        fby:=fbo/(*fbw/32)
                        fbx:=((fbo*32)%*fbw)+uint32(pi)
                        if int(fby) < int(*fbh) && int(fbx) < int(*fbw) {
                         
                                fb.SetPixel(int(fbx),int(*fbh-fby),pxcr,pxcg,pxcb,255)
                            
                        }
                }
          }
      //  }()



	//return fbw, fbh
}


