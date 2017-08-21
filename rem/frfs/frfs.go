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

var inode uint64

type RFS_D struct {
        inode uint64
	disk *RFS_FS
}

func (d *RFS_D) Attr(ctx context.Context, a *fuse.Attr) error {
        a.Inode = d.inode
        a.Mode = os.ModeDir | 0444
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

func (d *RFS_D) Create(ctx context.Context, req *fuse.CreateRequest, resp *fuse.CreateResponse) (fs.Node, fs.Handle, error) {

	fmt.Println("Creating File",req.Name)

	var smap RFS_AllocMap 

        _ = RFS_Scan(d.disk, RFS_DiskAdr(d.inode), &smap)

//	f := &File{Node: Node{name: req.Name, inode: NewInode()}}
//	files := []*File{f}
//	if d.files != nil {
//		files = append(files, *d.files...)
//	}
//	d.files = &files
//	return f, f, nil

	return nil,nil,fuse.ENOSYS  
}

func (d *RFS_D) Remove(ctx context.Context, req *fuse.RemoveRequest) error          {   return fuse.ENOSYS       }

func (d *RFS_D) Mkdir(ctx context.Context, req *fuse.MkdirRequest) (fs.Node, error) {   return nil, fuse.ENOSYS  }

type RFS_F struct {
        inode uint64
	disk *RFS_FS
}

func (f *RFS_F) Attr(ctx context.Context, a *fuse.Attr) error {
        a.Inode = f.inode
        a.Mode = 0555

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

func (f *RFS_F) Read(ctx context.Context, req *fuse.ReadRequest, resp *fuse.ReadResponse) error {
        fuseutil.HandleRead(req, resp, nil)
        return nil
}

func (f *RFS_F) ReadAll(ctx context.Context) ([]byte, error) {

        var fh RFS_FileHeader
        RFS_K_GetFileHeader(f.disk, RFS_DiskAdr(f.inode), & fh)
        var rv []byte

          for i:=0;i<=int(fh.Aleng);i++{
            fsec := RFS_K_Read(f.disk,fh.Sec[i])
            if i==0 {
                  if fh.Aleng==0 {
                    rv = append(rv,fsec[352:fh.Bleng]...)
                  }else{
                    rv = append(rv,fsec[352:]...)
                  }
            }
            if i > 0 && i < int(fh.Aleng) {
                  rv = append(rv,fsec...)
            }
            if i > 0 && i == int(fh.Aleng) {
                  rv = append(rv,fsec[:fh.Bleng]...)
            }
        } 
        return rv, nil
}

func (f *RFS_F) Write(ctx context.Context, req *fuse.WriteRequest, resp *fuse.WriteResponse) error {    return fuse.ENOSYS   }
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
type    RFS_SectorTable    [RFS_SecTabSize]RFS_DiskAdr
type    RFS_ExtensionTable [RFS_ExTabSize]RFS_DiskAdr
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

func RFS_K_Read( disk *RFS_FS, dpg RFS_DiskAdr) sbuf {

     RFS_Aquire()

      x:=(dpg/29)+262144
      _,err := disk.file.Seek( (int64(x)*1024) - int64(disk.offset*512),0 )
      if err!= nil {    fmt.Println("Disk Seek Error --->",err,"address",(int64(x)*1024),"offset",int64(disk.offset*512),"page",dpg/29)      }
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

func RFS_K_GetFileHeader( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_FileHeader){

      sector := RFS_K_Read( disk, dpg )

      a.Mark =sector.Uint32At(0)

      if a.Mark == 0x9BA71D86 {
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
//       a.Sec[0]=dpg

         for i:=0;i<RFS_SectorSize - RFS_HeaderSize;i++{
           a.fill[i]=sector[i+RFS_HeaderSize]
         }
      }
}
func RFS_K_GetDirSector( disk *RFS_FS, dpg RFS_DiskAdr, a * RFS_DirPage){

      sector := RFS_K_Read( disk, dpg )

      a.Mark =sector.Uint32At(0)
      a.M    =sector.Int32At(1)
      a.P0   =sector.DiskAdrAt(2)

   if a.Mark==0x9b1ea38d {

      for e := 0; int32(e)<a.M;e++{
          i := 16 + (e*10)
          for x:=0;x<32;x++ {
            a.E[e].Name[x]=sector[i*4+x]
          }
          a.E[e].Adr = sector.DiskAdrAt(i+8)
          a.E[e].P   = sector.DiskAdrAt(i+9)
      }
    }


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

func RFS_Scan(disk *RFS_FS, dpg RFS_DiskAdr, smap *RFS_AllocMap ) []RFS_FI {

    var a RFS_DirPage
    var files []RFS_FI

    RFS_K_GetDirSector(disk, dpg, & a)
    if a.P0 != 0 { 
	fnames := RFS_Scan( disk, a.P0, smap )
	files = append( files, fnames...)
    }

    for n:=0;int32(n)<a.M;n++ {
      files=append(files,RFS_FI{string(a.E[n].Name[:FindNameEnd(a.E[n].Name[:])]),a.E[n].Adr})
      if a.E[n].P != 0 {
	fnames :=  RFS_Scan(disk, a.E[n].P, smap)
        files=append(files, fnames...)
      }
    }
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
