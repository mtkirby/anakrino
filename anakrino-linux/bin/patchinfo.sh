#!/bin/bash
# 20170709 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

if [[ -f "$SPLUNK_HOME/apps/anakrino-linux/bin/anakrino.funcs" ]]
then
    # shellcheck disable=SC1090
    . "$SPLUNK_HOME/apps/anakrino-linux/bin/anakrino.funcs" || exit 1
elif [[ -f "anakrino.funcs" ]]
then
    # shellcheck disable=SC1091
    . "anakrino.funcs" || exit 1
else
    echo "FATAL ERROR unable to find anakrino.funcs"
    exit 1
fi

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 86400 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
# MAIN

# yum/dnf uses python, which can conflict with Splunk's python
unset PYTHONPATH

declare -a notices

IFS=$'\n'
if which dnf >/dev/null 2>&1 || which yum >/dev/null 2>&1
then
    if which dnf >/dev/null 2>&1
    then
        yum=dnf
    else
        yum=yum
    fi
    num=0
    for line in $($yum updateinfo|egrep -a 'notice\(s\)$')
    do
        num=$(echo "$line" |awk '{print $1}')
        type=$(echo "$line" |sed -e 's/.* [0-9]* \(.*\) notice.*/\1/'|sed -e 's/ /_/g')
        notices+=($type=$num)
    done
    alarm="$(join_by ' ' "${notices[@]}")"
    lastpatch=$($yum history |grep -i '| update ' |sed -e 's/.* \([0-9]*-[0-9]*-[0-9]*\) [0-9]*:[0-9]* .*/\1/' |head -1)
    echo "updater=\"$yum\" lastpatchdate=\"$lastpatch\" $alarm"
fi

if which apt-get >/dev/null 2>&1
then
    apt-get update >/dev/null 2>&1
    apt-get -q -s upgrade
    patches=$(apt-get -q -s upgrade|egrep -a  '^[0-9]+ upgraded' |sed -e 's/\([0-9]*\) upgraded.*/\1/')
    echo "updater=\"apt\" patches=$patches"
fi


if egrep -q '^Start-Date:' /var/log/apt/history.log >/dev/null 2>&1
then
    aptlastpatch=$(egrep -a '^Start-Date:' /var/log/apt/history.log |tail -1 |awk '{print $2" "$3}')
    echo "updater=\"apt\" lastpatchdate=\"$aptlastpatch\""
fi

gotoexit "$startepoch" "completed"

