#!/bin/bash
# 20170709 Kirby

renice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

if [[ -f "$SPLUNK_HOME/etc/apps/anakrino-linux/bin/anakrino.funcs" ]]
then
    # shellcheck disable=SC1090
    . "$SPLUNK_HOME/etc/apps/anakrino-linux/bin/anakrino.funcs" || exit 1
elif [[ -f "anakrino.funcs" ]]
then
    # shellcheck disable=SC1091
    . "anakrino.funcs" || exit 1
else
    echo "FATAL ERROR unable to find anakrino.funcs"
    exit 1
fi

which docker >/dev/null 2>&1 || exit 0
pgrep -x docker >/dev/null 2>&1 || exit 0

# startup sleep for server farms sharing disk
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 3600 ))
startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

# make sure dosleep is working
dosleep 1 1 10
if [[ "(($(date +%s) - startepoch))" -lt 5 ]]
then
    echo "FATAL ERROR dosleep function is disabled."
    exit 1
fi


##################################################
# MAIN


IFS='.' dockerversion=($(docker version |awk '/^Server version:/ {print $3}'))
IFS=$'\n'
if [[ ${dockerversion[0]} -le 1 ]] \
&& [[ ${dockerversion[1]} -le 7 ]]
then
    # docker ps does not allow format
    for line in $(docker ps --no-trunc |grep -v CONTAINER)
    do
        container=$(echo "$line" |awk '{print $1}')
        image=$(echo "$line" |awk '{print $2}')
        name=$(echo "$line" |awk '{print $NF}')
        ports=$(docker port "$container")
        command=$(echo "$line" |cut -d'"' -f2)
        echo "name=\"$name\" image=\"$image\" command=\"$command\" ports=\"$ports\""
    done
else
    for line in $(docker ps --no-trunc --format '{{.Names}}\t{{.Image}}\t{{.Command}}\t{{.Ports}}'|sed -e 's/"//g')
    do
        IFS=$'\t'
        arr=($line)
        echo "name=\"${arr[0]}\" image=\"${arr[1]}\" command=\"${arr[2]}\" ports=\"${arr[3]}\""
        IFS=$'\n'
    done
fi

for line in $(pgrep -xa docker|cut -d' ' -f2-|grep -v docker-proxy)
do
    echo "dockerargs=\"$line\""
done

for line in $(pgrep -fa docker-proxy|cut -d' ' -f2-)
do
    echo "dockerproxyargs=\"$line\""
done

gotoexit "$startepoch" "completed"
