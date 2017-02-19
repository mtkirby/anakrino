#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")

rm -f /tmp/modpkgcheckreport.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

# sleep in case Splunk is slow
sleep 10
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/modpkgcheckreport.py --file="$SPLUNK_ARG_8" --url="$SPLUNK_ARG_6" --mailfrom='anakrino@localhost' --mailto='root' --smtp=localhost >/tmp/modpkgcheckreport.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/modpkgcheckreport.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/modpkgcheckreport.csv.gz


echo $1 >> /tmp/modpkgcheckreport.log
echo $2 >> /tmp/modpkgcheckreport.log
env >> /tmp/modpkgcheckreport.log
set >> /tmp/modpkgcheckreport.log

