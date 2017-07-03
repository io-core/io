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
        "./xdisp"

	"fmt"
//	"time"
	"flag"
	"context"
	"os/signal"
	"os"
	"os/exec"
	"io/ioutil"
	"strings"
	"strconv"
	"github.com/davecheney/profile"
)

const TRACEMIN = 800000
const TRACEMAX = 800000

const MemSize=     0x00280000
const MemWords=    (MemSize / 4)
const ROMStart=    0xFFFFF800
const ROMWords=    512
//const XWidth=	   1280+256
//const XHeight=	   768
const XDepth=	   1
const DisplayStart=0x000E7F00
const IOStart=     0xFFFFFFC0

const pbit = 0x80000000
const qbit = 0x40000000
const ubit = 0x20000000
const vbit = 0x10000000


type RISC struct {
  PC uint32
  R [16]uint32
  H uint32
  Z, N, C, V, halt bool

  OPC uint32
  OR [16]uint32
  OH uint32
  OZ, ON, OC, OV bool

  icount uint32
  spi_selected uint32
  progress uint32
  current_tick uint32
  mouse uint32
  key_buf [16]byte
  key_cnt uint32
  fbw uint32
  fbh uint32
  fbchg bool
  diskImage string
  frameDevice string
}


const(
  MOV = iota
  LSL
  ASR
  ROR
  AND
  ANN
  IOR
  XOR
  ADD
  SUB
  MUL
  DIV
  FAD
  FSB
  FML
  FDV
)


const ( // DiskState
  diskCommand = iota
  diskRead
  diskWrite
  diskWriting
)

type Disk struct {
//  struct RISC_SPI spi;

  state uint32
  file *os.File
  offset uint32

  rx_buf [128]uint32
  rx_idx int

  tx_buf [128+2]uint32
  tx_cnt int
  tx_idx int
}

var risc RISC
var  RAM [MemWords]uint32
var  ROM [ROMWords]uint32
var disk Disk

func msgtrace(risc * RISC,s string){
    if (risc.icount<TRACEMAX && risc.icount>TRACEMIN){
	fmt.Printf("%s",s)
    }
}

func rtrace(risc * RISC, ir uint32){
//  if (risc != nil){
    if (risc.icount<TRACEMAX && risc.icount>TRACEMIN){
      risc.OPC=risc.PC;
      for i:=0; i<16; i++ {
         if  risc.OR[i] != risc.R[i] {
           fmt.Printf( "  R[%2d]<%08x ", i, risc.R[i]);
         }
         risc.OR[i]=risc.R[i];
      }
      risc.OH=risc.H;
      risc.OZ=risc.Z;
      risc.ON=risc.N;
      risc.OC=risc.C;
      risc.OV=risc.V;
      op := (ir & 0x000F0000) >> 16
      opcode:="???"
      if ir & pbit == 0 {
        switch op {
        case MOV:
            opcode="MOV"
        case LSL:
            opcode="LSL"
        case ASR:
            opcode="ASR"
        case ROR:
            opcode="ROR"
        case AND:
            opcode="AND"
        case ANN:
            opcode="ANN"
        case IOR:
            opcode="IOR"
        case XOR:
            opcode="XOR"
        case ADD:
            opcode="ADD"
        case SUB:
            opcode="SUB"
        case MUL:
            opcode="MUL"
        case DIV:
            opcode="DIV"
        case FAD:
            opcode="FAD"
        case FSB:
            opcode="FSB"
        case FML:
            opcode="FML"
        case FDV:
            opcode="FDV"
        }
      } else if ((ir & qbit) == 0) {
        if ((ir & ubit) == 0) {
          if (ir & vbit) == 0 {
            opcode="LDW" 
          }else{
            opcode="LDB"
          } 
         }else{
          if (ir & vbit) == 0 {
            opcode="STW"
          }else{
            opcode="STB"
          }
        }
      }else{
            opcode="BR "
      }
      fmt.Printf("\n%6d %08x %s",risc.icount, risc.PC -1, opcode );
    }
//  }
}


func reset() {
        risc.icount=0
	risc.PC=ROMStart/4
	content, err := ioutil.ReadFile("risc-boot.inc")
	if err != nil {
	    fmt.Printf("Error reading boot rom.")
	}
	lines := strings.Split(string(content), "\n")
        ri:=0
        for _,l := range lines{
	   e := strings.Split(l, ",")
           for _,n := range e{
             if len(n)>0{
                r,_:=strconv.ParseUint( strings.Replace(strings.TrimSpace(n), "0x", "", -1), 16, 32)
		ROM[ri]=uint32(r)
		ri++
	     }
           }
        }
//	f,err:=os.OpenFile("Oberon-2016-08-02.dsk", os.O_RDWR, 0644)
        f,err:=os.OpenFile(risc.diskImage, os.O_RDWR, 0644)
        if err != nil {
          panic(err)
        }else{
	  disk.file=f
	}
	disk.state = diskCommand
	disk.offset = 0x80002
//        disk.offset = 0
	RAM[DisplayStart/4] = 0x53697A66  // magic value 'SIZE'+1
	RAM[DisplayStart/4+1] = risc.fbw
	RAM[DisplayStart/4+2] = risc.fbh
//	risc.fbw=1600
//	risc.fbh=890
}


func fp_add(x, y uint32, u, v bool) uint32{
  xs := (x & 0x80000000) != 0
  var xe uint32
  var x0 int32
  if (!u) {
    xe = (x >> 23) & 0xFF
    xm := uint32(((x & 0x7FFFFF) << 1) | 0x1000000)
    if xs {
      x0 = int32(-xm )
    }else{
      x0 = int32( xm )
    }
  } else {
    xe = 150
    x0 = int32((x & 0x00FFFFFF) << 8 >> 7)
  }

  ys := ((y & 0x80000000) != 0)
  ye := uint32((y >> 23) & 0xFF)
  ym := uint32(((y & 0x7FFFFF) << 1))
  if (!u && !v) { ym = ym | 0x1000000 }
  var y0 int32
  if ys {
    y0 = int32( -ym )
  }else{
    y0 = int32( ym )
  }

  var e0 uint32
  var x3, y3 int32
  if (ye > xe) {
    shift := uint32(ye - xe)
    e0 = ye
    if shift > 31 {
      x3 = x0 >> 31 
    }else{
      x3 = x0 >> shift
    }
    y3 = y0
  } else {
    shift := uint32(xe - ye)
    e0 = xe
    x3 = x0
    if shift > 31 {
      y3 =  y0 >> 31 
    }else{
      y3 =  y0 >> shift
    }
  }

  var sum1,sum2,sum uint32
  sum1=0
  sum2=0
  if xs {  sum1 = sum1 | uint32(1 << 26) }
  if xs {  sum1 = sum1 | uint32(1 << 25) }
  sum1 = sum1 | uint32(x3 & 0x01FFFFFF)
  if ys {  sum2 = sum2 | uint32(1 << 26) }
  if ys {  sum2 = sum2 | uint32(1 << 25) }
  sum2 = sum2 | uint32(y3 & 0x01FFFFFF)
  sum = sum1+sum2

//  sum := uint32(((xs << 26) | (xs << 25) | (x3 & 0x01FFFFFF)) + ((ys << 26) | (ys << 25) | (y3 & 0x01FFFFFF)))

  var s uint32
  if (sum & (1 << 26)) != 0 {
    s = uint32(( -sum + 1) & 0x07FFFFFF)
  }else{
    s = uint32((  sum + 1) & 0x07FFFFFF)
  }
  e1 := uint32(e0 + 1)
  t3 := uint32(s >> 1)
  if ((s & 0x3FFFFFC) != 0) {
    for ((t3 & (1<<24)) == 0) {
      t3 <<= 1
      e1--
    }
  }else{
    t3 <<= 24
    e1 -= 24
  }

  xn := (x & 0x7FFFFFFF) == 0
  yn := (y & 0x7FFFFFFF) == 0

  if (v) {
    return uint32((sum << 5) >> 6)
  } else if (xn) {
    if (u || yn) {
      return 0 
    }else{
      return y
    }
  } else if (yn) {
    return x
  } else if ((t3 & 0x01FFFFFF) == 0 || (e1 & 0x100) != 0) {
    return 0
  } else {
    return ((sum & 0x04000000) << 5) | (e1 << 23) | ((t3 >> 1) & 0x7FFFFF);
  }
}

func fp_mul(x, y uint32) uint32 {
  sign := uint32((x ^ y) & 0x80000000)
  xe := uint32((x >> 23) & 0xFF)
  ye := uint32((y >> 23) & 0xFF)

  xm := uint32((x & 0x7FFFFF) | 0x800000)
  ym := uint32((y & 0x7FFFFF) | 0x800000)
  m := uint64(uint64(xm) * uint64(ym))

  e1 := (xe + ye) - 127
  var z0 uint32
  if ((m & (uint64(1) << 47)) != 0) {
    e1++;
    z0 = uint32(((m >> 23) + 1) & 0xFFFFFF)
  } else {
    z0 = uint32(((m >> 22) + 1) & 0xFFFFFF)
  }

  if (xe == 0 || ye == 0) {
    return 0
  } else if ((e1 & 0x100) == 0) {
    return sign | ((e1 & 0xFF) << 23) | (z0 >> 1)
  } else if ((e1 & 0x80) == 0) {
    return sign | (0xFF << 23) | (z0 >> 1)
  } else {
    return 0
  }
}

func fp_div( x, y uint32) uint32 {
  sign := (x ^ y) & 0x80000000
  xe := (x >> 23) & 0xFF
  ye := (y >> 23) & 0xFF

  xm := (x & 0x7FFFFF) | 0x800000
  ym := (y & 0x7FFFFF) | 0x800000
  q1 := uint32((uint64(xm) * (uint64(1) << 25) / uint64(ym)))

  e1 := (xe - ye) + 126
  var q2 uint32
  if ((q1 & (1 << 25)) != 0) {
    e1++
    q2 = (q1 >> 1) & 0xFFFFFF
  } else {
    q2 = q1 & 0xFFFFFF
  }
  q3 := q2 + 1

  if (xe == 0) {
    return 0
  } else if (ye == 0) {
    return sign | (0xFF << 23)
  } else if ((e1 & 0x100) == 0) {
    return sign | ((e1 & 0xFF) << 23) | (q3 >> 1)
  } else if ((e1 & 0x80) == 0) {
    return sign | (0xFF << 23) | (q2 >> 1)
  } else {
    return 0
  }
}

func idiv( x, y uint32, signed_div bool) (uint32, uint32) {
  sign := (x < 0) && signed_div
  var x0 uint32
  if sign {
    x0 = -x
  }else{
    x0 = x
  }
 

  RQ := uint64(x0)
  for S := 0; S < 31; S++ {
    w0 := uint32(RQ >> 31)
    w1 := w0 - y
    if (w1 < 0) {
      RQ = (uint64(w0) << 32) | ((RQ & 0x7FFFFFFF) << 1)
    } else {
      RQ = (uint64(w1) << 32) | ((RQ & 0x7FFFFFFF) << 1) | 1
    }
  }

  quot :=  uint32(RQ)
  rem :=  uint32(RQ >> 32) 
  if (sign) {
    quot = -quot
    if (rem!=0) {
      quot -= 1
      rem = y - rem
    }
  }
  return quot,rem
}

func set_register(reg uint32, value uint32) {
  risc.R[reg] = value
  risc.Z = value == 0
  risc.N = int32(value) < 0
}

func load_word(address uint32) uint32{
  if (address < MemSize) {
//    msgtrace(&risc, fmt.Sprintf(" %08x from MEMORY LOCATION %08x ",RAM[address/4],address/4))
    return RAM[address/4]
  } else {
    return load_io(address)
  }
}

func load_byte(address uint32) byte {
  var w uint32 = 0 
  if (address < MemSize) {
    w = RAM[address/4]
  } else { 
    w = load_io(address)
  }
  b:=byte(w >> (address % 4 * 8))

//  msgtrace(&risc, fmt.Sprintf(" %02x from MEMORY LOCATION %08x ",b,address/4))
  return b

}


func store_word(address, value uint32) {
  if (address < DisplayStart) {
//    msgtrace(&risc, fmt.Sprintf(" %08x to MEMORY LOCATION %08x ",value,address/4))
    RAM[address/4] = value
  } else if (address < MemSize) {
//    msgtrace(&risc, fmt.Sprintf(" %08x to VIDEO LOCATION %08x ",value,address/4))
    RAM[address/4] = value
    vChan <- [2]uint32{ address, value} 
  } else {
    store_io(address, value)
  }
}

func store_byte(address uint32, value uint8) {
  if (address < MemSize) {
//    if trace { fmt.Printf("MEMORY BYTE ") }
    w := uint32(load_word(address))
    shift := uint32((address & 3) * 8)
    w = w & (^ (0xFF << shift))
    w = w | uint32(value) << shift
    store_word(address, w)
  } else {
    if trace { fmt.Printf("IO BYTE ") }
    store_io( address, uint32(value))
  }
}

func spi_read_data( spi_selected uint32) uint32 {

  var result uint32 = 255
  if (spi_selected==1)&&(disk.tx_idx >= 0 && disk.tx_idx < disk.tx_cnt) {
    result = disk.tx_buf[disk.tx_idx];
  } 
  return result;  

}

func disk_run_command(){
//  fmt.Printf(" DISK-OPERATION ")
  cmd := disk.rx_buf[0]
  arg := (disk.rx_buf[1] << 24) | (disk.rx_buf[2] << 16) | (disk.rx_buf[3] << 8) | disk.rx_buf[4]

  switch (cmd) {
    case 81: 
      disk.state = diskRead
      disk.tx_buf[0] = 0
      disk.tx_buf[1] = 254
      _,err := disk.file.Seek( int64((arg - disk.offset) * 512), 0)
      if err!= nil {
	fmt.Println("Disk Seek Error",err)
      }
      read_sector()
      disk.tx_cnt = 2 + 128
      
    case 88: 
      disk.state = diskWrite
      _,err := disk.file.Seek( int64((arg - disk.offset) * 512), 0)
      if err!= nil {
        fmt.Println("Disk Seek Error",err)
      } 
      disk.tx_buf[0] = 0
      disk.tx_cnt = 1
      
    default: 
      disk.tx_buf[0] = 0
      disk.tx_cnt = 1
      
  }
  disk.tx_idx = -1
}

func write_sector(){
//  fmt.Printf(" WRITING SECTOR ")
  bytes:=make([]byte, 512)
  for i := 0; i < 128; i++ {
    bytes[i*4+0] = uint8(disk.rx_buf[i]      )
    bytes[i*4+1] = uint8(disk.rx_buf[i] >>  8)
    bytes[i*4+2] = uint8(disk.rx_buf[i] >> 16)
    bytes[i*4+3] = uint8(disk.rx_buf[i] >> 24)
  }
  disk.file.Write(bytes)
}

func read_sector(){
//  fmt.Printf(" READING SECTOR ")
  bytes := make([]byte, 512)
  _,err := disk.file.Read(bytes)
  if err!= nil {
    fmt.Println("Disk Read Error",err)
  }
  for i := 0; i < 128; i++ {
    disk.tx_buf[i+2] = uint32(bytes[i*4+0]) | (uint32(bytes[i*4+1]) << 8) | (uint32(bytes[i*4+2]) << 16) | (uint32(bytes[i*4+3]) << 24)
  }
}

func spi_write_data(spi, value uint32){
 if spi == 1 {
  disk.tx_idx++
  switch (disk.state) {
    case diskCommand: 
      if (uint8(value) != 0xFF || disk.rx_idx != 0) {
        disk.rx_buf[disk.rx_idx] = value
        disk.rx_idx++
        if (disk.rx_idx == 6) {
         disk_run_command()
          disk.rx_idx = 0
        }
      }
      
    case diskRead: 
      if (disk.tx_idx == disk.tx_cnt) {
        disk.state = diskCommand;
        disk.tx_cnt = 0;
        disk.tx_idx = 0;
      }
     
    case diskWrite: 
      if (value == 254) {
        disk.state = diskWriting;
      }
      
    case diskWriting: 
      if (disk.rx_idx < 128) {
        disk.rx_buf[disk.rx_idx] = value;
      }
      disk.rx_idx++;
      if (disk.rx_idx == 128) {
//        write_sector(disk.file, &disk.rx_buf[0]);
        write_sector()
      }
      if (disk.rx_idx == 130) {
        disk.tx_buf[0] = 5;
        disk.tx_cnt = 1;
        disk.tx_idx = -1;
        disk.rx_idx = 0;
        disk.state = diskCommand;
      }
      
  }
 }
}


func load_io(address uint32) uint32 {
  switch (address - IOStart) {
    case 0: 
      // Millisecond counter
//      if trace { fmt.Printf(" MS COUNTER") }
      risc.progress--
      return risc.current_tick
    
    case 4: 
      // Switches
//      if trace { fmt.Printf(" SWITCHES") }
      return 0
    
    case 8: 
      // RS232 data
//      if trace { fmt.Printf(" RS232 DATA") }
//      if (risc->serial) {
//        return risc->serial->read_data(risc->serial);
//      }
      return 0;
    
    case 12: 
      // RS232 status
//      if trace { fmt.Printf(" RS232 STATUS") }
//      if (risc->serial) {
//        return risc->serial->read_status(risc->serial);
//      }
      return 0;
    
    case 16: 
      // SPI data
        var value uint32 = 255
        value=spi_read_data(risc.spi_selected)
        msgtrace(&risc, fmt.Sprintf(" %08x from SPI%d DATA ",value,risc.spi_selected))

//      const struct RISC_SPI *spi = risc->spi[risc->spi_selected];
//      if (spi != NULL) {
//        return spi->read_data(spi);
//      }
      return value
    
    case 20: 
      // SPI status
      // Bit 0: rx ready
      // Other bits unused
      var value uint32 = 1
      msgtrace(&risc, fmt.Sprintf(" %08x from SPI STATUS ",value))
      return 1
    
    case 24: 
      // Mouse input / keyboard status
//      if trace { fmt.Printf(" MOUSE/KEYBOARD STATUS") }
      mouse := risc.mouse
      if risc.key_cnt > 0 {
        mouse = mouse | 0x10000000
//      } else {
//        risc->progress--;
      }
 //     fmt.Printf(" %02x %03x %03x \n",(mouse >> 24),(mouse & 0x00FFF000)>>12,(mouse & 0x00000FFF));
       return mouse
      
    case 28: 
      // Keyboard input
//      if trace { fmt.Printf(" KEYBOARD INPUT") }
      if (risc.key_cnt > 0) {
        scancode := risc.key_buf[0]
        risc.key_cnt--
        for i:=0; i<int(risc.key_cnt); i++ { 
           risc.key_buf[i]=risc.key_buf[i+1] 
        }
        return uint32(scancode)
      }
      return 0
    
    case 40: 
      // Clipboard control
//      if trace { fmt.Printf(" CLIPBOARD CONTROL ") }
//      if (risc->clipboard) {
//        return risc->clipboard->read_control(risc->clipboard);
//      }
      return 0
    
    case 44: 
      // Clipboard data
//      if trace { fmt.Printf(" CLIPBOARD DATA ") }
//      if (risc->clipboard) {
//        return risc->clipboard->read_data(risc->clipboard);
//      }
      return 0
   
    default: 
//      if trace { fmt.Printf(" IO DEFAULT FALLTHROUGH ") }
      return 0
    
  }
}


func store_io(address, value uint32) {
  switch (address - IOStart) {
    case 4: 
      msgtrace(&risc, fmt.Sprintf(" %08x -> LED CONTROL ",value))
      // LED control
//      if (risc->leds) {
//        risc->leds->write(risc->leds, value);
//      }
      
    
    case 8: 
      // RS232 data
      if trace { fmt.Printf(" RS232 DATA ") }
//      if (risc->serial) {
//        risc->serial->write_data(risc->serial, value);
//      }
      
    
    case 16: 
     // SPI write
        spi_write_data(risc.spi_selected, value);
        msgtrace(&risc, fmt.Sprintf(" %08x to SPI%d DATA ",value,risc.spi_selected))

      
    
    case 20: 
      // SPI control
      // Bit 0-1: slave select
      // Bit 2:   fast mode
      // Bit 3:   netwerk enable
      // Other bits unused
      risc.spi_selected = value & 3;
        msgtrace(&risc, fmt.Sprintf(" %08x to SPI CONTROL ",value & 3))
      
    
    case 40: 
      // Clipboard control
        if trace { fmt.Printf(" CLIPBOARD CONTROL ") }
//      if (risc->clipboard) {
//        risc->clipboard->write_control(risc->clipboard, value);
//      }
      
    
    case 44: 
      // Clipboard data
        if trace { fmt.Printf(" CLIPBOARD DATA ") }
//      if (risc->clipboard) {
//        risc->clipboard->write_data(risc->clipboard, value);
//      }
      
    
  }
}

var trace bool

func step() {
  
//  trace = true


  var ir uint32
  switch{
  case risc.PC < MemWords :
    ir = RAM[risc.PC];
  case (risc.PC >= ROMStart/4) && (risc.PC < ROMStart/4 + ROMWords) : 
    ir = ROM[risc.PC - ROMStart/4]
  default: 
    fmt.Printf("Branched into the void (PC=0x%08X, I=%d), resetting...\n", risc.PC,risc.icount)
    reset()
    return
  }

//  fmt.Printf("%s %x, %x ","step",risc.PC,ir)
  risc.PC=risc.PC+1
//  rtrace(&risc,ir)
  risc.icount++


  if ir & pbit == 0 {
    // Register instructions
    a  := (ir & 0x0F000000) >> 24
    b  := (ir & 0x00F00000) >> 20
    op := (ir & 0x000F0000) >> 16
    im :=  ir & 0x0000FFFF
    c  :=  ir & 0x0000000F

    var a_val, b_val, c_val uint32
    b_val = risc.R[b];
    if ((ir & qbit) == 0) {
      c_val = risc.R[c];
    } else if ((ir & vbit) == 0) {
      c_val = im;
    } else {
      c_val = 0xFFFF0000 | im;
    }
    
    switch op {
    case MOV:
        if ((ir & ubit) == 0) {
          a_val = c_val
        } else if ((ir & qbit) != 0) {
          a_val = c_val << 16;
        } else if ((ir & vbit) != 0) {
          a_val = 0xD0
	  if risc.N { a_val = a_val | 0x80000000 }
          if risc.Z { a_val = a_val | 0x40000000 }
          if risc.C { a_val = a_val | 0x20000000 }
          if risc.V { a_val = a_val | 0x10000000 }
        } else {
          a_val = risc.H;
        }
     
      
    case LSL: 
        a_val = b_val << (c_val & 31)
      
    case ASR: 
        a_val = uint32(int32((b_val)) >> (c_val & 31))
      
    case ROR: 
        a_val = (b_val >> (c_val & 31)) | (b_val << (-c_val & 31));
     
    case AND: 
        a_val = b_val & c_val
        
    case ANN: 
        a_val = b_val & ^c_val
     
    case IOR: 
        a_val = b_val | c_val
        
    case XOR: 
        a_val = b_val ^ c_val
        
    case ADD: 
        a_val = b_val + c_val
        if (((ir & ubit) != 0)&&risc.C) {
          a_val = a_val + 1
        }
        risc.C = a_val < b_val
        risc.V = (((a_val ^ c_val) & (a_val ^ b_val)) >> 31) != 0
        
    case SUB: 
        a_val = b_val - c_val
        if (((ir & ubit) != 0)&&risc.C) {
          a_val = a_val - 1
        }
        risc.C = a_val > b_val
        risc.V = (((b_val ^ c_val) & (a_val ^ b_val)) >> 31) != 0
       
      
    case MUL: 
        if ((ir & ubit) == 0) {
          tmpi := int64(int32(b_val)) * int64(int32(c_val))
          a_val = uint32(tmpi)
          risc.H = uint32(tmpi >> 32)
        } else {
          tmpu := uint64(b_val) * uint64(c_val)
          a_val = uint32(tmpu)
          risc.H = uint32(tmpu >> 32)
        }
      
    case DIV: 
        if (int32(c_val) > 0) {
          if ((ir & ubit) == 0) {
            a_val = uint32(int32(b_val) / int32(c_val))
            risc.H = uint32(int32(b_val) % int32(c_val))
            if (int32(risc.H) < 0) {
              a_val--
              risc.H += c_val
            }
          } else {
            a_val = b_val / c_val
            risc.H = b_val % c_val
          }
        } else {
          a_val,risc.H = idiv(b_val, c_val, (ir & ubit) != 0)
        }
        
    case FAD: 
	a_val = fp_add(b_val, c_val, (ir & ubit)!=0, (ir & vbit)!=0)
        
      
    case FSB: 
        a_val = fp_add(b_val, c_val ^ 0x80000000, (ir & ubit)!=0, (ir & vbit)!=0)
        
      
    case FML: 
        a_val = fp_mul(b_val, c_val)
       
      
    case FDV: 
        a_val = fp_div(b_val, c_val)
        
      
    default: 
      
    }
    set_register( a, a_val)

  } else if ((ir & qbit) == 0) {
    // Memory instructions
    a := (ir & 0x0F000000) >> 24
    b := (ir & 0x00F00000) >> 20
    off := ir & 0x000FFFFF
    off = (off ^ 0x00080000) - 0x00080000 // sign-extend

    address := risc.R[b] + off
    if ((ir & ubit) == 0) {
      var a_val uint32

      if (ir & vbit) == 0 {
        a_val = load_word( address)
      }else{ 
        a_val = uint32(load_byte( address))
      }

      set_register( a, a_val)

    }else{

      if (ir & vbit) == 0 {
        store_word(address, risc.R[a])
      }else{
        store_byte(address, byte(risc.R[a]))
      }

    }
  }else{
    // Branch instructions
    var t bool
    t = ((ir >> 27) & 1) != 0
    tf := (ir >> 24) & 7
    switch {
      case tf==0: t = t != risc.N
      case tf==1: t = t != risc.Z
      case tf==2: t = t != risc.C
      case tf==3: t = t != risc.V
      case tf==4: t = t != (risc.C || risc.Z)
      case tf==5: t = t != (risc.N != risc.V)
      case tf==6: t = t != ((risc.N != risc.V) || risc.Z)
      case tf==7: t = t != true
      default: //abort();  // unreachable
    }
    if (t) {
      if ((ir & vbit) != 0) {
        set_register(15, risc.PC * 4);
      }
      if ((ir & ubit) == 0) {
        c := ir & 0x0000000F;
        risc.PC = risc.R[c] / 4;
      } else {
        off := ir & 0x00FFFFFF;
        off = (off ^ 0x00800000) - 0x00800000;  // sign-extend
        risc.PC = risc.PC + off;
      }
    }
  }
}


var vChan chan [2]uint32


func main() {
        defer profile.Start(profile.CPUProfile).Stop()

        risc.halt = false
	
	
	
        imagePtr := flag.String("i", "RISC.img", "Disk image to boot")
        devicePtr := flag.String("d", "console", "Device to render to, e.g. X or console")
        mountpoint := flag.String("m", "/mnt/risc", "Mount Point for fuse filesystem")
	
	flag.Parse()

        risc.diskImage=*imagePtr
	risc.frameDevice=*devicePtr

	if risc.frameDevice == "console" {

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

        vChan = make(chan [2]uint32 )

        if risc.frameDevice == "console" {
	  risc.fbw,risc.fbh = cdisp.Initfb( vChan, &risc.mouse, &risc.key_buf, &risc.key_cnt )
	}else if risc.frameDevice == "X" {
	  risc.fbw,risc.fbh = xdisp.Initfb( vChan, &risc.mouse, &risc.key_buf, &risc.key_cnt )
	}
	fmt.Println("Graphics configured for",risc.fbw,"x",risc.fbh)

	reset()

        frfs.ServeRFS( mountpoint, disk.file, disk.offset )

	for !risc.halt {
	  step()
	}
	fmt.Printf("%+v\n",risc.PC)


}

