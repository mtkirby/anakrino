#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")

rm -f /tmp/procpkgcheckreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/procpkgcheckreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root' --smtp='localhost' >/tmp/procpkgcheckreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/procpkgcheckreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/procpkgcheckreport.csv.gz


echo $1 >> /tmp/procpkgcheckreport.log
echo $2 >> /tmp/procpkgcheckreport.log
env >> /tmp/procpkgcheckreport.log
set >> /tmp/procpkgcheckreport.log

