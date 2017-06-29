#!/bin/bash
# 20170628 Kirby

renice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

export dIFS=$IFS
export rnIFS=$'\r\n'
export tIFS=$'\t'


which docker >/dev/null 2>&1 || exit 0
pgrep -x docker >/dev/null 2>&1 || exit 0

# startup sleep for server farms sharing disk
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 3600 ))
startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep


##################################################
function gotoexit() {
    local result=$1
    endepoch=$(date +%s)
    runtime=$(( endepoch - startepoch ))
    runhour=$(( runtime / 3600 ))
    runmin=0$(( (runtime - ( runhour * 3600 )) / 60 ))
    runmin=${runmin:$((${#runmin}-2)):${#runmin}}
    runsec=0$(( (runtime - ( runhour * 3600 )) % 60 ))
    runsec=${runsec:$((${#runsec}-2)):${#runsec}}
    echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"$result\""
}


##################################################
# MAIN


IFS='.' dockerversion=($(docker version |awk '/^Server version:/ {print $3}'))
IFS=$rnIFS
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
        IFS=$tIFS
        arr=($line)
        echo "name=\"${arr[0]}\" image=\"${arr[1]}\" command=\"${arr[2]}\" ports=\"${arr[3]}\""
        IFS=$rnIFS
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


gotoexit "completed"
