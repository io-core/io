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
}

func (f *RFS_FS) Root() (fs.Node, error) {
        return f.root, nil
}

//var inode uint64
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
        files := RFS_Scan(d.disk, RFS_DiskAdr(d.inode), nil)
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
	
	
        files := RFS_Scan(d.disk, RFS_DiskAdr(d.inode), nil)
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

   var smap RFS_AllocMap
   var slist []RFS_DiskAdr

   _ = RFS_Scan(d.disk, RFS_DiskAdr(d.inode), &smap)
   fmt.Println("smap len:",len(smap),"for",len(smap)*64,"sectors")
   
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
        //fmt.Println("done with",ith)
   }

   return slist
}


func (d *RFS_D) Create(ctx context.Context, req *fuse.CreateRequest, resp *fuse.CreateResponse) (fs.Node, fs.Handle, error) {

    var fserr error = fuse.EIO
    var attr = fuse.Attr{Inode: 0, Mode: 0777, Size: 0}

    fsn := &RFS_F{inode: 0,disk: d.disk}
    fmt.Println("Inserting File",req.Name)

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
		        fmt.Println("Inserting File",req.Name,"starting at sector id",nsec*29)
		        	
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

	//_ = fsn.Attr(ctx, &attr)

        //fmt.Println("create response:",resp)
    }
    //fsh, fserr := d.Lookup(ctx,req.Name)

    var smap RFS_AllocMap
    _ = RFS_Scan(d.disk,29,&smap)

    return fsn,fsn,fserr

//  PROCEDURE Insert*(name: FileName; fad: DiskAdr);
//    VAR  oldroot: DiskAdr;
//      h: BOOLEAN; U: DirEntry;
//      a: DirPage;
//  BEGIN h := FALSE;
//    insert(name, DirRootAdr, h, U, fad);
//    IF h THEN (*root overflow*)
//      Kernel.GetSector(DirRootAdr, a); ASSERT(a.mark = DirMark);
//      Kernel.AllocSector(DirRootAdr, oldroot); Kernel.PutSector(oldroot, a);
//      a.mark := DirMark; a.m := 1; a.p0 := oldroot; a.e[0] := U;
//      Kernel.PutSector(DirRootAdr, a)
//    END
//  END Insert;

	

//	f := &File{Node: Node{name: req.Name, inode: NewInode()}}
//	files := []*File{f}
//	if d.files != nil {
//		files = append(files, *d.files...)
//	}
//	d.files = &files
//	return f, f, nil

    //fsh, fserr := d.Lookup(ctx,req.Name)
    //fsn = d
    //return fsn,fsh,fserr
    //return fsn,resp,fserr
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
        RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh)


        ecount:=0
        for i:=0;i<12;i++{
          if fh.Ext[i]!=0 { ecount++ }
        }
        scount:=0
        for i:=0;i<64;i++{
          if fh.Sec[i]!=0 { scount++ }
        }
        a.Size = (uint64(fh.Aleng) * RFS_SectorSize) + uint64(fh.Bleng) - RFS_HeaderSize
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
        RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh)
        var rv []byte

          for i:=0;i<=int(fh.Aleng);i++{
           if fh.Sec[i]>0 {
            fsec := RFS_K_Read(f.disk,fh.Sec[i])
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
        return rv, nil
}

func (f *RFS_F) Write(ctx context.Context, req *fuse.WriteRequest, resp *fuse.WriteResponse) error {

        var fserr error
        fserr = fuse.EIO

        var fh RFS_FileHeader
        RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh)
        
	if fh.Sec[0]==0{
		fmt.Println("File header self-sector is zero for f.inode",f.inode)
	}
       
        appendOp := (req.FileFlags & fuse.OpenAppend) > 0
	
        fsec := RFS_K_Read(f.disk,fh.Sec[0])

        osz:=int32(0)          
        if appendOp {
		osz = (fh.Aleng * RFS_SectorSize) + fh.Bleng - RFS_HeaderSize
        }

        newl := osz + int32(len(req.Data))
	origAleng := fh.Aleng
	origBleng := fh.Bleng
        newAleng := (newl + RFS_HeaderSize) / RFS_SectorSize
	newBleng := (newl + RFS_HeaderSize) % RFS_SectorSize

        if newAleng > 63 {
		newAleng = 63
	}

	fmt.Println("Write operation begin")

	if origAleng < newAleng {
                
                
        	slist := RFS_FindNFreeSectors(int(newAleng-origAleng), f.disk.root)
                
        	if len(slist)!=int(newAleng-origAleng){
        	        fmt.Println("Failed to find",newAleng-origAleng,"free sector(s) for the file")
        	}else{
                        fmt.Println("found sector(s)",slist,"for the file")
			for i:=origAleng+1;i<=newAleng;i++{
                                if i < int32(len(fh.Sec)){
				  fh.Sec[i]=slist[i-(origAleng+1)]*29
				}else{
				  fmt.Println("Sec has",len(fh.Sec),"but need",i)
				}
				fsec.PutWordAt(int(24+i),uint32(slist[i-(origAleng+1)])*29)
			}
        	}

                
	}else if origAleng > newAleng{
                fmt.Println("Have too many sectors... trimming!")
	}

        rc:= int32(0)
	for seqn:= int32(0); seqn <= newAleng ; seqn ++ {
		if seqn == 0 || seqn >= int32( rc + osz + RFS_HeaderSize )/ RFS_SectorSize {
	                if seqn > 0 {
	                        fsec = RFS_K_Read(f.disk,fh.Sec[seqn])
	                }else{
                                fh.Aleng = int32(newAleng)
                                fh.Bleng = int32(newBleng)
                                
                                fsec.PutWordAt(9,uint32(fh.Aleng))
                                fsec.PutWordAt(10,uint32(fh.Bleng))
			}
			if seqn==0 && ((osz + RFS_HeaderSize)/RFS_SectorSize) == 0 {
				for i:=int32(0); i < (RFS_SectorSize - (osz+RFS_HeaderSize)) &&  rc < int32(len(req.Data)) ; i++ {
					fsec[ (osz+RFS_HeaderSize) + i ] = req.Data[ rc ]
                                	rc = rc + 1
				}
			}
                        if seqn > 0 && appendOp && seqn == origAleng {
                                for i:=int32(0); i < (RFS_SectorSize - origBleng) &&  rc < int32(len(req.Data)) ; i++ {
                                        fsec[ origBleng + i ] = req.Data[ rc ]
                                        rc = rc + 1
                                }
			} else if seqn > 0 {
                                for i:=int32(0); i < RFS_SectorSize &&  rc < int32(len(req.Data)) ; i++ {
                                        fsec[ i ] = req.Data[ rc ] 
                                        rc = rc + 1
                                }
			}
			fmt.Println("Writing chunk",seqn,"to sector",fh.Sec[seqn]/29)
                        RFS_K_Write( f.disk, fh.Sec[seqn], fsec)
		}
                    
        }
	resp.Size = len(req.Data)
        fserr = nil
        
        fmt.Println("Write operation end. fh original Aleng:",fh.Aleng,"write request flags:",req.FileFlags,"Size:",len(req.Data),"Error:",fserr)
        return fserr   
}

func (f *RFS_F) Flush(ctx context.Context, req *fuse.FlushRequest) error {      return nil   }

func (f *RFS_F) Open(ctx context.Context, req *fuse.OpenRequest, resp *fuse.OpenResponse) (fs.Handle, error) {	return f, nil   }

func (f *RFS_F) Release(ctx context.Context, req *fuse.ReleaseRequest) error {  return nil   }
func (f *RFS_F) Fsync(ctx context.Context, req *fuse.FsyncRequest) error {      return nil   }

const RFS_FnLength    = 32
const RFS_SecTabSize   = 64
const RFS_ExTabSize   = 12
const RFS_SectorSize   = 1024
const RFS_IndexSize   = 256    //SectorSize / 4
const RFS_HeaderSize  = 352
const RFS_DirRootAdr  = 29
const RFS_DirPgSize   = 24
const RFS_N = 12               //DirPgSize / 2
const RFS_DirMark    = 0x9B1EA38D
const RFS_HeaderMark = 0x9BA71D86
const RFS_FillerSize = 52
const RFS_NUMSECTORS = 1220   // RISC.img size / 1024

type 	RFS_AllocMap	[ RFS_NUMSECTORS / 64 ]uint64

type    RFS_DiskAdr         int32
type    RFS_FileName       [RFS_FnLength]byte
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

func RFS_K_Write( disk *RFS_FS, dpg RFS_DiskAdr, sbuf []byte) {

    RFS_Aquire()
    if len(sbuf)==1024{

      x:=(dpg/29)+262144
      _,err := disk.file.Seek( (int64(x)*1024) - int64(disk.offset*512),0 )
      if err!= nil {    fmt.Println("Disk Seek Errorin Write --->",err,"address",(int64(x)*1024),"offset",int64(disk.offset*512),"page",dpg/29)      }

//func (board *BOARD) write_sector(){
//  bytes:=make([]byte, 512)
//  for i := 0; i < 128; i++ {
//    bytes[i*4+0] = uint8(board.Disk.rx_buf[i]      )
//    bytes[i*4+1] = uint8(board.Disk.rx_buf[i] >>  8)
//    bytes[i*4+2] = uint8(board.Disk.rx_buf[i] >> 16)
//    bytes[i*4+3] = uint8(board.Disk.rx_buf[i] >> 24)
//  }
//  board.Disk.File.Write(bytes)
//}

     disk.file.Write(sbuf)
   }else{
	fmt.Println("Bad file write sector buffer size")
   }
   RFS_Release()
}

func RFS_K_Read( disk *RFS_FS, dpg RFS_DiskAdr) sbuf {

     RFS_Aquire()

      x:=(dpg/29)+262144
      _,err := disk.file.Seek( (int64(x)*1024) - int64(disk.offset*512),0 )
      if err!= nil {    fmt.Println("Disk Seek Error in Read --->",err,"address",(int64(x)*1024),"offset",int64(disk.offset*512),"page",dpg/29)      }
      bytes := make([]byte, 1024)
      _,err = disk.file.Read(bytes)
      if err!= nil {        fmt.Println("Disk Read Error",err,x)      }

     RFS_Release()

      return sbuf(bytes)
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
        
        fmt.Println("writing file header sector",dpg/29)
	RFS_K_Write( disk, dpg, sector )

}

func RFS_K_GetFileHeader( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_FileHeader){

      sector := RFS_K_Read( disk, dpg )

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
      }else{
	fmt.Println("sector",dpg,"has no header mark in GetFileHeader")
      }
}

func RFS_K_PutDirSector( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_DirPage){

        sector := sbuf(make([]byte, 1024))

        sector.PutWordAt(0,a.Mark)
        sector.PutWordAt(1,uint32(a.M))
        sector.PutWordAt(2,uint32(a.P0))

   if a.Mark == RFS_DirMark {

      for e := 0; int32(e)<a.M;e++{
          i := 16 + (e*10)
          for x:=0;x<32;x++ {
            sector[(i*4)+x]=a.E[e].Name[x]
          } 
          sector.PutWordAt(i+8,uint32(a.E[e].Adr))  
          sector.PutWordAt(i+9,uint32(a.E[e].P))  
      }

      fmt.Println("writing directory sector",dpg/29)
      RFS_K_Write( disk, dpg, sector )

   }
}

func RFS_K_GetDirSector( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_DirPage){

      sector := RFS_K_Read( disk, dpg )

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

//          fmt.Println("Preparing directory entry for insert")

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
//            fmt.Println("bounce to", dpg1/29)
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
		fmt.Println("directory entry inserted")
	    }else{ // split page and assign the middle element to v
                fmt.Println("splitting directory page")
 
//          a.m := N; a.mark := DirMark;
//          IF R < N THEN (*insert in left half*)
//            v := a.e[N-1]; i := N-1;
//            WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END ;
//            a.e[R] := u; Kernel.PutSector(dpg0, a);
//            Kernel.AllocSector(dpg0, dpg0); i := 0;
//            WHILE i < N DO a.e[i] := a.e[i+N]; INC(i) END
//          ELSE (*insert in right half*)
//            Kernel.PutSector(dpg0, a);
//            Kernel.AllocSector(dpg0, dpg0); DEC(R, N); i := 0;
//            IF R = 0 THEN v := u
//            ELSE v := a.e[N];
//              WHILE i < R-1 DO a.e[i] := a.e[N+1+i]; INC(i) END ;
//              a.e[i] := u; INC(i)
//            END ;
//            WHILE i < N DO a.e[i] := a.e[N+i]; INC(i) END
//          END ;
//          a.p0 := v.p; v.p := dpg0

            }
            RFS_K_PutDirSector(disk,dpg0,&a)
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

func secBitSet( smap *RFS_AllocMap, dpg RFS_DiskAdr){
    if smap != nil {
        s:=dpg/29
        e:=s/64
        r:=s%64
//      if e >= len(*smap){
//        fmt.Printf("Sector mark beyond end of sector bitmap\n")
//      }else{
          smap[e] = smap[e] | (1<<uint(r))
//      }
    }

}


func RFS_Scan(disk *RFS_FS, dpg RFS_DiskAdr, smap *RFS_AllocMap ) []RFS_FI {

    var a RFS_DirPage
    var files []RFS_FI

    fmt.Print("<",dpg)

    RFS_K_GetDirSector(disk, dpg, & a)

    secBitSet( smap, dpg )

    if a.P0 != 0 { 
	fnames := RFS_Scan( disk, a.P0, smap )
	files = append( files, fnames...)
    }

    for n:=0;int32(n)<a.M;n++ {
      if a.E[n].Adr == 0 {
	fmt.Println("Found file with zero sector address in RFS_Scan with name",a.E[n].Name)
      }else{
      files=append(files,RFS_FI{string(a.E[n].Name[:FindNameEnd(a.E[n].Name[:])]),a.E[n].Adr})
      secBitSet(smap, a.E[n].Adr)
      if smap != nil {
        var fh RFS_FileHeader
        RFS_K_GetFileHeader(disk, a.E[n].Adr, & fh)
	  for e:=0;(e<RFS_SecTabSize && e <= int(fh.Aleng));e++{
                if fh.Sec[e]!=0{
	  	   secBitSet( smap, fh.Sec[e] )
		}
	  }
          for e:=0;e<RFS_ExTabSize;e++{
		if fh.Ext[e]!=0{
		   fmt.Println("Can't handle an ext entry in a file handle! Egads!")
		}
	  }
      }


      if a.E[n].P != 0 {
	fnames :=  RFS_Scan(disk, a.E[n].P, smap)
        files=append(files, fnames...)
      }
      }
    }
    fmt.Print(">")

    return files
}


func ServeRFS( mountpoint *string, f *os.File, o uint32 ) {
	if *mountpoint != "-" {

	   go func() {

	      c, err := fuse.Mount(*mountpoint)
	      if err != nil { log.Fatal(err) }
	      defer c.Close()
	      if p := c.Protocol(); !p.HasInvalidate() {
		log.Panicln("kernel FUSE support is too old to have invalidations: version %v", p)
	      }
	      srv := fs.New(c, nil)
	      filesys := &RFS_FS{ &RFS_D{  inode: 29, disk: nil},f,o}
	      filesys.root.disk=filesys
	     

	      log.Println("About to serve fs")
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
