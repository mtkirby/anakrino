#!/bin/bash
# 20190409 Kirby

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

# make sure dosleep is working
dosleep 1 1 10
if [[ "(($(date +%s) - startepoch))" -lt 5 ]]
then
    echo "FATAL ERROR dosleep function is disabled."
    exit 1
fi


##################################################
# MAIN

declare -A seen
for pid in /proc/[0-9]*
do
    if ! readlink $pid/exe |grep -q java 
    then
        continue
    fi

    file=$(stat -c '%N' "${pid}/exe" 2>/dev/null |grep ' -> '|sed -e "s/.*-> .\(\/.*\).$/\1/")

    if ! egrep -q '^/$' $pid/cpuset
    then
        echo "skipping containerized java at $file"
        continue
    fi

    if [[ ! -e "$file" ]]
    then
        echo "file not found: $file"
        continue
    fi

    if [[ ${seen["$file"]} == 1 ]]
    then
        continue
    else
        seen["$file"]=1
    fi 

    version=$(${file} -version 2>&1 |sed -e 's/"//g' |paste -sd " " -)
    echo "java=\"$file\" version=\"${version}\""

    timeoutcheck "$timeout" "$startepoch" "$startsleep"
done

printexitstats "$startepoch" "$startsleep" "\"completed\""

