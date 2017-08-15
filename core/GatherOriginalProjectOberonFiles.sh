#!/bin/bash

curl https://www.inf.ethz.ch/personal/wirth/ProjectOberon/index.html | grep Mod.txt | sed -e 's/.*HREF=.\(.*\).txt\".*/wget https:\/\/www.inf.ethz.ch\/personal\/wirth\/ProjectOberon\/\1.txt /g' | bash ; wget https://www.inf.ethz.ch/personal/wirth/ProjectOberon/license.txt 

find -type f -name '*Mod.txt' | while read f; do mv "$f" "${f%.txt}"; done

