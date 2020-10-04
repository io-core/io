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



package board

import (
	"fmt"
	"os"
	"time"
	"io/ioutil"
	"strings"
	"strconv"
        
)


const MemSize=     0x00480000
const MemWords=    (MemSize / 4)
const ROMStart=    0xFFFFF800
const ROMWords=    512
const XDepth=	   1
//const DisplayStart=0x000E7F00
const IOStart=     0xFFFFFFC0

const pbit = 0x80000000
const qbit = 0x40000000
const ubit = 0x20000000
const vbit = 0x10000000


type BOARD struct {

  RAM []uint32
  ROM [ROMWords]uint32
  Disk Disk
  Vchan chan [2]uint32
  PIchan chan [2]uint32
  Mlim uint32
  DisplayStart uint32
  Tick, Polled int
  
  SPI_selected uint32
  Mouse, PMouse uint32
  Key_buf [16]byte
  Key_cnt uint32
  Fbw uint32
  Fbh uint32
  Fbd uint32
  Fbchg bool
  DiskImage string
  FrameDevice string
  StartTime uint32
}


const ( // DiskState
  diskCommand = iota
  diskRead
  diskWrite
  diskWriting
)

type Disk struct {


  state uint32
  File *os.File
  Offset uint32

  rx_buf [128]uint32
  rx_idx int

  tx_buf [128+2]uint32
  tx_cnt int
  tx_idx int
}


//var  RAM [MemWords]uint32
//var  ROM [ROMWords]uint32
//var disk Disk


func (board *BOARD) Opendisk(){
        f,err:=os.OpenFile(board.DiskImage, os.O_RDWR, 0644)
        if err != nil {
          panic(err)
        }else{
          board.Disk.File=f
        }

	sig:=make([]byte,4)
	n,err:=f.Read(sig)
        if err != nil {
          panic(err)
        }else{
	  fmt.Println("disk image signature:",sig,n)
          board.Disk.state = diskCommand
	  if sig[0]==141 && sig[1]==163 && sig[2]==30 && sig[3]==155{
            board.Disk.Offset = 0x80002
	  }else{
	    board.Disk.Offset = 0
	  }
	}
}

var verbose bool

func (board *BOARD) Reset(fbw, fbh, fbd uint32, vc chan [2]uint32, pic chan [2]uint32, v bool) {
        verbose = v
	board.Vchan = vc
	board.PIchan = pic

        board.Tick = 0
	board.Polled = 0

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
		board.ROM[ri]=uint32(r)
		
		//fmt.Print(ri)
		//fmt.Printf(" %x\n",uint32(r))
		ri++
	     }
           }
        }
	if board.Mlim == 0x00180000/4 {
		board.DisplayStart=0x000E7F00
		board.RAM[board.DisplayStart/4] = 0x53697A66  // magic value 'SIZE'+1
		board.RAM[board.DisplayStart/4+1] = fbw
		board.RAM[board.DisplayStart/4+2] = fbh
	}else{
		newMlim:=(board.Mlim*4) - (fbd * fbh * (fbw / 8)) - 272
                board.ROM[340] = 0x6e000000 + ((board.Mlim)>>15)
                board.ROM[372] = 0x61000000 + (newMlim >> 16)
                board.ROM[373] = 0x41160000 + (newMlim & 0xFFFF)
                board.RAM[376] = 0x61000000 + ((board.Mlim)>>15)
		board.DisplayStart=newMlim+16
		if fbd == 1 {
                  board.RAM[((newMlim+16)/4)] = 0x53697A66  // magic value 'SIZE'+1
		}else{
                  board.RAM[((newMlim+16)/4)] = 0x53697A67  // magic value 'SIZE'+2
		}
                board.RAM[((newMlim+16)/4)+1] = fbw
                board.RAM[((newMlim+16)/4)+2] = fbh
                board.RAM[((newMlim+16)/4)+3] = fbd
	}
	board.StartTime=uint32(time.Now().UnixNano() / int64(time.Millisecond))
        if verbose {fmt.Printf("%s"," board reset ")}

}



func (board *BOARD) Load_word(address uint32, core uint32) uint32{
  if (address < MemSize) {
    return board.RAM[address/4]
  } else {
    return board.Load_io(address,core)
  }
}

func (board *BOARD) Load_byte(address uint32, core uint32) byte {
  var w uint32 = 0 
  if (address < MemSize) {
    w = board.RAM[address/4]
  } else { 
    w = board.Load_io(address,core)
  }
  b:=byte(w >> (address % 4 * 8))
  return b

}


func (board *BOARD) Store_word(address, value uint32, core uint32) {
  if (address < board.DisplayStart) {
    board.RAM[address/4] = value
  } else if (address < MemSize) {
    board.RAM[address/4] = value
    if verbose {fmt.Printf("%s"," video send ")}
    board.Vchan <- [2]uint32{ address, value} 
  } else {
    board.Store_io(address, value, core)
  }
}


func (board *BOARD) Store_byte(address uint32, value uint8, core uint32) {
  if (address < MemSize) {
    w := uint32(board.Load_word(address,core))
    shift := uint32((address & 3) * 8)
    w = w & (^ (0xFF << shift))
    w = w | uint32(value) << shift
    board.Store_word(address, w,core)
  } else {
    
    board.Store_io( address, uint32(value), core)
  }
}

func (board *BOARD) spi_read_data( spi_selected uint32) uint32 {

  var result uint32 = 255
  if (spi_selected==1)&&(board.Disk.tx_idx >= 0 && board.Disk.tx_idx < board.Disk.tx_cnt) {
    result = board.Disk.tx_buf[board.Disk.tx_idx];
  } 
  return result;  

}

func (board *BOARD) disk_run_command(){
  cmd := board.Disk.rx_buf[0]
  arg := (board.Disk.rx_buf[1] << 24) | (board.Disk.rx_buf[2] << 16) | (board.Disk.rx_buf[3] << 8) | board.Disk.rx_buf[4]

  switch (cmd) {
    case 81: 
      board.Disk.state = diskRead
      board.Disk.tx_buf[0] = 0
      board.Disk.tx_buf[1] = 254
      _,err := board.Disk.File.Seek( int64((arg - board.Disk.Offset) * 512), 0)
      if err!= nil {
	fmt.Println("Disk Seek Error",err)
      }
      board.read_sector()
      board.Disk.tx_cnt = 2 + 128
      
    case 88: 
      board.Disk.state = diskWrite
      _,err := board.Disk.File.Seek( int64((arg - board.Disk.Offset) * 512), 0)
      if err!= nil {
        fmt.Println("Disk Seek Error",err)
      } 
      board.Disk.tx_buf[0] = 0
      board.Disk.tx_cnt = 1
      
    default: 
      board.Disk.tx_buf[0] = 0
      board.Disk.tx_cnt = 1
      
  }
  board.Disk.tx_idx = -1
}

func (board *BOARD) write_sector(){
  bytes:=make([]byte, 512)
  for i := 0; i < 128; i++ {
    bytes[i*4+0] = uint8(board.Disk.rx_buf[i]      )
    bytes[i*4+1] = uint8(board.Disk.rx_buf[i] >>  8)
    bytes[i*4+2] = uint8(board.Disk.rx_buf[i] >> 16)
    bytes[i*4+3] = uint8(board.Disk.rx_buf[i] >> 24)
  }
  board.Disk.File.Write(bytes)
}

func (board *BOARD) read_sector(){
  bytes := make([]byte, 512)
  _,err := board.Disk.File.Read(bytes)
  if err!= nil {
    fmt.Println("Disk Read Error",err)
  }
  for i := 0; i < 128; i++ {
    board.Disk.tx_buf[i+2] = uint32(bytes[i*4+0]) | (uint32(bytes[i*4+1]) << 8) | (uint32(bytes[i*4+2]) << 16) | (uint32(bytes[i*4+3]) << 24)
  }
}

func (board *BOARD) SPI_write_data(spi, value uint32){
 if spi == 1 {
  board.Disk.tx_idx++
  switch (board.Disk.state) {
    case diskCommand: 
      if (uint8(value) != 0xFF || board.Disk.rx_idx != 0) {
        board.Disk.rx_buf[board.Disk.rx_idx] = value
        board.Disk.rx_idx++
        if (board.Disk.rx_idx == 6) {
         board.disk_run_command()
          board.Disk.rx_idx = 0
        }
      }
      
    case diskRead: 
      if (board.Disk.tx_idx == board.Disk.tx_cnt) {
        board.Disk.state = diskCommand;
        board.Disk.tx_cnt = 0;
        board.Disk.tx_idx = 0;
      }
     
    case diskWrite: 
      if (value == 254) {
        board.Disk.state = diskWriting;
      }
      
    case diskWriting: 
      if (board.Disk.rx_idx < 128) {
        board.Disk.rx_buf[board.Disk.rx_idx] = value;
      }
      board.Disk.rx_idx++;
      if (board.Disk.rx_idx == 128) {
//        write_sector(disk.file, &disk.rx_buf[0]);
        board.write_sector()
      }
      if (board.Disk.rx_idx == 130) {
        board.Disk.tx_buf[0] = 5;
        board.Disk.tx_cnt = 1;
        board.Disk.tx_idx = -1;
        board.Disk.rx_idx = 0;
        board.Disk.state = diskCommand;
      }
      
  }
 }
}

// -128 to -68 for 16 color pallete 
func (board *BOARD) Load_io(address, core uint32) uint32 {
  switch (address - IOStart) {
    case 0:         
      // Millisecond counter    -64
//      if trace { fmt.Printf(" MS COUNTER") }
//      risc.progress--
//	fmt.Println(uint32(time.Now().UnixNano() / int64(time.Millisecond))-board.StartTime)
      return uint32(time.Now().UnixNano() / int64(time.Millisecond)) - board.StartTime
//	return 0  
  
    case 4: 
      // Switches       -60
//      if trace { fmt.Printf(" SWITCHES") }
      return 0
    
    case 8: 
      // RS232 data    -56
//      if trace { fmt.Printf(" RS232 DATA") }
//      if (risc->serial) {
//        return risc->serial->read_data(risc->serial);
//      }
      return 0;
    
    case 12: 
      // RS232 status   -52
//      if trace { fmt.Printf(" RS232 STATUS") }
//      if (risc->serial) {
//        return risc->serial->read_status(risc->serial);
//      }
      return 0;
    
    case 16: 
      // SPI data      -48
        var value uint32 = 255
        value=board.spi_read_data(board.SPI_selected)
//        msgtrace(&risc, fmt.Sprintf(" %08x from SPI%d DATA ",value,risc.spi_selected))

//      const struct RISC_SPI *spi = risc->spi[risc->spi_selected];
//      if (spi != NULL) {
//        return spi->read_data(spi);
//      }
      if verbose {fmt.Printf("%s %d"," spi read ",value)}
      return value
    
    case 20: 
      // SPI status          -44
      // Bit 0: rx ready
      // Other bits unused
      var value uint32 = 1
//      msgtrace(&risc, fmt.Sprintf(" %08x from SPI STATUS ",value))
      return value
    
    case 24: 
      // Mouse input / keyboard status    -40
      mouse := board.Mouse
      changed := board.PMouse != board.Mouse
      if board.Key_cnt > 0 {
        changed = true
        mouse = mouse | 0x10000000
      }

	board.PMouse = board.Mouse

	if !changed { 
		//fmt.Println("Poll Freq:",board.Tick-board.Polled)
		if board.Tick-board.Polled < 100 {
                	Snooze(40)
		}   
	}else{
			
	}

        board.Polled = board.Tick
	return mouse



 //     fmt.Printf(" %02x %03x %03x \n",(mouse >> 24),(mouse & 0x00FFF000)>>12,(mouse & 0x00000FFF));

    case 28: 
      // Keyboard input   -36
//      if trace { fmt.Printf(" KEYBOARD INPUT") }
      if (board.Key_cnt > 0) {
        scancode := board.Key_buf[0]
        board.Key_cnt--
        for i:=0; i<int(board.Key_cnt); i++ { 
           board.Key_buf[i]=board.Key_buf[i+1] 
        }
        return uint32(scancode)
      }
      return 0
    
    case 40: 
      // Clipboard control  -24
//      if trace { fmt.Printf(" CLIPBOARD CONTROL ") }
//      if (risc->clipboard) {
//        return risc->clipboard->read_control(risc->clipboard);
//      }
      return 0
    
    case 44: 
      // Clipboard data   -20
//      if trace { fmt.Printf(" CLIPBOARD DATA ") }
//      if (risc->clipboard) {
//        return risc->clipboard->read_data(risc->clipboard);
//      }
      return 0
   
    default: 
//      if trace { fmt.Printf(" IO DEFAULT FALLTHROUGH ") }
      return 0
    
  }
  return 0
}

func Snooze( value uint32 ) {
  time.Sleep(time.Millisecond * time.Duration(value))
}


// -128 to -68 for 16 color pallete
func (board *BOARD) Store_io(address, value, core uint32) {
  switch (address - IOStart) {

    case 0:            //         -64
	if value > 0 && value < 1001 {
	  fmt.Println("sleeping",value,"Milliseconds")
	  Snooze(value)
	}

    case 4:              //       -60
//      msgtrace(&risc, fmt.Sprintf(" %08x -> LED CONTROL ",value))
      // LED control
//      if (risc->leds) {
//        risc->leds->write(risc->leds, value);
        fmt.Println("LED",value)
//      }
      
    
    case 8: 
      // RS232 data               -56
//      if trace { fmt.Printf(" RS232 DATA ") }
//      if (risc->serial) {
//        risc->serial->write_data(risc->serial, value);
//      }
      
    
    case 16: 
     // SPI write               -48
        board.SPI_write_data(board.SPI_selected, value);
//        msgtrace(&risc, fmt.Sprintf(" %08x to SPI%d DATA ",value,risc.spi_selected))

      
    
    case 20: 
      // SPI control            -44
      // Bit 0-1: slave select
      // Bit 2:   fast mode
      // Bit 3:   netwerk enable
      // Other bits unused
      board.SPI_selected = value & 3;
//        msgtrace(&risc, fmt.Sprintf(" %08x to SPI CONTROL ",value & 3))
      
    
    case 40: 
      // Clipboard control  -24
//        if trace { fmt.Printf(" CLIPBOARD CONTROL ") }
//      if (risc->clipboard) {
//        risc->clipboard->write_control(risc->clipboard, value);
//      }
      
    
    case 44: 
      // Clipboard data   -20
//        if trace { fmt.Printf(" CLIPBOARD DATA ") }
//      if (risc->clipboard) {
//        risc->clipboard->write_data(risc->clipboard, value);
//      }
      
    
  }
}

