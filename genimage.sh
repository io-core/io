#!/bin/bash

oxlines=`oxfstool -h 2>&1 | wc -l`
if [ $oxlines -gt 10 ]; then 
  rm -rf work
  mkdir work
  cd work
  for i in ../root/src/github.com/io-core/*/*.Mod; do 
    ln $i
  done
  for i in ../images/objcache/*; do 
    ln $i
  done
  cd ..
  rm images/io.img
  oxfstool -f2o -i work -o images/io.img -s 8g
  rm -rf work

else
  echo "need oxfstool to generate images"
fi
