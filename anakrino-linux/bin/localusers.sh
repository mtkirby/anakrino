#!/bin/bash 
# 20161214 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\""

IFS='
'

for line in $(cat /etc/passwd)
do 
    username=$(echo $line |cut -d':' -f1)
    home=$(echo $line |cut -d':' -f6)
    if [ -f "$home/.ssh/authorized_keys" ]
    then
        hassshkey="yes"
    else
        hassshkey="no"
    fi
    shell=$(echo $line |cut -d':' -f7)
    if [ "x$shell" == "x/sbin/nologin" ] \
    || [ "x$shell" == "x/usr/sbin/nologin" ] \
    || [ "x$shell" == "x/bin/false" ] \
    || [ "x$shell" == "x/sbin/shutdown" ] \
    || [ "x$shell" == "x/sbin/halt" ] \
    || [ "x$shell" == "x/bin/sync" ]
    then
        continue
    fi

    # DES is 13 chars, so match at least 13
    if egrep "^$username:" /etc/shadow |cut -d':' -f2 |egrep -q "............."
    then 
        haspw="yes"
    else
        haspw="no"
    fi

    if [ $haspw == "no" ] && [ $hassshkey == "no" ]
    then
        continue
    fi

    pwage=$(egrep "^$username:" /etc/shadow |cut -d':' -f3)
    if [ "x$pwage" == "x" ]
    then
        pwage=0
    fi
    pwageepoch=$(( $pwage * 86400 ))
    pwagedate=$(date --date="@$pwageepoch")

    pwexpire=$(egrep "^$username:" /etc/shadow |cut -d':' -f5)
    if [ "x$pwexpire" != "x" ]
    then
        pwexpireepoch=$(( $pwexpire * 86400 ))
        pwexpiredate=$(date --date="@$pwexpireepoch")
    else
        pwexpiredate=""
    fi

    echo "username=\"$username\" shell=\"$shell\" pwageepoch=\"$pwageepoch\" pwagedate=\"$pwagedate\" pwexpiredate=\"$pwexpiredate\" haspw=\"$haspw\" hassshkey=\"$hassshkey\""

done



endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""

