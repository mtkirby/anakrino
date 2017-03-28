#!/bin/bash
# 20170301 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

# startup sleep for server farms sharing disk
sleep $(( $RANDOM % 36000 ))
startepoch=$(date +%s)


unset PYTHONPATH
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/libexec
export LD_LIBRARY_PATH=/lib64:/usr/lib64:/lib:/usr/lib


oldIFS=$IFS
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
    info="updater=\"$yum\""
    num=0
    for line in $(/bin/$yum updateinfo|egrep -a 'notice\(s\)$')
    do
        num=$(echo $line |awk '{print $1}')
        type=$(echo $line |sed -e 's/.* [0-9]* \(.*\) notice.*/\1/'|sed -e 's/ /_/g')
        info="$info $type=$num"
    done
    if [ $num != 0 ]
    then
        echo $info
    fi
    lastpatch=$($yum history |grep -i '| update ' |sed -e 's/.* \([0-9]*-[0-9]*-[0-9]*\) [0-9]*:[0-9]* .*/\1/' |head -1)
    echo "updater=\"$yum\" lastpatchdate=\"$lastpatch\""
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



endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""

