#!/bin/bash
git add root/doc
git add root/src/github.com/io-core/*
git commit -m 'sync local to master'
git push origin main
