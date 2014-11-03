package Machine
import (
	"SYSTEM"
)
const (
     GPFSEL1 = 0x20200004
     GPSET0  = 0x2020001C
     GPCLR0  = 0x20200028
     GPPUD   = 0x20200094
     GPPUDCLK0 =   0x20200098
     AUXENABLES  =  0x20215004
     AUXMUIOREG  =  0x20215040
     AUXMUIERREG =  0x20215044
     AUXMUIIRREG =  0x20215048
     AUXMULCRREG =  0x2021504C
     AUXMUMCRREG =  0x20215050
     AUXMULSRREG =  0x20215054
     AUXMUMSRREG =  0x20215058
     AUXMUSCRATCH = 0x2021505C
     AUXMUCNTLREG = 0x20215060
     AUXMUSTATREG = 0x20215064
     AUXMUBAUDREG = 0x20215068

     SCREENX       = 1366 
     SCREENY       = 768 
     BITSPERPIXEL  = 1 

     VFPEnable = 0x40000000
     VFPSingle =   0x300000
     VFPDouble =  0x0C00000

     MBREAD  =  0x2000B880
     MBWRITE =  0x2000B8A0
     MBSTATUS = 0x2000B898

     MAILPOWER   = 0 
     MAILFB      = 1 
     MAILVUART   = 2 
     MAILVCHIQ   = 3 
     MAILLEDS    = 4 
     MAILBUTTONS = 5 
     MAILTOUCH   = 6 
     MAILCOUNT   = 7 
     MAILTAGS    = 8 
)
  type FBSTRUCT struct {
     PW int32
     PH int32
     VPW int32
     VPH int32
     PTCH int32
     BPP int32
     OFSX int32
     OFSY int32
     FBP int32
     FBS int32
  }
type FBSPTR *FBSTRUCT


func Init(){
}

func main(){ 
}