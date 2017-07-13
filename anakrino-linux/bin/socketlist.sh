#!/bin/bash
# 20170712 Kirby

nice 20 $$ >/dev/null 2>&1
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


startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 1800 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
# MAIN

declare -a socket

IFS=$'\n'

if which netstat >/dev/null 2>&1
then
    for line in $(netstat -peanut|awk '{ if ($6 == "LISTEN") print }' |sed -e 's/[[:space:]][[:space:]]*/ /g')
    do
        IFS=' '
        socket=($line)
        pid=${socket[8]%/*}
        chroot=$(cat /proc/"$pid"/cpuset)
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline)
        user=$(id -nu "${socket[6]}")
        echo "proto=\"${socket[0]}\" local=\"${socket[3]}\" remote=\"${socket[4]}\" state=\"${socket[5]}\" uid=\"${socket[6]}\" user=\"$user\" chroot=\"$chroot\" cmdline=\"${cmdline:0:92}\""
        sleep 1
    done
elif which ss >/dev/null 2>&1
then
    for line in $(ss -n -l -p -ut|awk '{ if ($2 == "LISTEN" || $2 == "UNCONN") print }' |sed -e 's/[[:space:]][[:space:]]*/ /g')
    do
        IFS=' '
        socket=($line)
        pid=$(echo "${socket[6]}" |sed -e 's/.*,pid=\([[:digit:]]*\),.*/\1/')
        chroot=$(cat /proc/"$pid"/cpuset)
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline)
        uid=$(stat -c '%u' /proc/"$pid")
        user=$(id -nu "$uid")
        echo "proto=\"${socket[0]}\" local=\"${socket[4]}\" remote=\"${socket[5]}\" state=\"${socket[1]}\" uid=\"$uid\" user=\"$user\" chroot=\"$chroot\" cmdline=\"${cmdline:0:92}\""
        sleep 1
    done
fi

printexitstats "$startepoch" "$startsleep" "completed"

