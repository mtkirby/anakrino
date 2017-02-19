#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")

rm -f /tmp/sudoerscheckreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/sudoerscheckreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root' --smtp=localhost >/tmp/sudoerscheckreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/sudoerscheckreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/sudoerscheckreport.csv.gz


echo $1 >> /tmp/sudoerscheckreport.log
echo $2 >> /tmp/sudoerscheckreport.log
env >> /tmp/sudoerscheckreport.log
set >> /tmp/sudoerscheckreport.log

