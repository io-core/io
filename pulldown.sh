#!/bin/bash
pushd .
cd root/doc
echo "at `pwd`"
git pull
popd
for i in `ls -d root/src/github.com/io-core/*/`; do
       pushd .	
       cd $i
       echo "at `pwd`"
       git pull
       popd
done
git pull
