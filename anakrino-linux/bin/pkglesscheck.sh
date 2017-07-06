#!/bin/bash
# 20170705 Kirby

IFS='
'


nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

# terminate script after $timeout seconds pass
#timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
#startsleep=$(( ( RANDOM * RANDOM + 1 ) % 18000 ))
#echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
#sleep $startsleep

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
function filecheck() {
    local file=$1
    local alert=()
    local trigger=0
    local alarm=''
    local mode
    local owner
    local group
    local access
    local modify
    local change
    local otherperm
    local groupperm
    local sha1sum

    if ! stat "$file" >/dev/null 2>&1; then
        # file disappeared
        return 1
    fi
    mode=$(stat -c "%a" "$file")
    owner=$(stat -c "%U" "$file")
    group=$(stat -c "%G" "$file")
    access=$(stat -c "%x" "$file")
    modify=$(stat -c "%y" "$file")
    change=$(stat -c "%z" "$file")
    otherperm=${mode:$((${#mode}-1)):1}
    groupperm=${mode:$((${#mode}-2)):1}

    if [ "$otherperm" == '2' ] \
    || [ "$otherperm" == '3' ] \
    || [ "$otherperm" == '6' ] \
    || [ "$otherperm" == '7' ]
    then
        alert+=("Permissions allow world write. ")
        trigger=1
    fi
    if [ "$groupperm" == '2' ] \
    || [ "$groupperm" == '3' ] \
    || [ "$groupperm" == '6' ] \
    || [ "$groupperm" == '7' ] \
    && [ "$group" != 'root' ]
    then
        alert+=("Permissions allow group write. ")
        trigger=1
    fi

    if [ $trigger -eq 1 ]; then
        alarm="alarm=\"$(join_by ' ' "${alert[@]}")\""
    fi

    if which sha1sum >/dev/null 2>&1; then
        sha1sum=$(sha1sum "$file" |awk '{print $1}')
    elif which openssl >/dev/null 2>&1; then
        sha1sum=$(openssl sha1 "$file" |awk '{print $2}')
    else
        sha1sum="unknown"
    fi
    echo "file=\"$file\" mode=\"$mode\" owner=\"$owner\" group=\"$group\" lastaccess=\"$access\" lastmodify=\"$modify\" lastchange=\"$change\" sha1sum=\"$sha1sum\" $alarm"

}

##################################################


declare -A dirs
declare -A pkgfiles

if which rpm >/dev/null 2>&1
then
    for pkg in $(rpm -qa|grep -v splunk 2>/dev/null)
    do 
        for file in $(rpm -qil "$pkg" |egrep '^/')
        do
            pkgfiles["$file"]=1
            pkgfiles["$file"]=1
            dir="${file%/*}"
            if [[ "$dir" =~ ^$ ]] \
            || [[ "$dir" =~ /log$ ]] \
            || [[ "$dir" =~ /cache$ ]] \
            || [[ "$dir" =~ /tmp$ ]] \
            || [[ "$dir" =~ /root$ ]] \
            || [[ "$dir" =~ /lock$ ]] \
            || [[ "$dir" =~ /run$ ]] \
            || [[ -h "$dir" ]]
            then
                continue
            fi
            dirs["$dir"]=1
        done
    done
fi

if which dpkg >/dev/null 2>&1
then
    for pkg in $(dpkg -l |grep -v splunk|awk '/^[phuri]/ {print $2}' 2>/dev/null)
    do 
        for file in $(dpkg -L "$pkg" |egrep '^/')
        do
            pkgfiles["$file"]=1
            pkgfiles["$file"]=1
            dir="${file%/*}"
            if [[ "$dir" =~ ^$ ]] \
            || [[ "$dir" =~ ^\.$ ]] \
            || [[ "$dir" =~ /log$ ]] \
            || [[ "$dir" =~ /cache$ ]] \
            || [[ "$dir" =~ /tmp$ ]] \
            || [[ "$dir" =~ /root$ ]] \
            || [[ "$dir" =~ /lock$ ]] \
            || [[ "$dir" =~ /run$ ]] \
            || [[ -h "$dir" ]]
            then
                continue
            fi
            dirs["$dir"]=1
        done
    done
fi

echo loaded
    
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
        && [[ ! -h "$file" ]] \
        && [[ -z ${pkgfiles["$file"]} ]] \
        && ! rpm -qif "$file" >/dev/null 2>&1 \
        && ! dpkg -S "$file" >/dev/null 2>&1
        then
            ((checkcount++))
            filecheck "$file"
        fi
    done
done

echo "dircount=$dircount"
echo "filecount=$filecount"
echo "checkcount=$checkcount"
