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

if ! which rpm >/dev/null 2>&1 \
&& ! which dpkg dpkg-query >/dev/null 2>&1
then
    exit 1
fi

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH

for module in $(lsmod |awk '{print $1}')
do 
    if [[ "$module" == 'Module' ]]
    then
        continue
    fi
    filename=$(modinfo "$module" 2>/dev/null |awk '/^filename:/ {print $2}')

    if ! rpm -f "$filename" -V >/dev/null 2>&1 \
    && ! dpkg-query -S "$filename" >/dev/null 2>&1
    then
        echo "ALERT=\"No package for module=$module filename=$filename\""
    fi
    sleep $(( ( RANDOM * RANDOM + 1 ) % 300 + 60 ))
    timeoutcheck "$timeout"
done

gotoexit "completed"
