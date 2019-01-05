//
// Copyright © 2017,2018 Charles Perkins
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

package frfs

import (
	"log"
	"os"
	"fmt"
        "bazil.org/fuse"
        "bazil.org/fuse/fs"
        "bazil.org/fuse/fuseutil"
	"golang.org/x/net/context"
)

type RFS_FS struct {
        root *RFS_D
	file *os.File
	offset uint32
        size int64
	r chan readOp
	w chan writeOp
}

func (f *RFS_FS) Root() (fs.Node, error) {
        return f.root, nil
}

type inode uint64

func (i *inode) Attr(ctx context.Context, attr *fuse.Attr) error {
	return nil
}

type RFS_D struct {
        inode uint64
	disk *RFS_FS
}

func (d *RFS_D) Attr(ctx context.Context, a *fuse.Attr) error {
        a.Inode = d.inode
        a.Mode = os.ModeDir | 0777
        return nil
}

func (d *RFS_D) Lookup(ctx context.Context, name string) (fs.Node, error) {
        files := RFS_Scan(d.disk, RFS_DiskAdr(d.inode), nil,"Lookup")
        if files != nil {
                for _, f := range files {
                        if f.N == name {
                                return &RFS_F{inode: uint64(f.S), disk: d.disk}, nil
                        }
                }
        }
        return nil, fuse.ENOENT
}

func (d *RFS_D) ReadDirAll(ctx context.Context) ([]fuse.Dirent, error) {

        var result []fuse.Dirent
	
        files := RFS_Scan(d.disk, RFS_DiskAdr(d.inode), nil,"ReadDirAll")
        if files != nil {
                for _, f := range files {
                        result = append(result, fuse.Dirent{Inode: uint64(f.S), Type: fuse.DT_File, Name: f.N})
                }
        }
        return result, nil
}

func name_is_good(name string) bool {
	return true
}

func RFS_FindNFreeSectors(n int, d *RFS_D ) []RFS_DiskAdr {
   smsz := int64(d.disk.size)
   if d.disk.offset == 0 {
	smsz = smsz -(262144*1024)
   }
   
   var slist []RFS_DiskAdr

   for i:= range smap { // 0;i<RFS_AllocMapLimit;i++{
      smap[i]=0
   }
   fmt.Print("S")
   _ = RFS_Scan(d.disk, RFS_DiskAdr(d.inode), &smap,"FindSectors")

   startat:=0
   for ith:=0;ith<n;ith++{
   	found:=0
   	for i:=startat; i<len(smap); i++{
           if found == 0 && i > 0 && smap[i] != 0xffffffffffffffff {
                   found = i
		   startat = i
           }
   	}
   	if found > 0 {
                fbit:=64
                for j := 0; j < 64 && fbit == 64 ; j++ {
                  if ((smap[found]) & (1 << uint(j) ))!=0{
                  }else{
                    fbit=j
                  }
                }
                if fbit != 64{
                        nsec:=(found*64) + fbit
			smap[found]=smap[found] | (1 << uint(fbit) )
                        slist=append(slist,RFS_DiskAdr(nsec))
                }
   	}else{
   	  ith=n
   	}
   }
   return slist
}


func (d *RFS_D) Create(ctx context.Context, req *fuse.CreateRequest, resp *fuse.CreateResponse) (fs.Node, fs.Handle, error) {

    var fserr error = fuse.EIO
    var attr = fuse.Attr{Inode: 0, Mode: 0777, Size: 0}

    fsn := &RFS_F{inode: 0,disk: d.disk}
    if name_is_good(req.Name){
        var fhdr RFS_FileHeader

	for i:=0;i<len(req.Name);i++{
	    fhdr.Name[i]=req.Name[i]
	}
	fhdr.Mark = RFS_HeaderMark
	fhdr.Aleng = 0
	fhdr.Bleng = RFS_HeaderSize
	fhdr.Date = 0
	

        slist := RFS_FindNFreeSectors(1, d) 
        if len(slist)!=1{
                        fmt.Println("Failed to find one free sector for the file header")
	}else{
			nsec := slist[0]
			fhdr.Sec[0]=RFS_DiskAdr(nsec*29)

			fsn.inode=uint64(nsec*29)
			attr.Inode=uint64(nsec*29)
			resp.Node=fuse.NodeID(nsec*29)
			//resp.Generation=1
			//resp.EntryValid=0
			resp.Attr=attr
                        //resp.Handle=fuse.HandleID(nsec)
                        //resp.Flags=0

			RFS_K_PutFileHeader( d.disk, RFS_DiskAdr(nsec*29), &fhdr)

			//h:=false
			h,U := RFS_Insert(d.disk, req.Name, RFS_DirRootAdr,RFS_DiskAdr(nsec*29) )
			if h {  // root overflow
				fmt.Println("overflow, ascending at entry",U)
			}else{
				fserr = nil
			}
		
	}
    }

    return fsn,fsn,fserr

}

func (d *RFS_D) Remove(ctx context.Context, req *fuse.RemoveRequest) error          {   return fuse.ENOSYS       }

func (d *RFS_D) Mkdir(ctx context.Context, req *fuse.MkdirRequest) (fs.Node, error) {   return nil, fuse.ENOSYS  }

type RFS_F struct {
        inode uint64
	disk *RFS_FS
}

func (f *RFS_F) Attr(ctx context.Context, a *fuse.Attr) error {
      a.Inode = f.inode
      a.Mode = 0777

      var fh RFS_FileHeader
      
      if f.inode % 29 != 0 {
            fmt.Println("inode not divisible by 29 in Attr:",f.inode)
      }else{

        ok:=RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh,"Attr")
	if ! ok {
            fmt.Println("GetFileHeader failed in Attr:",f.inode/29)
	}else{
          a.Size = (uint64(fh.Aleng) * RFS_SectorSize) + uint64(fh.Bleng) - RFS_HeaderSize
	}
      }
      return nil
}

//func (f *RFS_F) Setattr(ctx context.Context, req *fuse.SetattrRequest, resp *fuse.SetattrResponse) (err error) {
//        fmt.Printf("Setting file attributes (not!)")
//	return nil
//}

func (f *RFS_F) Read(ctx context.Context, req *fuse.ReadRequest, resp *fuse.ReadResponse) error {
        fuseutil.HandleRead(req, resp, nil)
        return nil
}

func (f *RFS_F) ReadAll(ctx context.Context) ([]byte, error) {

      var fh RFS_FileHeader
     
      var rv []byte

      if f.inode % 29 != 0 {
            fmt.Println("inode not divisible by 29 in ReadAll:",f.inode)
      }else{

        ok:=RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh,"ReadAll")
	
        
	if ! ok {
	 fmt.Println("ReadAll not ok for some reason.")
	}else{
          for i:=0;i<=int(fh.Aleng);i++{
	   sn:=RFS_DiskAdr(0)
	   if i < RFS_SecTabSize {
	    sn = fh.Sec[i]
	   }else{
	    xte := int32( i - RFS_SecTabSize ) / 256
            xti := int32( i - RFS_SecTabSize ) % 256

            //rsp := make(chan sbuf)
            //f.disk.r <- readOp{fh.Ext[xte], rsp}
            //sector := <- rsp
            sector := getSector(f.disk,fh.Ext[xte])

            sn=sector.DiskAdrAt(int(xti))


	   }
           if sn>0 {
            //fsec := RFS_K_Read(f.disk,sn)

            //rsp := make(chan sbuf)
            //f.disk.r <- readOp{sn, rsp}
            //fsec := <- rsp
            fsec := getSector(f.disk,sn)

            if i==0 {
                  if fh.Aleng==0 {
                    rv = append(rv,fsec[RFS_HeaderSize:fh.Bleng]...)
                  }else{
                    rv = append(rv,fsec[RFS_HeaderSize:]...)
                  }
            }
            if i > 0 && i < int(fh.Aleng) {
                  rv = append(rv,fsec...)
            }
            if i > 0 && i == int(fh.Aleng) {
                  rv = append(rv,fsec[:fh.Bleng]...)
            }
           }else{
	    fmt.Println("Disk read error in file",fh.Name[:],"Attempt to read sector zero.")
           }
        } 
      }
    }
    return rv, nil
}

func saneDiskAdr( adr RFS_DiskAdr, m string ) bool {
  
  if adr == 0 {
	fmt.Println("Insane Disk Address (zero):",adr,m)
	os.Exit(1)
  }
  if adr % 29 != 0 {
        fmt.Println("Insane Disk Address (not mod 29):",adr,m)
	os.Exit(1)
  }
  return true
}

func getSector(disk *RFS_FS, adr RFS_DiskAdr) sbuf {
	var sec sbuf
	if saneDiskAdr(adr,"Get Sector") {
        	rsp := make(chan sbuf)
        	disk.r <- readOp{adr,rsp}
        	sec = <- rsp
	}
	return sec
}

func putSector(disk *RFS_FS, adr RFS_DiskAdr, sector sbuf){
        rsp := make(chan bool)
        disk.w <- writeOp{adr, sector, rsp}
        _ = <- rsp
}

func (f *RFS_F) Write(ctx context.Context, req *fuse.WriteRequest, resp *fuse.WriteResponse) error {

	var fserr error = fuse.EIO
	var fh RFS_FileHeader
	var fsec sbuf
        var xsec sbuf = make([]byte,1024)

	ok:=RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh,"Write")
	isAppend := int32(req.FileFlags & fuse.OpenAppend)/int32(fuse.OpenAppend) 

	if ok && saneDiskAdr(fh.Sec[0], "File Header Self Sector") {  	 
		fsec = getSector(f.disk,fh.Sec[0])
	}else{
		os.Exit(1)
	}

	osz := int32(req.Offset) + (isAppend * ((fh.Aleng * RFS_SectorSize) + fh.Bleng - RFS_HeaderSize))
	nsz := osz + int32(len(req.Data))

	oA := fh.Aleng
	oB := fh.Bleng
        nA := (nsz + RFS_HeaderSize) / RFS_SectorSize
	nB := (nsz + RFS_HeaderSize) % RFS_SectorSize
        adelta := nA - oA
        var xtbuf [ 256 ]RFS_DiskAdr

	if oA < nA {
                fmt.Print("[")
                oxA:=oA+1-RFS_SecTabSize; if oxA < 0 { oxA = 0 }
		nxA:=nA+1-RFS_SecTabSize; if nxA < 0 { nxA = 0 }
		dxA:= nxA - oxA
		
                xP:=int32(0);  if dxA > 0 { xP = ( dxA / 256 ) + 1 }

                fmt.Print("/",len(req.Data)/1024,len(req.Data)%1024,"/",dxA,"/",adelta,"/",xP,"/")

        	slist := RFS_FindNFreeSectors(int(xP+adelta), f.disk.root)
                
        	if len(slist)!=int(xP+adelta){
        	        fmt.Println("Failed to find",xP+adelta,"free sector(s) for the file")
			os.Exit(1)
        	}else{
                        xsn:=RFS_DiskAdr(0)
                        xtmod:=false
			xtloaded:=false
		        
			for i:=oA+1;i<=nA;i++{
                                if i < RFS_SecTabSize {
				  fh.Sec[i]=slist[xP+i-(oA+1)]*29
				  fsec.PutWordAt(int(24+i),uint32(slist[xP+i-(oA+1)])*29)
				}else{
				  fmt.Print("!")
                                  xi := i - RFS_SecTabSize
                                  xiP := xi / 256  
 				  xiPi := xi % 256
				  if xiPi == 0 {
				      if xtmod {
					putSector(f.disk,xsn,xsec)
					xtmod = false
				      }
                                      fh.Ext[xiP]=slist[xiP]*29
				      xsn=slist[xiP]*29
                                      for j:=0;j<256;j++{
                                            xtbuf[j]=RFS_DiskAdr(0)
					    xsec.PutWordAt(j,uint32(0))
				      }
                                      fsec.PutWordAt(int(12+xiP),uint32(slist[xiP])*29)
				      xtloaded = true
				  }else{
					if ! xtloaded {
					    xsn=fh.Ext[xiP]
                                            
                                            xsec = getSector(f.disk,xsn)
                                            
                                            for j:=0;j<256;j++{
                                                xtbuf[j]=xsec.DiskAdrAt(j)
                                            }
					    xtloaded = true      
					} 
				  }
                                  
				  xtbuf[xiPi]=slist[xP+i-(oA+1)]*29
                                  xsec.PutWordAt(int(xiPi),uint32(slist[xP+i-(oA+1)])*29)
				  xtmod = true
                                  fmt.Print(xiP,":",xiPi)

                                }

                        }
                        if xtmod {
				putSector(f.disk,xsn,xsec)
			}


        	}
                fmt.Print("]")
                
	}else if oA > nA{
                fmt.Println("Have too many sectors... ignoring extra")
	}

        rc:= int32(0)
        xsn:=RFS_DiskAdr(0)
        fmt.Print("{")
	for seqn:= int32(0); seqn <= nA && seqn < RFS_SecTabSize; seqn ++ {
                sn := RFS_DiskAdr(0)
	        if seqn < RFS_SecTabSize {
                    fmt.Print(".")
	            sn = fh.Sec[seqn]
	        }else{
                    fmt.Print(",")
                  xi := seqn - RFS_SecTabSize
                  xiP := xi / 256 
                  xiPi := xi % 256
                    
                    if xsn != fh.Ext[xiP] {
                                xsn = fh.Ext[xiP]
                                xsec := getSector(f.disk,xsn)
                                for j:=0;j<256;j++{
                                        xtbuf[j]=xsec.DiskAdrAt(j)
                                }
		    }

	            sn = xtbuf[ xiPi ]
                    if sn % 29 != 0 {
                       fmt.Println("Sector index format error:",sn," not divisible by 29")
		    }    
	        
                    fmt.Print("[",sn/29,"]")
                   
                }
		if seqn == 0 || seqn >= int32( rc + osz + RFS_HeaderSize )/ RFS_SectorSize {
	                if seqn > 0 {
			       
                                fsec = getSector(f.disk,sn)
			        

	                }else{
                                fh.Aleng = int32(nA)
                                fh.Bleng = int32(nB)
                                
                                fsec.PutWordAt(9,uint32(fh.Aleng))
                                fsec.PutWordAt(10,uint32(fh.Bleng))
			}

			if seqn==0 && ((osz + RFS_HeaderSize)/RFS_SectorSize) == 0 {
				for i:=int32(0); i < (RFS_SectorSize - (osz+RFS_HeaderSize)) &&  rc < int32(len(req.Data)) ; i++ {
					fsec[ (osz+RFS_HeaderSize) + i ] = req.Data[ rc ]
                                	rc = rc + 1
				}
			}
                        if seqn > 0 && (isAppend==1) && seqn == oA {
                                for i:=int32(0); i < (RFS_SectorSize - oB) &&  rc < int32(len(req.Data)) ; i++ {
                                        fsec[ oB + i ] = req.Data[ rc ]
                                        rc = rc + 1
                                }
			} else if seqn > 0 {
                                for i:=int32(0); i < RFS_SectorSize &&  rc < int32(len(req.Data)) ; i++ {
                                        fsec[ i ] = req.Data[ rc ] 
                                        rc = rc + 1
                                }
			}

		        rsp := make(chan bool)
		        f.disk.w <- writeOp{sn, fsec, rsp}
		        _ = <- rsp

		}
                    
        }
	resp.Size = len(req.Data)
        fserr = nil
        fmt.Print("}")      
      return fserr   
}

func (f *RFS_F) Flush(ctx context.Context, req *fuse.FlushRequest) error {      return nil   }

func (f *RFS_F) Open(ctx context.Context, req *fuse.OpenRequest, resp *fuse.OpenResponse) (fs.Handle, error) {	return f, nil   }

func (f *RFS_F) Release(ctx context.Context, req *fuse.ReleaseRequest) error {  return nil   }

func (f *RFS_F) Fsync(ctx context.Context, req *fuse.FsyncRequest) error {      return nil   }

// 32-bit oberon file system                                // 64-bit oberon filesystem
const RFS_FnLength    = 32                                  // 255 + a zero byte = 256
const RFS_SecTabSize   = 64                                 // 64 -- 62 bit integer, top two bits flag for 0, 1, 2, or 3 level indirect
const RFS_ExTabSize   = 12                                  // maximum file size: 64 * 512 * 512 * 512 * 4096 = 32T
const RFS_SectorSize   = 1024                               // 4096
const RFS_IndexSize   = 256    //SectorSize / 4             // 512  -- SectorSize / 8
const RFS_HeaderSize  = 352                                 // 1024
const RFS_DirRootAdr  = 29                                  // 29
const RFS_DirPgSize   = 24
const RFS_N = 12               //DirPgSize / 2
const RFS_DirMark    = 0x9B1EA38D
const RFS_HeaderMark = 0x9BA71D86
const RFS_FillerSize = 52

var rfs_numsectors = 1220   // RISC.img size / 1024

// 141G max volume size (2^32)/29 sectors, 1k sector size   // 565Y max volume size 2^62 sectors, 4k sector size, div 29

const   RFS_AllocMapLimit = 9256395
type 	RFS_AllocMap	[RFS_AllocMapLimit]uint64   // 9.2 MiB for a bit for every possible sector on a maximally sized disk

var smap RFS_AllocMap

type    RFS_DiskAdr         int32
type    RFS_FileName       [RFS_FnLength]byte           // 672 data bytes in zeroth sector of file
type    RFS_SectorTable    [RFS_SecTabSize]RFS_DiskAdr  // 65,184 byte max file size without using extension table
type    RFS_ExtensionTable [RFS_ExTabSize]RFS_DiskAdr   // 3,210,912 max file size with addition of extension table
type    RFS_EntryHandler   uint32 //= PROCEDURE (name: FileName; sec: DiskAdr; VAR continue: BOOLEAN);

type  RFS_FileHeader struct { // (*first page of each file on disk*)
        Mark uint32
        Name [32]byte
        Aleng, Bleng, Date int32
        Ext  RFS_ExtensionTable
        Sec RFS_SectorTable
        fill [RFS_SectorSize - RFS_HeaderSize]byte
}

type    RFS_FileHd *RFS_FileHeader
type    RFS_IndexSector [RFS_IndexSize]RFS_DiskAdr
type    RFS_DataSector [RFS_SectorSize]byte

type    RFS_DirEntry struct { //  (*B-tree node*)
        Name [32]byte
        Adr  RFS_DiskAdr  // (*sec no of file header*)
        P    RFS_DiskAdr  // (*sec no of descendant in directory*)
}

type    RFS_DirPage struct {
        Mark  uint32
        M     int32
        P0    RFS_DiskAdr //  (*sec no of left descendant in directory*)
//        fill  [RFS_FillerSize]byte
        E  [RFS_DirPgSize]RFS_DirEntry
}

var RFS_k int32
var RFS_A [2000]RFS_DiskAdr

func RFS_Aquire(){
}

func RFS_Release(){
}

type sbuf []byte

type readOp struct {
	i RFS_DiskAdr
	c chan sbuf
}

type writeOp struct {
        i RFS_DiskAdr
	s sbuf
        c chan bool
}

func RFS_K_Drive( disk *RFS_FS ){
	for ;; {
		select{
		
		case readit := <- disk.r :
			
		        RFS_Aquire()

		        x:=(readit.i /29)+262144
		        _,err := disk.file.Seek( (int64(x)*1024) - int64(disk.offset*512),0 )
		        if err!= nil {    fmt.Println("Disk Seek Error in Read --->",err,"address",(int64(x)*1024),"offset",int64(disk.offset*512),"page",readit.i/29)      }
		        bytes := make(sbuf,1024)
		        n,err := disk.file.Read(bytes)
		        if err!= nil {        fmt.Println("Disk Read Error",err,x)      }
		        if n< 1024 {        fmt.Println("K_Read less than 1024:",n)      }
		
		        RFS_Release()

			readit.c <- bytes

		case writeit := <- disk.w :
                        
		        RFS_Aquire()
		        
		        x:=(writeit.i/29)+262144
		        _,err := disk.file.Seek( (int64(x)*1024) - int64(disk.offset*512),0 )
		        if err!= nil {    fmt.Println("Disk Seek Error in Write --->",err,"address",(int64(x)*1024),"offset",int64(disk.offset*512),"page",writeit.i/29)      }
		
		        disk.file.Write(writeit.s)
		        
		        RFS_Release()

			writeit.c <- true
		}
	}

}

func (bytes sbuf) Int32At( i int) int32 {
     return int32(uint32(bytes[(i*4)+0]) | (uint32(bytes[(i*4)+1]) << 8) | (uint32(bytes[(i*4)+2]) << 16) | (uint32(bytes[(i*4)+3]) << 24))
}

func (bytes sbuf) Uint32At( i int) uint32 {
     return uint32(bytes[(i*4)+0]) | (uint32(bytes[(i*4)+1]) << 8) | (uint32(bytes[(i*4)+2]) << 16) | (uint32(bytes[(i*4)+3]) << 24)
}

func (bytes sbuf) DiskAdrAt( i int) RFS_DiskAdr {
     return RFS_DiskAdr(uint32(bytes[(i*4)+0]) | (uint32(bytes[(i*4)+1]) << 8) | (uint32(bytes[(i*4)+2]) << 16) | (uint32(bytes[(i*4)+3]) << 24))
}

func (bytes sbuf) PutWordAt( i int, w uint32) {
        bytes[i*4]=byte(w & 0xFF)
        bytes[(i*4)+1]=byte((w >> 8) & 0xFF)
        bytes[(i*4)+2]=byte((w >> 16) & 0xFF)
        bytes[(i*4)+3]=byte((w >> 24) & 0xFF)
}

func RFS_K_PutFileHeader( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_FileHeader){

	sector := sbuf(make([]byte, 1024))
	
	sector.PutWordAt(0,RFS_HeaderMark)

         for i:=0;i<32;i++{
            sector[i+4]=a.Name[i]
         }

        sector.PutWordAt(9,uint32(a.Aleng))
        sector.PutWordAt(10,uint32(a.Bleng))
        sector.PutWordAt(11,uint32(a.Date))

         for i:=0;i<RFS_ExTabSize;i++{
            sector.PutWordAt(12+i,uint32(a.Ext[i]))
         }
         for i:=0;i<RFS_SecTabSize;i++{
            sector.PutWordAt(24+i,uint32(a.Sec[i]))
         }

         for i:=0;i<(RFS_SectorSize - RFS_HeaderSize);i++{
            sector[RFS_HeaderSize+i]=a.fill[i]
         }
        rsp := make(chan bool)
        disk.w <- writeOp{dpg, sector, rsp}
         _ = <- rsp


}

func RFS_K_GetFileHeader( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_FileHeader,caller string) (ok bool){

    if dpg % 29 != 0 {
        fmt.Println("sector",dpg,"is not divisble by 29 in GetFileHeader called from",caller)
    }else{

      //rsp := make(chan sbuf)
      //disk.r <- readOp{dpg, rsp}
      //sector := <- rsp
      sector := getSector(disk,dpg)

      a.Mark =sector.Uint32At(0)

      if a.Mark == RFS_HeaderMark {
         for i:=0;i<32;i++{
            a.Name[i]=sector[i+4]
         }
         a.Aleng=sector.Int32At(9)
         a.Bleng=sector.Int32At(10)
         a.Date =sector.Int32At(11)
         for i:=0;i<RFS_ExTabSize;i++{
            a.Ext[i]=sector.DiskAdrAt(i+12)
	 }
	

         for i:=0;i<RFS_SecTabSize;i++{
            a.Sec[i]=sector.DiskAdrAt(i+24)
         }
         for i:=0;i<RFS_SectorSize - RFS_HeaderSize;i++{
           a.fill[i]=sector[i+RFS_HeaderSize]
         }
	 ok = true
      }else{
	fmt.Println("sector",dpg/29,"has no header mark in GetFileHeader called from",caller,"is:",sector)
      }
    }
    return ok
}

func RFS_K_PutDirSector( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_DirPage){

   if a.Mark != RFS_DirMark {
	fmt.Println("Asked to write a dirpage that does not have dirmark!")
   }else{

      sector := sbuf(make([]byte, 1024))

      sector.PutWordAt(0,a.Mark)
      sector.PutWordAt(1,uint32(a.M))
      sector.PutWordAt(2,uint32(a.P0))

      for e := 0; int32(e)<a.M;e++{
          i := 16 + (e*10)
          for x:=0;x<32;x++ {
            sector[(i*4)+x]=a.E[e].Name[x]
          } 
          sector.PutWordAt(i+8,uint32(a.E[e].Adr))  
          sector.PutWordAt(i+9,uint32(a.E[e].P))  
      }

      rsp := make(chan bool)
      disk.w <- writeOp{dpg, sector, rsp}
      _ = <- rsp

   }
}

func RFS_K_GetDirSector( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_DirPage){

      //rsp := make(chan sbuf)
      //disk.r <- readOp{dpg, rsp}
      //sector := <- rsp
      sector := getSector(disk,dpg)


      a.Mark =sector.Uint32At(0)
      a.M    =sector.Int32At(1)
      a.P0   =sector.DiskAdrAt(2)

   if a.Mark == RFS_DirMark {

      for e := 0; int32(e)<a.M;e++{
          i := 16 + (e*10)
          for x:=0;x<32;x++ {
            a.E[e].Name[x]=sector[(i*4)+x]
          }
          a.E[e].Adr = sector.DiskAdrAt(i+8)
          a.E[e].P   = sector.DiskAdrAt(i+9)
      }
    }

}

func RFS_Insert(disk *RFS_FS, name string,  dpg0 RFS_DiskAdr, fad RFS_DiskAdr) (h bool, v RFS_DirEntry) {

  var a RFS_DirPage
  var u RFS_DirEntry
  h = false  //    (*h = "tree has become higher and v is ascending element"*)

  RFS_K_GetDirSector(disk, dpg0, &a)
  if a.Mark != RFS_DirMark {
	fmt.Println("Directory sector load did not have directory mark")
  }else{
    L :=int32(0) // binary search current directory page
    R :=a.M
    for L < R {
	i:= (L+R)/2
	if name <= string(a.E[i].Name[:]) {
	  R = i
	}else{
	  L = i+1
	}
    }
    if (R < a.M) && (name == string(a.E[R].Name[:])) {  // is already on page, replace
        a.E[R].Adr = fad
	RFS_K_PutDirSector(disk,dpg0, &a) 
	fmt.Println("File already exists -- Replacing")

    }else{  // not on this page
	var dpg1 RFS_DiskAdr
	if R == 0 {
	    dpg1 = a.P0 
	}else{
	    dpg1 = a.E[R-1].P
	}
	if dpg1 == 0 { // can place here
	    u.Adr = fad
	    u.P = 0
	    h = true
	    for j:=0;j<len(name);j++{
		u.Name[j]=name[j]
	    }
	    for j:=len(name);j<RFS_FnLength;j++{
		u.Name[j]=0x00
	    }
	}else{  // go look at another page
	    h, u = RFS_Insert(disk,name,dpg1,fad)
	}

	if h { // insert u to the left of e[R]
	    if a.M < RFS_DirPgSize {
		h = false
		for i := a.M; i > R; i-- {
		  a.E[i] = a.E[i-1]
		}
		a.E[R] = u
		a.M++
                RFS_K_PutDirSector(disk,dpg0,&a)
		fmt.Println("directory entry inserted")
	    }else{ // split page and assign the middle element to v
                fmt.Println("splitting directory page")
                
	        slist := RFS_FindNFreeSectors(2, disk.root)
	        if len(slist)!=2{
                        fmt.Println("Failed to find another sector for the directory page split")
	        }else{
                        nsec := slist[1]*29
			fmt.Println("Parent Directory Sector:",dpg0/29,"Split to:",nsec/29)
	                a.M = RFS_N
			a.Mark = RFS_DirMark
	                if R < RFS_N {       // (*insert in left half*)
			  fmt.Println("Inserting in left half")
	                  v = a.E[RFS_N-1]
			  i := int32(RFS_N-1)
	                  for ;i > R;  {
				 i = i - 1
				 a.E[i+1] = a.E[i] 
			  }
	                  a.E[R] = u
			  RFS_K_PutDirSector(disk,dpg0, &a)
	                  //Kernel.AllocSector(dpg0, dpg0)
                          //tdpg0 = nsec*29
			  i = 0
	                  for ;i < RFS_N; { 
				a.E[i] = a.E[i+RFS_N]
				i = i + 1
			  }
	                }else{           // (*insert in right half*)
                          fmt.Println("Inserting in right half")
	                  RFS_K_PutDirSector(disk,dpg0, &a)
                          //tdpg0 = nsec*29
	    //            Kernel.AllocSector(dpg0, dpg0)
			  R = R - RFS_N
			  i := int32(0)
	                  if R == 0 {
				v = u
			  }else{
	                        v  = a.E[RFS_N]
	                        for ;i < R-1; {
					a.E[i] = a.E[RFS_N+1+i]
					i = i + 1
				}
	                        a.E[i] = u
				i = i + 1
	                  }
	                  for  ;i < RFS_N; {
				a.E[i] = a.E[RFS_N+i]
				i = i + 1
			  }
	                }
	                a.P0 = v.P
			v.P = nsec
			a.Mark = RFS_DirMark
            

		
                        RFS_K_PutDirSector(disk,nsec,&a)
                }
            }
            
        }
    }

  }
  return h, v
}

func FindNameEnd(s []byte) int {
  var i int
  for i=0;(i<len(s)&&(s[i]>32 && s[i]<127));i++ {}
  return i

}

type RFS_FI struct {
     N string
     S RFS_DiskAdr
}

func secBitSet( tsmap *RFS_AllocMap, dpg RFS_DiskAdr) (rv bool) {
    if tsmap != nil {
        s:=dpg/29
	x:=dpg%29
	if x != 0 {
		fmt.Printf("DiskAdr not evenly divisible by 29!\n")
	}
        e:=s/64
        r:=s%64
	  if tsmap[e] & (1<<uint(r)) != 0 {
		fmt.Println("sector already allocated in scan:", dpg/29)
	  }else{
                tsmap[e] = tsmap[e] | (1<<uint(r))
		rv = true
	  }
    }
    return rv

}


func RFS_Scan(disk *RFS_FS, dpg RFS_DiskAdr, tsmap *RFS_AllocMap, caller string ) []RFS_FI {

  var a RFS_DirPage
  var files []RFS_FI
  var sector sbuf

  if dpg%29 != 0 {
     fmt.Println("Attept to scan from DiskAdr", dpg, "which is not divisible by 29 from",caller)
  }else{

  RFS_K_GetDirSector(disk, dpg, & a)
//  fmt.Println("Scan:",dpg/29)
  if a.Mark == RFS_DirMark {

   
    if tsmap != nil {
      bok := secBitSet( tsmap, dpg )
      if ! bok {
	fmt.Println("Dir sector already marked:", dpg/29,"from",caller)
      }
    }

    if a.P0 != 0 { 
	fnames := RFS_Scan( disk, a.P0, tsmap ,"recursive")
	files = append( files, fnames...)
    }

    for n:=0;int32(n)<a.M;n++ {
      if a.E[n].Adr == 0 {
	fmt.Println("Found file with zero sector address in RFS_Scan with name",a.E[n].Name,"from",caller)
      }else{
      files=append(files,RFS_FI{string(a.E[n].Name[:FindNameEnd(a.E[n].Name[:])]),a.E[n].Adr})
      if tsmap != nil {
        bok := secBitSet(tsmap, a.E[n].Adr)
        if ! bok {
          fmt.Println("File Header sector already marked:", a.E[n].Adr/29,"from",caller)
        }
      }

      if tsmap != nil {
        var fh RFS_FileHeader
       
        ok:=RFS_K_GetFileHeader(disk, a.E[n].Adr, & fh,"Scan")
	if ! ok {
	  fmt.Println("Couldn't get file header")
	}else{
	  if fh.Sec[0] != a.E[n].Adr {
            fmt.Println("File Header First sector does not match file header sector:", a.E[n].Adr/29,"from",caller)
	  }else{
            for e:=1;(e<RFS_SecTabSize && e <= int(fh.Aleng));e++{
	      if e < RFS_SecTabSize {
                 if fh.Sec[e]!=0{
                     bok := secBitSet( tsmap, fh.Sec[e] )
                     if ! bok {
                          fmt.Println("File Contents sector already marked:", fh.Sec[e]/29,"from",caller)
                     }
                  }
	      }else{
                  xP:=(e-RFS_SecTabSize)/256
		  xPi:=(e-RFS_SecTabSize)%256
                  
		  if xPi == 0 {
                    sector = getSector(disk,fh.Ext[ xP ])
                    bok := secBitSet( tsmap, fh.Ext[ xP ] )
                    if ! bok {
                       fmt.Println("File extended sector already marked:", fh.Ext[xP]/29,"from",caller)
                    }
		  }
                  xe:=sector.DiskAdrAt(xPi)
                  bok := secBitSet( tsmap, xe )
                  if ! bok {
                     fmt.Println("File extended sector contents already marked:", xe/29,"from",caller)
                  }  

	      }

            }


          }
	}
      }


      if a.E[n].P != 0 {
	fnames :=  RFS_Scan(disk, a.E[n].P, tsmap,"recursive2")
        files=append(files, fnames...)
      }
      }
    }
    
    
  }else{
    fmt.Println("No Directory Signature:",dpg/29,"from",caller)
  }
  }
  return files
}


func ServeRFS( mountpoint *string, f *os.File, o uint32 ) {
	if *mountpoint != "-" {

	   fi, err := f.Stat()
	   if err != nil {
	     fmt.Println(err)
	   }else{

           go func() {
              sz := fi.Size()
	      fmt.Println("The volume is %d bytes", sz)

	      c, err := fuse.Mount(*mountpoint)
	      if err != nil { log.Fatal(err) }
	      defer c.Close()
	      if p := c.Protocol(); !p.HasInvalidate() {
		log.Panicln("kernel FUSE support is too old to have invalidations: version %v", p)
	      }


	      srv := fs.New(c, nil)

	      filesys := &RFS_FS{ &RFS_D{  inode: 29, disk: nil},f,o,sz,make(chan readOp),make(chan writeOp)}
	      filesys.root.disk=filesys

	      for i:=0;i<RFS_AllocMapLimit;i++{
	        smap[i]=0
	      }


              go RFS_K_Drive(filesys)

	      
	      _ = RFS_Scan( filesys, 29, &smap,"initialization" )

	      fmt.Println("Scan Complete")
	     
	      if err := srv.Serve(filesys); err != nil {
		log.Panicln(err)
	      }
	      <-c.Ready
	      if err := c.MountError; err != nil {
		log.Panicln(err)
	      }
	   }()
           }
	}
}
