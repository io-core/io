#!/bin/bash

oxlines=`oxfstool -h 2>&1 | wc -l`
if [ $oxlines -gt 10 ]; then 
  rm -rf work
  mkdir work
  cd work
  for i in ../root/src/github.com/io-core/*/*.Mod; do 
    ln $i
  done
  cd ..










else
  echo "need oxfstool to generate images"
fi
