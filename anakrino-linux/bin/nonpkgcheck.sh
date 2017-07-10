#!/bin/bash
# 20170709 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

if [[ -f "$SPLUNK_HOME/apps/anakrino-linux/bin/anakrino.funcs" ]]
then
    # shellcheck disable=SC1090
    . "$SPLUNK_HOME/apps/anakrino-linux/bin/anakrino.funcs" || exit 1
elif [[ -f "anakrino.funcs" ]]
then
    # shellcheck disable=SC1091
    . "anakrino.funcs" || exit 1
else
    echo "FATAL ERROR unable to find anakrino.funcs"
    exit 1
fi


if uname -n |egrep -q 'dev|test|lte|sys|cte|\.dt0'
then
    echo "NON-PCI SYSTEM"
    exit 0
fi


# terminate script after $timeout seconds pass
timeout=$(( $(date +"%s") + 604800 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 1800 ))
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

IFS=$'\n'
declare -A dirs
declare -A pkgfiles
pkgcount=()

if which rpm >/dev/null 2>&1
then
    totalpkgcount=$(rpm -qa|wc -l)
    for pkg in $(rpm -qa|grep -v splunk 2>/dev/null)
    do 
        ((pkgcount++))
        for file in $(rpm -qil "$pkg" |egrep '^/')
        do
            pkgfiles["$file"]=1
            pkgfiles["$file"]=1
            dir="${file%/*}"
            if [[ "$dir" =~ ^$ ]] \
            || [[ "$dir" =~ /log ]] \
            || [[ "$dir" =~ /cache ]] \
            || [[ "$dir" =~ /tmp ]] \
            || [[ "$dir" =~ /root ]] \
            || [[ "$dir" =~ /lock ]] \
            || [[ "$dir" =~ /run ]] \
            || [[ -h "$dir" ]]
            then
                continue
            fi
            dirs["$dir"]=1
        done
        dosleep "$totalpkgcount" "$pkgcount" 43200
    done
fi

if which dpkg >/dev/null 2>&1
then
    totalpkgcount=$(dpkg -l |grep -v splunk|awk '/^[phuri]/ {print $2}' 2>/dev/null |wc -l)
    for pkg in $(dpkg -l |grep -v splunk|awk '/^[phuri]/ {print $2}' 2>/dev/null)
    do 
        ((pkgcount++))
        for file in $(dpkg -L "$pkg" |egrep '^/')
        do
            pkgfiles["$file"]=1
            pkgfiles["$file"]=1
            dir="${file%/*}"
            if [[ "$dir" =~ ^$ ]] \
            || [[ "$dir" =~ ^\.$ ]] \
            || [[ "$dir" =~ /log ]] \
            || [[ "$dir" =~ /cache ]] \
            || [[ "$dir" =~ /tmp ]] \
            || [[ "$dir" =~ /root ]] \
            || [[ "$dir" =~ /lock ]] \
            || [[ "$dir" =~ /run ]] \
            || [[ -h "$dir" ]]
            then
                continue
            fi
            dirs["$dir"]=1
        done
        dosleep "$totalpkgcount" "$pkgcount" 43200
    done
fi

totaldircount=${#dirs[@]}    
dircount=0
filecount=0
checkcount=0
for dir in "${!dirs[@]}"
do
    ((dircount++))
    for file in "$dir"/*
    do
        ((filecount++))
        if [[ -f "$file" ]] \
        && [[ ! "$file" =~ \.pyc$ ]] \
        && [[ ! "$file" =~ \.cache$ ]] \
        && [[ ! "$file" =~ \.log$ ]] \
        && [[ ! "$file" =~ \.solv$ ]] \
        && [[ ! "$file" =~ \.solvx$ ]] \
        && [[ ! "$file" =~ \.dat$ ]] \
        && [[ ! "$file" =~ \.reg$ ]] \
        && [[ ! "$file" =~ \.rpmnew$ ]] \
        && [[ ! -h "$file" ]] \
        && [[ -z ${pkgfiles["$file"]} ]] \
        && ! rpm -qif "$file" >/dev/null 2>&1 \
        && ! dpkg -S "$file" >/dev/null 2>&1
        then
            ((checkcount++))
            printfileinfo "$file" "" "" ""
        fi
    done
    timeoutcheck "$timeout" "$startepoch"
    dosleep "$totaldircount" "$dircount" 518400
done

gotoexit "$startepoch" "completed dircount=$dircount filecount=$filecount checkcount=$checkcount pkgcount=$pkgcount"

