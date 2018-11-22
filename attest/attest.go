//
// Copyright © 2018 Charles Perkins
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
	"fmt"
//	"time"
	"flag"
	"os"
	"io/ioutil"
	"strings"
//	"strconv"
	"crypto"
	"crypto/rand"
	"crypto/sha256"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"encoding/base64"
)




func main() {
		
        inFilePtr := flag.String("i", "-", "input file")
        aMessagePtr := flag.String("a", "signed", "attest message")
        formatPtr := flag.String("f", "oberon", "attest comment style")
	pkeyPtr :=  flag.String("p", os.Getenv("HOME") + "/.ssh/id_rsa", "path to rsa private key file")
        bkeyPtr :=  flag.String("b", os.Getenv("HOME") + "/.ssh/id_rsa.pub", "path to rsa public key file")

	flag.Parse()

	fmt.Println("hashing",*inFilePtr,"attesting",*aMessagePtr,"in",*formatPtr,"format")

	message, _ := ioutil.ReadFile(*inFilePtr)  //[]byte("message to be signed")
	hashed := sha256.Sum256(message)
	
	pk, _ := ioutil.ReadFile(*pkeyPtr)
        bk, _ := ioutil.ReadFile(*bkeyPtr)
	bks:=strings.TrimSpace(string(bk))
        privPem, _ := pem.Decode(pk)
        privPemBytes := privPem.Bytes
	parsedKey, _ := x509.ParsePKCS1PrivateKey(privPemBytes)


	signature, err := rsa.SignPKCS1v15(rand.Reader, parsedKey, crypto.SHA256, hashed[:])
	if err != nil {
	    fmt.Println(err)
	}
        spaces:="                                                                                                    "
	encoded:=base64.StdEncoding.EncodeToString(signature)
        fmt.Println("(*----Attest-1.0.0------------------------------------------------------------------------*)")
        al:=strings.Split(*aMessagePtr,":")
	for _,v := range al{
		fmt.Println("(*",v,spaces[:85-len(v)],"*)")
	}
        fmt.Println("(*----------------------------------------------------------------------------------------*)")
        fmt.Println("(*",encoded[0:86],"*)\n(*",encoded[86:172],"*)\n(*",encoded[172:258],"*)\n(*",encoded[258:],"*)")
        fmt.Println("(*--------------------------------------------------------------------------------------  *)")
        fmt.Println("(*",bks[0:86],"*)\n(*",bks[86:172],"*)\n(*",bks[172:258],"*)\n(*",bks[258:344],"*)\n(*",bks[344:],spaces[:85-len(bks[344:])],"*)")
	fmt.Println("(*----------------------------------------------------------------------------------------*)")

}
