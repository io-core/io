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
	"time"
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

	cl:="(*"
	cr:="*)"
	if *formatPtr == "go" || *formatPtr == "c" {
        	cl="//"
        	cr="//"
	}
        if *formatPtr == "bash" || *formatPtr == "csharp" {
                cl=" #"
                cr="# "
        }
	
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
	now := fmt.Sprint(time.Now().Format("2006-01-02 15:04:05"))
        spaces:="                                                                                                    "
	encoded:=base64.StdEncoding.EncodeToString(signature)
        fmt.Println(cl+"----Attest-1.0.0------------------------------------------------------------------------"+cr)
        al:=strings.Split(*aMessagePtr,":")
	for _,v := range al{
		fmt.Println(cl,v,spaces[:85-len(v)],cr)
	}
	fmt.Println(cl,now,spaces[:85-len(now)],cr)
        fmt.Println(cl+"----------------------------------------------------------------------------------------"+cr)
        fmt.Println(cl,encoded[0:86],cr+"\n"+cl,encoded[86:172],cr+"\n"+cl,encoded[172:258],cr+"\n"+cl,encoded[258:],cr)
        fmt.Println(cl+"----------------------------------------------------------------------------------------"+cr)
        fmt.Println(cl,bks[0:86],cr+"\n"+cl,bks[86:172],cr+"\n"+cl,bks[172:258],cr+"\n"+cl,bks[258:344],cr+"\n"+cl,bks[344:],spaces[:85-len(bks[344:])],cr)
        fmt.Println(cl+"----------------------------------------------------------------------------------------"+cr)
}
