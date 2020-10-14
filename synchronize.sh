#!/bin/bash
pushd .
cd root/doc
bash synchronize.sh
popd
for i in `ls -d root/src/github.com/io-core/*/`; do
       pushd .	
       cd $i
       bash synchronize.sh
       popd
done
git add images/io.img
git add root/doc
git add root/src/github.com/io-core/*
git commit -m 'sync local to master'
git push origin main
