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
//	"context"
//	"os/signal"
	"os"
//	"os/exec"
	"io/ioutil"
//	"strings"
//	"strconv"
	"crypto"
	"crypto/rand"
	"crypto/sha256"
	"crypto/rsa"
//	"bytes"
	"golang.org/x/crypto/ssh"
	
)




func main() {
		
        inFilePtr := flag.String("i", "-", "input file")
        aMessagePtr := flag.String("a", "reviewed", "attest message")
        formatPtr := flag.String("f", "oberon", "attest comment style")

	flag.Parse()

	fmt.Println("hashing",&inFilePtr,"attesting",&aMessagePtr,"in",&formatPtr,"format")

	message := []byte("message to be signed")
	hashed := sha256.Sum256(message)

	pk, _ := ioutil.ReadFile(os.Getenv("HOME") + "/.ssh/id_rsa")
	signer, err := ssh.ParsePrivateKey(pk)
	s,_:=NewSignerFromSigner(signer)

	signature, err := rsa.SignPKCS1v15(rand.Reader, s, crypto.SHA256, hashed[:])
	if err != nil {
	    panic(err)
	}

	fmt.Println("signature is",signature)

}
