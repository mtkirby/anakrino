#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")

rm -f /tmp/pkgcheckreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/pkgcheckreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root' --smtp='localhost' >/tmp/pkgcheckreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/pkgcheckreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/pkgcheckreport.csv.gz


echo $1 >> /tmp/pkgcheckreport.log
echo $2 >> /tmp/pkgcheckreport.log
env >> /tmp/pkgcheckreport.log
set >> /tmp/pkgcheckreport.log

