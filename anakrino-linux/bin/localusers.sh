#!/bin/bash
# 20170712 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

if [[ -f "$SPLUNK_HOME/etc/apps/anakrino-linux/bin/anakrino.funcs" ]]
then
    # shellcheck disable=SC1090
    . "$SPLUNK_HOME/etc/apps/anakrino-linux/bin/anakrino.funcs" || exit 1
elif [[ -f "anakrino.funcs" ]]
then
    # shellcheck disable=SC1091
    . "anakrino.funcs" || exit 1
else
    echo "FATAL ERROR unable to find anakrino.funcs"
    exit 1
fi

# terminate script after $timeout seconds pass
timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 1800 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep


##################################################
# MAIN

IFS=$'\n'
usercount=0
for line in $(cat /etc/passwd)
do 
    IFS=':' passwd=($line)
    IFS=$'\n'
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
    sleep 5

    # DES is 13 chars, so match at least 13
    shadowline=$(egrep "^$username:" /etc/shadow)
    IFS=':' shadow=($shadowline)
    IFS=$'\n'
    if [[ "${#shadow[1]}" -ge 13 ]]
    then 
        haspw="yes"
    else
        haspw="no"
    fi

    # probably a service account
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
    ((usercount++))

    echo "username=\"$username\" shell=\"$shell\" pwageepoch=\"$pwageepoch\" pwagedate=\"$pwagedate\" pwexpiredate=\"$pwexpiredate\" haspw=\"$haspw\" hassshkey=\"$hassshkey\""

    timeoutcheck "$timeout" "$startepoch" "$startsleep"
done


printexitstats "$startepoch" "$startsleep" "completed usercount=$usercount"
