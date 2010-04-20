#!/bin/bash

OUTFILE="/tmp/tmp_redirect_out.txt"

cmd="curl -v $1"
`$cmd &> $OUTFILE`

ERR=`grep -a "< HTTP.*5[0-9][0-9]" $OUTFILE`
ERR=${ERR// /} # remove emtpy spaces

if [ -z $ERR ]; then
  ERR="no error"
else
  echo "ERROR" 1>&2 
  cmd="curl $1"
  echo `$cmd 2> /dev/null`
  exit 1
fi

RES=`grep -a "< HTTP.*30[0-9]" $OUTFILE`
RES=${RES// /} # remove emtpy spaces

#echo $RES

if [ -z $RES ]; then
  exit 0
else
  #cat $OUTFILE
  RES=`grep -a "< Location: " $OUTFILE`
  RES=${RES//"< Location: "/} # remove lcoation spaces
  echo $RES
fi

#match301=$(expr index "$res" 301)
#
#echo 
#echo "result:"
#echo 
#cat $OUTFILE

#echo $match301

#for testing try 301 instead of 303 with google.de/www.google.de