#!/bin/bash

umask 0077
scriptname=${0##*/}
date=$(date +"%s")

# sleep in case Splunk is slow
sleep 10
/opt/splunk/bin/scripts/fschangediff.py $SPLUNK_ARG_8 $SPLUNK_HOME > /tmp/fschangediff.report 2>&1
cp -f $SPLUNK_ARG_8 /tmp/fschangediff.csv.gz

echo $1 > /tmp/fschangediff.log
echo $2 >> /tmp/fschangediff.log
env >> /tmp/fschangediff.log
set >> /tmp/fschangediff.log

