#!/bin/bash
# 20160910 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\""

if ! which rpm >/dev/null 2>&1 \
&& ! which dpkg dpkg-query >/dev/null 2>&1
then
    exit 1
fi

for module in $(lsmod |awk '{print $1}')
do 
    if [ $module == 'Module' ]; then
        continue
    fi
    filename=$(modinfo $module 2>/dev/null |awk '/^filename:/ {print $2}')

    if rpm -f $filename -V 2>/dev/null |grep $filename >/dev/null 2>&1 \
    && ! dpkg-query -S $filename >/dev/null 2>&1
    then
        echo "ALERT=\"No package for $filename\""
    fi
    sleep $(( $RANDOM % 120 ))
done

endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""
