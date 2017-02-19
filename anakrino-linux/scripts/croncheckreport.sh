#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")


rm -f /tmp/croncheckreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/croncheckreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root' --smtp=localhost >/tmp/croncheckreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/croncheckreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/croncheckreport.csv.gz


echo $1 >> /tmp/croncheckreport.log
echo $2 >> /tmp/croncheckreport.log
env >> /tmp/croncheckreport.log
set >> /tmp/croncheckreport.log

