#!/bin/bash
# 20161204 Kirby
# 20170203 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

if ! which rpm >/dev/null 2>&1 \
&& ! which dpkg-query >/dev/null 2>&1
then
    exit 1
fi

function dokill() {
    local killsec=$1
    if [ $(date +"%s") -gt $killsec ]; then
        endepoch=$(date +%s)
        runtime=$(( $endepoch - $startepoch ))
        runhour=$(( $runtime / 3600 ))
        runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
        runmin=${runmin:$((${#runmin}-2)):${#runmin}}
        runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
        runsec=${runsec:$((${#runsec}-2)):${#runsec}}
        echo "end=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"FAILED: Went over $killsec seconds\""
        exit 1
    fi
}


# terminate script after $killsec seconds pass
killsec=$(( $(date +"%s") + 86400 ))

# startup sleep for server farms sharing disk
sleep $(( $RANDOM % 900 ))

startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\""

for pid in /proc/[0-9]*
do
    # Check to see if exe file exists.
    # Sometimes a program will create a temporary script and delete it while running.
    file=$(stat -c '%N' $pid/exe 2>/dev/null |grep ' -> '|sed -e "s/.*-> '\(\/.*\)'/\1/")
    if [ ! -f "$file" ]
    then
        continue
    fi

    #
    # Ignore process if it is within a container
    #
    if egrep -q 'docker|lxc' $pid/cgroup
    then
        continue
    fi


    if ! rpm -qf $file >/dev/null 2>&1 \
    && ! dpkg-query -S $file >/dev/null 2>&1
    then
        alert=()
        trigger=0
        alarm=''
        procowner=$(ps -fp ${pid##*/} |tail -1 |awk '{print $1}')
        filemode=$(stat -c "%a" "$file")
        fileowner=$(stat -c "%U" "$file")
        otherperm=$(echo $filemode |sed -e 's/.*.\(.\)$/\1/g')
        groupperm=$(echo $filemode |sed -e 's/.*\(.\).$/\1/g')

        if [ $procowner != $fileowner ] \
        && [ $fileowner != "root" ]
        then
            alert+=("Process owner and file owner mismatch. ")
            trigger=1
        fi
        if [ $otherperm == '2' ] \
        || [ $otherperm == '3' ] \
        || [ $otherperm == '6' ] \
        || [ $otherperm == '7' ]
        then
            alert+=("Permissions allow world write. ")
            trigger=1
        fi
        if [ $groupperm == '2' ] \
        || [ $groupperm == '3' ] \
        || [ $groupperm == '6' ] \
        || [ $groupperm == '7' ]
        then
            alert+=("Permissions allow group write. ")
            trigger=1
        fi

        if [ $trigger -eq 1 ]; then
            alarm="ALERT=\"${alert[@]}\""
        fi

        echo "file=\"$file\" package=\"none\" pid=\"${pid##*/}\" procowner=\"$procowner\" fileowner=\"$fileowner\" filemode=\"$filemode\" $alarm"
    fi
    sleep $(( $RANDOM % 30 ))

    dokill $killsec
done

endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""

