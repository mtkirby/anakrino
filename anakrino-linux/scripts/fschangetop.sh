#!/bin/bash
# Matt Kirby


umask 0077
scriptname=${0##*/}
date=$(date +"%s")

######/opt/splunk/bin/scripts/osseccompactor.pl --report="$1" --emailto='root' --emailfrom='logcompactor@localhost' --smtpserver='localhost' --name="$2" --link="http://localhost:8000/app/" >/tmp/${scriptname%%.sh}.log 2>&1


rm -f /tmp/fschangetop.log >/dev/null 2>&1

#export PYTHONVERBOSE=1
unset PYTHONPATH

sleep 1
if [ -f $SPLUNK_ARG_8 ]; then
	/opt/splunk/bin/scripts/fschangetop.py $SPLUNK_ARG_8 $SPLUNK_ARG_6 >/tmp/fschangetop.report 2>&1
else
	echo "REPORT NOT FOUND: $SPLUNK_ARG_8" >> /tmp/fschangetop.log
	exit 0
fi 

cp -f $SPLUNK_ARG_8 /tmp/fschangetop.csv.gz


echo $1 >> /tmp/fschangetop.log
echo $2 >> /tmp/fschangetop.log
env >> /tmp/fschangetop.log
set >> /tmp/fschangetop.log

