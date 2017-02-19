#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")


rm -f /tmp/sigcheckreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/sigcheckreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root@localhost' --smtp=localhost >/tmp/sigcheckreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/sigcheckreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/sigcheckreport.csv.gz


echo $1 >> /tmp/sigcheckreport.log
echo $2 >> /tmp/sigcheckreport.log
env >> /tmp/sigcheckreport.log
set >> /tmp/sigcheckreport.log

