#!/bin/bash

for i in `ls -d root/src/github.com/io-core/*/`; do
       pushd .	
       cd $i
       echo "at `pwd`"
       git checkout main
       popd       
done

for i in `ls -d root/src/github.com/charlesap/*/`; do
       pushd .	
       cd $i
       echo "at `pwd`"
       git checkout main
       popd       
done
