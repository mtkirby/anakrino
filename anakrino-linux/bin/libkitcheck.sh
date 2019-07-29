#!/bin/bash
# 20190729 Kirby

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
timeout=$(( $(date +"%s") + 604800 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 86400 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

# make sure dosleep is working
dosleep 1 1 10
if [[ "(($(date +%s) - startepoch))" -lt 5 ]]
then
    echo "FATAL ERROR dosleep function is disabled."
    exit 1
fi


##################################################
# MAIN

declare -A libseen

ldcount=$(ldconfig -p |grep -c ' => ')
proclibcount=$(awk '/ r-xp .* \// {print $6}' /proc/[0-9]*/maps 2>/dev/null|sort|uniq |wc -l)
libtotalcount=$((ldcount + proclibcount))
dupskip=0
chrootcount=0
for libfile in $(ldconfig -p|grep ' => ' |sed -e 's/.* => \(\/*\)/\1/' )
do 
    libfile=$(readlink -f "$libfile")
    if ! rpm -qf "$libfile" >/dev/null 2>&1 \
    && ! dpkg -S "$libfile" >/dev/null 2>&1
    then
        printfileinfo "$libfile" "root" "ld cache" "alarm=\"ALERT $libfile found in ld cache does not belong to a package\""
    else
        libseen["$libfile"]=1
    fi
    # 84600 is 1 day - 1/2 hour
    dosleep "$libtotalcount" "${#libseen[@]}" 259200
done

for pid in /proc/[0-9]*
do
    # Check to see if exe file exists.
    # Sometimes a program will create a temporary script and delete it while running.
    file=$(readlink -f "$pid/exe" 2>/dev/null)
    if [[ ! -f "$file" ]]
    then
        continue
    fi

    # Ignore process if it is within a container or chroot
    if ! egrep -q '^/$' "$pid"/cpuset >/dev/null 2>&1
    then
        ((chrootcount++))
        continue
    fi

    if preload=$(tr '\0' '\n' < "$pid"/environ |egrep '^LD_PRELOAD=' 2>&1)
    then
        procowner=$(stat -c '%U' "$pid")
        procuid=$(stat -c '%u' "$pid")
        loginuid=$(cat "$pid"/loginuid)
        printfileinfo "$file" "" "" "alarm=\"LD_PRELOAD DETECTED\" preload=\"$preload\" process=\"$file\" pid=\"${pid##*/}\" procowner=\"$procowner\" procuid=\"$procuid\" loginuid=\"$loginuid\""
    fi

    for libfile in $(awk '/ r-xp .* \// {print $6}' "$pid"/maps 2>/dev/null)
    do
        libfile=$(readlink -f "$libfile")
        if [[ ${libseen["$libfile"]} == 1 ]]
        then
            ((dupskip++))
            continue
        fi
        if [[ -f "$libfile" ]] \
        && ! rpm -qf "$libfile" >/dev/null 2>&1 \
        && ! dpkg -S "$libfile" >/dev/null 2>&1 
        then
            procowner=$(stat -c '%U' "$pid")
            procuid=$(stat -c '%u' "$pid")
            loginuid=$(cat "$pid"/loginuid)
            printfileinfo "$libfile" "" "" "alarm=\"ALERT $libfile is not a package library\" process=\"$file\" pid=\"${pid##*/}\" procowner=\"$procowner\" procuid=\"$procuid\" loginuid=\"$loginuid\""
        else
            libseen["$libfile"]=1
        fi
        dosleep "$libtotalcount" "${#libseen[@]}" 259200
        timeoutcheck "$timeout" "$startepoch" "$startsleep"
    done
done

printexitstats "$startepoch" "$startsleep" "completed libschecked=${#libseen[@]} dupskip=$dupskip chrootcount=$chrootcount"

