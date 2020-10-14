#!/bin/bash
pushd .
cd root/doc
echo "at `pwd`"
bash gendocs.sh
bash pushup.sh
popd
git add root/doc
for i in `ls -d root/src/github.com/io-core/*/`; do
       pushd .	
       cd $i
       echo "at `pwd`"
       bash pushup.sh
       popd
       git add $i
done
git add images/io.img
git add root/src/Packages.Wrk
git add root/src/github.com/io-core/Packages.Wrk
git commit -m 'sync local to upstream'
git push origin
