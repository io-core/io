#!/bin/bash
mkdir Sources
curl https://www.inf.ethz.ch/personal/wirth/ProjectOberon/index.html | grep Mod.txt | sed -e 's/.*HREF=.\(.*\).txt\".*/curl https:\/\/www.inf.ethz.ch\/personal\/wirth\/ProjectOberon\/\1.txt > \1/g' | bash ; wget https://www.inf.ethz.ch/personal/wirth/ProjectOberon/license.txt 

find -type f -name '*Mod.txt' | while read f; do mv "$f" "${f%.txt}"; done

