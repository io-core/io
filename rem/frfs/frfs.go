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
        a chan sallocOp
	m chan smarkOp
        f chan sfreeOp
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
        files := RFS_Scan(d.disk, RFS_DiskAdr(d.inode), false,"Lookup")
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
	
        files := RFS_Scan(d.disk, RFS_DiskAdr(d.inode), false,"ReadDirAll")
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
	
	nsec := allocSector(d.disk) * 29
	fhdr.Sec[0]=RFS_DiskAdr(nsec)

	fsn.inode=uint64(nsec)
	attr.Inode=uint64(nsec)
	resp.Node=fuse.NodeID(nsec)
	//resp.Generation=1
	//resp.EntryValid=0
	resp.Attr=attr
	//resp.Handle=fuse.HandleID(nsec)
	//resp.Flags=0

	RFS_K_PutFileHeader( d.disk, RFS_DiskAdr(nsec), &fhdr)

	//h:=false
	h,U := RFS_Insert(d.disk, req.Name, RFS_DirRootAdr,RFS_DiskAdr(nsec) )
	if h {  // root overflow
		fmt.Println("overflow, ascending at entry",U)
	}else{
		fserr = nil
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

      if saneDiskAdr(RFS_DiskAdr(f.inode), "ReadAll file header"){
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
		    sector := getSector(f.disk,fh.Ext[xte])
		    sn=sector.DiskAdrAt(int(xti))
		}
		if saneDiskAdr(sn,"ReadAll file content sector") {
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



func allocateFileSectors(disk *RFS_FS, fh RFS_FileHeader, hx HADJ) (RFS_FileHeader, error) {
        var fserr error = nil
        var xsec sbuf = make([]byte,1024)

        if hx.oA < hx.nA {
                
                oxA:=hx.oA+1-RFS_SecTabSize; if oxA < 0 { oxA = 0 }
                nxA:=hx.nA+1-RFS_SecTabSize; if nxA < 0 { nxA = 0 }

		xsn:=RFS_DiskAdr(0)

		for i:=hx.oA+1;i<=hx.nA;i++{
			if i < RFS_SecTabSize {
			  fh.Sec[i]=allocSector(disk)*29 
			}else{

			  //fmt.Print("!")
			  xi := i - RFS_SecTabSize
			  xiP := xi / 256
			  xiPi := xi % 256
			  
			  if i == hx.oA+1 && xiPi !=0 {
				xsn=fh.Ext[xiP]
				xsec = getSector(disk,xsn)
			  }

			  if xiPi == 0 {
				xsn=allocSector(disk)*29    
				fh.Ext[xiP]=xsn
				for j:=0;j<256;j++{
				    xsec.PutWordAt(j,uint32(0))
				}    
			  }


			  xsec.PutWordAt(int(xiPi),uint32( allocSector(disk)*29)) 
			  
			  if xiPi == 255 || i == hx.nA {
				putSector(disk,xsn,xsec)
			  }

			}
		}

        }else if hx.oA > hx.nA{
                fmt.Println("Have too many sectors... ignoring extra")
        }

        checkFileHeaderSectors(disk,fh,hx)

	return fh, fserr
}

func checkFileHeaderSectors(disk *RFS_FS, fh RFS_FileHeader, hx HADJ){

	var lseqn,lxi,lxiP,lxiPi int
	var lfhe,lsn RFS_DiskAdr

	for i:=0;i<RFS_SecTabSize;i++{
		if i <= int(hx.nA) {
		_ = saneDiskAdr(fh.Sec[i],"checking file header sector table entry")
		}
	}

        for i:=0;i<RFS_ExTabSize*256;i++{
		seqn:=i+RFS_SecTabSize
		if seqn <= int(hx.nA) {
			xi:= seqn - RFS_SecTabSize
                	xiP:=xi / 256
                        xiPi:=xi % 256
                	_ = saneDiskAdr(fh.Ext[xiP],"checking file header Extended table entry")
			xsec:=getSector(disk,fh.Ext[xiP])
			//if xiP == 1 && xiPi == 0 { fmt.Print("boing....") }
			sn:=xsec.DiskAdrAt(int(xiPi))
                        _ = saneDiskAdr(sn,"checking file header Extended table file sector entry")
                        
			lseqn=seqn
			lxi=xi
			lxiP=xiP
			lxiPi=xiPi
			lfhe=fh.Ext[xiP]
			lsn=sn
		}
		
        }
	if 1==2 {
	  fmt.Print("(seqn is ",lseqn," xi is ",lxi," xiP is ",lxiP," xiPi is ",lxiPi," fhe is ",lfhe/29," sn is ",lsn/29,")")
	}

}


func writeToFile(disk *RFS_FS, fh RFS_FileHeader, hx HADJ, data []byte) (RFS_FileHeader, error) {
        var fserr error = fuse.EIO
        var fsec sbuf
        

        rc:= int32(0)
        
        //fmt.Print("{")
        for seqn:= int32(0); seqn <= hx.nA; seqn ++ {
                sn := RFS_DiskAdr(0)
                if seqn < RFS_SecTabSize {
                   
		    sn = fh.Sec[seqn]                    
                }else{
                    xi := seqn - RFS_SecTabSize
                    xiP := xi / 256
                    xiPi := xi % 256
                    _ = saneDiskAdr(fh.Ext[xiP],"2checking file header Extended table entry")
                    xsec:=getSector(disk,fh.Ext[xiP])
                    
                    sn=xsec.DiskAdrAt(int(xiPi))

		    if sn % 29 != 0 { fmt.Println("\nseqn is",seqn,"xi is",xi,"xiP is",xiP,"xiPi is",xiPi,"fhe is",fh.Ext[xiP]/29,"sn is",sn)}
                    _ = saneDiskAdr(sn,"2checking file header Extended table file sector entry")

                }
                if seqn == 0 || seqn >= int32( rc + hx.osz + RFS_HeaderSize )/ RFS_SectorSize {
                        if seqn > 0 {
                                fsec = getSector(disk,sn)
                        }

                        if seqn==0 && ((hx.osz + RFS_HeaderSize)/RFS_SectorSize) == 0 {
                                for i:=int32(0); i < (RFS_SectorSize - (hx.osz+RFS_HeaderSize)) &&  rc < int32(len(data)) ; i++ {
					fh.fill[ hx.osz + i ] = data[ rc ]
                                        rc = rc + 1
                                }
                        }
                        if seqn > 0 && seqn == hx.oA {  // seqn > 0 && hx.isAppend==1 && seqn == hx.oA 
                                for i:=int32(0); i < (RFS_SectorSize - hx.oB) &&  rc < int32(len(data)) ; i++ {
                                        fsec[ hx.oB + i ] = data[ rc ]
                                        rc = rc + 1
                                }
                        } else if seqn > 0 {
                                for i:=int32(0); i < RFS_SectorSize  &&  rc < int32(len(data)) ; i++ {
                                        fsec[ i ] = data[ rc ]
                                        rc = rc + 1
                                }
                        }
			if seqn > 0 {
                        	rsp := make(chan bool)
                        	disk.w <- writeOp{sn, fsec, rsp}
                        	_ = <- rsp
			}
                }

        }
        
        fh.Aleng = int32(hx.nA)
        fh.Bleng = int32(hx.nB)

        fserr = nil
        //fmt.Print("}")

	return fh, fserr
}

type HADJ struct {
        osz, nsz, oA, oB, nA, nB, isAppend, offset, dlen int32
}

func calcAdjust(offset int64, oA int32, oB int32, dlen int, ff fuse.OpenFlags) HADJ {
	var hx HADJ

	hx.isAppend = int32(fuse.OpenFlags(ff) & fuse.OpenAppend)/int32(fuse.OpenAppend)
        hx.osz = int32(offset) + (hx.isAppend * ((oA * RFS_SectorSize) + oB - RFS_HeaderSize))
        hx.nsz = hx.osz + int32(dlen)
	hx.oA = oA
	hx.oB = oB
        hx.nA = (hx.nsz + RFS_HeaderSize) / RFS_SectorSize
        hx.nB = (hx.nsz + RFS_HeaderSize) % RFS_SectorSize
	hx.offset = int32(offset)
	hx.dlen = int32(dlen)

	return hx
}

func (f *RFS_F) Write(ctx context.Context, req *fuse.WriteRequest, resp *fuse.WriteResponse) error {
        var fserr error = nil
        var fh RFS_FileHeader

        ok:=RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh, "Write" )

        if ! (ok && saneDiskAdr(fh.Sec[0], "File Header Self Sector")) {
                os.Exit(1)
        }

	hx := calcAdjust(req.Offset,fh.Aleng,fh.Bleng,len(req.Data),req.FileFlags)

        if ((hx.nA - RFS_SecTabSize)/256) > RFS_ExTabSize {
          fmt.Println("File too large for risc file system")
          fserr = fuse.EIO
        }


        if fserr == nil {
		fh, fserr = allocateFileSectors(f.disk, fh, hx)
	}

	if fserr == nil {
		fh, fserr = writeToFile(f.disk, fh, hx, req.Data)
	}

	if fserr == nil {
		resp.Size = len(req.Data)
		RFS_K_PutFileHeader( f.disk, RFS_DiskAdr(f.inode), &fh)
	}

	return fserr
}



func (f *RFS_F) Flush(ctx context.Context, req *fuse.FlushRequest) error {      return nil   }

func (f *RFS_F) Open(ctx context.Context, req *fuse.OpenRequest, resp *fuse.OpenResponse) (fs.Handle, error) {	return f, nil   }

func (f *RFS_F) Release(ctx context.Context, req *fuse.ReleaseRequest) error {  return nil   }

func (f *RFS_F) Fsync(ctx context.Context, req *fuse.FsyncRequest) error {      return nil   }

// 32-bit oberon file system  141.2 GiB Max Volume          // 64-bit oberon filesystem   2 ZiB Max Volume
const RFS_FnLength    = 32                                  // 127 + a zero byte = 128
const RFS_SecTabSize  = 64                                  // 64 -- 64-bit integers mod 29
const RFS_ExTabSize   = 12  //64+12*256 = 3MB max file size // 64 + 12*512 + 16*512*512 + 16*512*512*512 = 16 TiB max file size
const RFS_SectorSize  = 1024                                // 4096
const RFS_IndexSize   = 256    //SectorSize / 4             // 512  -- SectorSize / 8
const RFS_HeaderSize  = 352                                 // ??
const RFS_DirRootAdr  = 29                                  // 29
const RFS_DirPgSize   = 24                                  // 24
const RFS_N = 12               //DirPgSize / 2              // 12
const RFS_DirMark    = 0x9B1EA38D                           // 0x9B1EA38E
const RFS_HeaderMark = 0x9BA71D86                           // 0x9BA71D87
//  RFS_MERKLEHASH                                          // SHA256 hash of: filenames + hashes of file contents of all files in directory
const RFS_FillerSize = 52                                   // ??

var rfs_numsectors = 1220   // RISC.img size / 1024

//const   RFS_AllocMapLimit = 9256395
//type 	RFS_AllocMap	[RFS_AllocMapLimit]uint64   // 9.2 MiB for a bit for every possible sector on a maximally sized disk

//var smap RFS_AllocMap

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


type sallocOp struct {
	c chan RFS_DiskAdr
}

type smarkOp struct {
	i RFS_DiskAdr
	c chan bool
}

type sfreeOp struct {
        i RFS_DiskAdr
        c chan bool
}


func allocSector(disk *RFS_FS) RFS_DiskAdr {
        rsp := make(chan RFS_DiskAdr)
        disk.a <- sallocOp{rsp}
        adr := <- rsp
       
        return adr
}

func markSector(disk *RFS_FS, adr RFS_DiskAdr){
        rsp := make(chan bool) 
        disk.m <- smarkOp{adr, rsp}
        _ = <- rsp
}

func freeSector(disk *RFS_FS, adr RFS_DiskAdr){
        rsp := make(chan bool)
        disk.f <- sfreeOp{adr, rsp}
        _ = <- rsp
}


func RFS_Smap( disk *RFS_FS ){

	const   RFS_AllocMapLimit = 9256395
	type    RFS_AllocMap    [RFS_AllocMapLimit]uint64   // 9.2 MiB for a bit for every possible sector on a maximally sized disk
	
	var smap RFS_AllocMap
	var startat int

        for i:=0;i<RFS_AllocMapLimit;i++{
                smap[i]=0
        }
	startat = 0

        for ;; {
                select{

                case allocit := <- disk.a :
		   	found:=0
			nsec:=0
		  	for i:=startat; i<len(smap) && found == 0; i++{
		  	         if i > 0 && smap[i] != 0xffffffffffffffff {
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
		   	                     nsec=(found*64) + fbit
					     fmt.Print(" ",nsec*29)
		   	                     smap[found]=smap[found] | (1 << uint(fbit) )
		   	                    
		   	         }
		   	}
                        allocit.c <- RFS_DiskAdr(nsec)
			
                
                case markit := <- disk.m :
			fmt.Print(" ",markit.i)
		        s:=markit.i/29
		        if (markit.i % 29) != 0 { fmt.Printf("DiskAdr ",markit.i," not evenly divisible by 29 in markit!\n")}
		        e:=s/64
		        r:=s%64
		        if smap[e] & (1<<uint(r)) != 0 {
		                fmt.Println("sector already allocated in scan:", markit.i/29)
		        }else{
		                smap[e] = smap[e] | (1<<uint(r))
		        }
                        markit.c <- true
                        
                case freeit := <- disk.f :
                        s:=freeit.i/29
                        if (freeit.i % 29) != 0 { fmt.Printf("DiskAdr ",freeit.i," not evenly divisible by 29 in freeit!\n")}
                        e:=s/64
                        r:=s%64
			smap[e] = smap[e] & ( 0xFFFFFFFF - (1<<uint(r)))
			if startat < int(freeit.i) / 64 {
				startat = int(freeit.i) / 64
			}
                        freeit.c <- true 
                        fmt.Println("Freeing",freeit.i)

                }
        }

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
                
                        nsec := allocSector(disk)*29    //slist[1]*29
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


func RFS_Scan(disk *RFS_FS, dpg RFS_DiskAdr, makemap bool, caller string ) []RFS_FI {

  var a RFS_DirPage
  var files []RFS_FI
  var sector sbuf

  if saneDiskAdr(dpg,"Scan") {
    RFS_K_GetDirSector(disk, dpg, & a)
    if a.Mark == RFS_DirMark {
   
      if makemap {
	markSector( disk, dpg )
      }

      if a.P0 != 0 { 
	fnames := RFS_Scan( disk, a.P0, makemap ,"recursive")
	files = append( files, fnames...)
      }

      for n:=0; int32(n)<a.M; n++ {
        if saneDiskAdr( a.E[n].Adr, "file head sector address"){
          files=append(files,RFS_FI{string(a.E[n].Name[:FindNameEnd(a.E[n].Name[:])]),a.E[n].Adr})

          if makemap {
            markSector(disk, a.E[n].Adr)
            var fh RFS_FileHeader
       
            _=RFS_K_GetFileHeader(disk, a.E[n].Adr, & fh,"Scan")

	    if fh.Sec[0] != a.E[n].Adr {
              fmt.Println("File Header First sector does not match file header sector:", a.E[n].Adr/29,"from",caller)
	    }else{
              for e:=1; e <= int(fh.Aleng);e++{
	        if e < RFS_SecTabSize {
                  if fh.Sec[e]!=0{
                     markSector( disk, fh.Sec[e] )
                  }
	        }else{
                  xP:=(e-RFS_SecTabSize)/256
		  xPi:=(e-RFS_SecTabSize)%256     
		  if xPi == 0 {
		    if saneDiskAdr(fh.Ext[xP],"Extended Sector in Scan"){
                      sector = getSector(disk, fh.Ext[ xP ])
                      markSector( disk, fh.Ext[ xP ] )
		    }
		  }
                  xe:=sector.DiskAdrAt(xPi)
		  if saneDiskAdr( xe ,"extended sector file page"){
                    markSector( disk, xe )
		  }
	        }
              }      
	    }
          }

          if a.E[n].P != 0 {
	    fnames :=  RFS_Scan(disk, a.E[n].P, makemap, "recursive2")
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

	      filesys := &RFS_FS{ &RFS_D{  inode: 29, disk: nil},f,o,sz,make(chan readOp),make(chan writeOp),make(chan sallocOp),make(chan smarkOp),make(chan sfreeOp)}
	      filesys.root.disk=filesys

              go RFS_Smap(filesys)
              go RFS_K_Drive(filesys)

	      
	      _ = RFS_Scan( filesys, 29, true, "initialization" )

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
