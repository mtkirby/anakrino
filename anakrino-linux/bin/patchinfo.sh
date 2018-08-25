#!/bin/bash
# 20180821 Kirby

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

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 86400 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
# MAIN

# yum/dnf uses python, which can conflict with Splunk's python
unset PYTHONPATH

declare -a notices
declare -a cves

IFS=$'\n'
if which dnf >/dev/null 2>&1 || which yum >/dev/null 2>&1
then
    if which dnf >/dev/null 2>&1
    then
        yum=dnf
    else
        yum=yum
    fi
    num=0
    for line in $($yum updateinfo summary updates|egrep -a 'notice\(s\)$')
    do
        num=$(echo "$line" |awk '{print $1}')
        type=$(echo "$line" |sed -e 's/.* [0-9]* \(.*\) notice.*/\1/'|sed -e 's/ /_/g')
        notices+=($type=$num)
    done
    alarm="$(join_by ' ' "${notices[@]}")"
    lastpatch=$($yum history |egrep -i ' Update |, U' |sed -e 's/.* \([0-9]*-[0-9]*-[0-9]*\) [0-9]*:[0-9]* .*/\1/' |head -1)

    for cve in $($yum updateinfo info updates 2>/dev/null  \
        |sed -e 's/ /\n/g' \
        |egrep -i 'CVE-[[:digit:]]+-[[:digit:]]' \
        |tr '[a-z]' '[A-Z]' \
        |sed -e 's/.*\(CVE-[[:digit:]]*-[[:digit:]]*\).*/\1/' \
        |sort -u )
    do
        cves+=($cve)
    done
    cvelist="$(join_by ' ' "${cves[@]}")"

    for repodate in $($yum repolist -v \
        |egrep 'Repo-id|Repo-updated|^$' \
        |cut -d':' -f2- \
        |sed -e 's/^$/SPLITRECORDHERE/g' \
        |tr '\n' ' '|sed -e 's/SPLITRECORDHERE/\n/g' \
        |egrep "[[:alnum:]]" \
        |sed -e 's/[[:space:]]*$//' \
        |sed -e 's/^[[:space:]]*\([^[:space:]]*\)[[:space:]]*\(.*\)/REPODATE-\1="\2"/g' )
    do
        repodates+=($repodate)
    done
    repodatelist="$(join_by ' ' "${repodates[@]}")"

    echo "updater=\"$yum\" lastpatchdate=\"$lastpatch\" $alarm missingCVEs=\"$cvelist\""
    echo "updater=\"$yum\" $repodatelist"
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

printexitstats "$startepoch" "$startsleep" "completed"

