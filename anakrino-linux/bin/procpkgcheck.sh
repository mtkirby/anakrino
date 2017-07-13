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

# terminate script after $timeout seconds pass
timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 1800 ))
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

declare -A seen
totalproccount=$(cat /proc/[0-9]*/cpuset 2>/dev/null |egrep -c '^/$')
proccount=0
chrootcount=0
for pid in /proc/[0-9]*
do
    ((proccount++))
    dosleep "$totalproccount" "$proccount" 84600

    # Check to see if exe file exists.
    # Sometimes a program will create a temporary script and delete it while running.
    file=$(stat -c '%N' "$pid/exe" 2>/dev/null |grep ' -> '|sed -e "s/.*-> .\(\/.*\).$/\1/")
    file=$(readlink -f "$file")
    if [[ ! -f "$file" ]]
    then
        continue
    fi

    #
    # Ignore process if it is within a container or chroot
    #   
    if ! egrep -q '^/$' "$pid"/cpuset >/dev/null 2>&1
    then
        ((chrootcount++))
        continue
    fi
        
    if [[ ${seen["$file"]} == 1 ]]
    then
        continue
    else
        seen["$file"]=1
    fi 

    if ! rpm -qf "$file" >/dev/null 2>&1 \
    && ! dpkg-query -S "$file" >/dev/null 2>&1
    then
        procowner=$(stat -c '%U' "$pid")
        procuid=$(stat -c '%u' "$pid")
        loginuid=$(cat "$pid"/loginuid)
        printfileinfo "$file" "$procowner" "Process owner" "pid=\"${pid##*/}\" procowner=\"$procowner\" procuid=\"$procuid\" loginuid=\"$loginuid\""   
    fi
    timeoutcheck "$timeout" "$startepoch" "$startsleep"
done

printexitstats "$startepoch" "$startsleep" "completed totalproccount=$totalproccount chrootcount=$chrootcount"

