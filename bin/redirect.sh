#!/bin/bash

OUTFILE="/tmp/tmp_redirect_out"

cmd="curl -v $1"
`$cmd &> $OUTFILE`

RES=`grep "< HTTP.*303" $OUTFILE`
RES=${RES// /} # remove emtpy spaces

#echo $RES

if [ -z $RES ]; then
  #echo "no"
  echo ""
else
  #cat $OUTFILE
  RES=`grep "< Location: " $OUTFILE`
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