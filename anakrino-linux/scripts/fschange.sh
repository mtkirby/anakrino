#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")

rm -f /tmp/fschange.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/fschange.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root' --smtp=localhost >/tmp/fschange.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/fschange.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/


echo $1 >> /tmp/fschange.log
echo $2 >> /tmp/fschange.log
env >> /tmp/fschange.log
set >> /tmp/fschange.log

