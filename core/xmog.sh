#!/bin/bash

if [ -e "$1.go" ] 
then
  cat $1.go |\
  sed -e 's/[[:space:]]*$//' |\
  sed -e 's/^}$/END/' |\
  /usr/bin/awk '
  function unquote( x ) {
    if ( match( x, /^".*"$/ ) ) {
      x = substr( x, 2, length(x) - 2 );
    }
    return x;
  }
  NR==1{mname = $2;  print "MODULE " $2 ";"}
  NR==2{state = 0; printf "%s", "  IMPORT "}
  NR > 2{
    if ( state == 0 ) {
      if ( $0 == ")" ) {
        state = 1; print ";"; print "  CONST"
      }else{
        printf "%s, ", unquote($1)
      }
    }else{
      if ( state == 1 ) {
        if ( $0 == ")" ) {
          state = 2; print "  TYPE"
        }else{
          if ( $1 != "const" ) {
            print "    " $1 " == " $3 
          }
        }
      }else{
          if ( $1 == "func" ) {
            fname = $2; 
            print
          }else{
            if ( $0 == "END" ) {
              if ( fname != "main(){" ) {
                print "  END " fname ";"  
              }
            }else{
              print "  " $0
            }
          }
      }
    }
  }
  END {print "END " mname "."}
'  |\
  sed -e 's/^\(  IMPORT .*\), ;/\1;/' |\
  sed -e 's/^\(END .*\)(.*;$/\1;/' |\
  sed -e 's/^func \(.*\){/  PROCEDURE \1;/g'|\
  sed -e 's/^  PROCEDURE \(.*\)();/  PROCEDURE \1;/g'|\
  sed -e 's/^  PROCEDURE main;/BEGIN/g'|\
  sed -e 's/\([[:space:]]*PROCEDURE[[:space:]]*[[:upper:]][[:alnum:]]*\)\(.*\)$/\1*\2/g'|\
  sed -e 's/()$/;/g' |\
  sed -e 's/(){;$/;/g' |\
  sed -e 's/();/;/g' |\
  sed -e 's/\([^=]\)=\([^=]\)/\1:=\2/g' |\
  sed -e 's/\([^=]\)==\([^=]\)/\1=\2/g' |\
  sed -e 's/^\([[:space:]]*\)=\([[:space:]]*\)$//g' |\
  sed -e 's/\(.*\)if\(.*\){$/\1IF\2 THEN/g' |\
  sed -e 's/}else{/ELSE/g' |\
  sed -e 's/^\([[:space:]]*\)}$/\1END/g' |\
  sed -e 's/^\([[:space:]]*\)const \(.*\):=\(.*\)$/\1\2=\3;/g' |\
  sed -e 's/^\([[:space:]]*\)var \([^[:space:]]*\)[[:space:]]*\(.*\)$/\1\2 : \3;/g' |\
  sed -e 's/0x\([abcdefABCDEF][1234567890abcdefABCDEF]*\)/0\1H/g' |\
  sed -e 's/0x\([1234567890][1234567890abcdefABCDEF]*\)/\1H/g' 










else
  echo "no file $1.go"
fi
