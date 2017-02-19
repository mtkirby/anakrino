#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")


rm -f /tmp/autorunsreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/autorunsreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root@localhost' --smtp=localhost >/tmp/autorunsreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/autorunsreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/autorunsreport.csv.gz


echo $1 >> /tmp/autorunsreport.log
echo $2 >> /tmp/autorunsreport.log
env >> /tmp/autorunsreport.log
set >> /tmp/autorunsreport.log

