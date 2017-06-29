#!/bin/bash
# 20170624 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

# terminate script after $timeout seconds pass
timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 18000 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
function join_by {
    local IFS="$1"
    shift
    echo "$*"
}

##################################################
function gotoexit() {
    local result=$1
    endepoch=$(date +%s)
    runtime=$(( endepoch - startepoch ))
    runhour=$(( runtime / 3600 ))
    runmin=0$(( ( runtime - ( runhour * 3600 )) / 60 ))
    runmin=${runmin:$((${#runmin}-2)):${#runmin}}
    runsec=0$(( ( runtime - ( runhour * 3600 )) % 60 ))
    runsec=${runsec:$((${#runsec}-2)):${#runsec}}
    echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"$result\""
}

##################################################
function timeoutcheck() {
    local timeout=$1
    if [[ "$(date +"%s")" -gt "$timeout" ]]
    then
        gotoexit "FAILED: Went over timeout seconds"
        exit 1
    fi  
}

##################################################
# MAIN

# yum/dnf uses python, which can conflict with Splunk's python
unset PYTHONPATH
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/libexec:$PATH
export LD_LIBRARY_PATH=/lib64:/usr/lib64:/lib:/usr/lib:$LD_LIBRARY_PATH

declare -a notices

IFS='
'
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


gotoexit "completed"

