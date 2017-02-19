#!/bin/bash
# 20161231 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\""

# terminate script after $killsec seconds pass
killsec=$(( $(date +"%s") + 86400 ))

# startup sleep for server farms sharing disk
sleep $(( $RANDOM % 900 ))

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

for tab in /var/spool/cron/*; do
    username=${tab##*/}
    for proc in $(cat $tab |egrep -v "^#" |awk '{print $6}'|sed -e 's/(//g' |egrep "."|sort|uniq)
    do 
        alert=()
        trigger=0
        alarm=''
        # aliases and functions have caused problems
        unset $proc >/dev/null 2>&1
        unalias $proc >/dev/null 2>&1
        which $proc >/dev/null 2>&1 || continue
        exe=$(which $proc)
        # check if symlink
        if stat -c '%N' $exe 2>/dev/null |grep -q ' -> ' >/dev/null 2>&1; then
            exe=$(stat -c '%N' $exe 2>/dev/null |sed -e "s/.* -> '\(.*\)'/\1/")
            if [ "${exe:0:1}" != "/" ]; then
                dir=$(which $proc)
                exe="${dir%/*}/$exe"
            fi  
        fi
        filemode=$(stat -c "%a" $exe)
        fileowner=$(stat -c "%U" $exe)
        filegroup=$(stat -c "%G" $exe)
        mountpoint=$(stat -c "%m" $exe)
        fstype=$(stat --file-system -c "%T" $exe)
        otherperm=$(echo $filemode |sed -e 's/.*.\(.\)$/\1/g')
        groupperm=$(echo $filemode |sed -e 's/.*\(.\).$/\1/g')

        if [ $username != $fileowner ] \
        && [ $fileowner != "root" ]
        then
            alert+=("Cron username and exe owner mismatch. ")
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

        echo "username=\"$username\" exe=\"$exe\" mode=\"$filemode\" owner=\"$fileowner\" group=\"$filegroup\" mountpoint=\"$mountpoint\" fstype=\"$fstype\" $alarm"
        sleep $(( $RANDOM % 30 ))
    done

    dokill $killsec

    sleep $(( $RANDOM % 10 ))
done


endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""
