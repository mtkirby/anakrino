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

rnIFS='
'
IFS=$rnIFS
for line in $(cat /etc/passwd)
do 
    IFS=':' passwd=($line)
    IFS=$rnIFS
    username=${passwd[0]}
    home=${passwd[5]}
    if [[ -f "$home/.ssh/authorized_keys" ]]
    then
        hassshkey="yes"
    else
        hassshkey="no"
    fi
    shell=${passwd[6]}
    if [[ "$shell" == "/sbin/nologin" ]] \
    || [[ "$shell" == "/usr/sbin/nologin" ]] \
    || [[ "$shell" == "/bin/false" ]] \
    || [[ "$shell" == "/sbin/shutdown" ]] \
    || [[ "$shell" == "/sbin/halt" ]] \
    || [[ "$shell" == "/bin/sync" ]]
    then
        continue
    fi
    sleep 1

    # DES is 13 chars, so match at least 13
    shadowline=$(egrep "^$username:" /etc/shadow)
    IFS=':' shadow=($shadowline)
    IFS=$rnIFS
    if [[ "${#shadow[1]}" -ge 13 ]]
    then 
        haspw="yes"
    else
        haspw="no"
    fi

    if [[ "$haspw" == "no" ]] \
    && [[ "$hassshkey" == "no" ]]
    then
        continue
    fi

    pwage=${shadow[2]}
    if [[ "x$pwage" == "x" ]]
    then
        pwage=0
    fi
    pwageepoch=$(( pwage * 86400 ))
    pwagedate=$(date --date="@$pwageepoch")

    pwexpire=${shadow[4]}
    if [[ "x$pwexpire" != "x" ]]
    then
        pwexpireepoch=$(( pwexpire * 86400 ))
        pwexpiredate=$(date --date="@$pwexpireepoch")
    else
        pwexpiredate=""
    fi

    echo "username=\"$username\" shell=\"$shell\" pwageepoch=\"$pwageepoch\" pwagedate=\"$pwagedate\" pwexpiredate=\"$pwexpiredate\" haspw=\"$haspw\" hassshkey=\"$hassshkey\""

    timeoutcheck "$timeout"
done


gotoexit "completed"
