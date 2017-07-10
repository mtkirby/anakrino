#!/bin/bash
# 20170709 Kirby

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

if ! which rpm >/dev/null 2>&1 \
&& ! which dpkg dpkg-query >/dev/null 2>&1
then
    exit 1
fi

totalmodcount=$(lsmod |wc -l)
modcount=0
for module in $(lsmod |awk '{print $1}')
do 
    if [[ "$module" == 'Module' ]]
    then
        continue
    fi
    filename=$(modinfo "$module" 2>/dev/null |awk '/^filename:/ {print $2}')
    filename=$(readlink -f "$filename")

    if ! rpm -f "$filename" -V >/dev/null 2>&1 \
    && ! dpkg-query -S "$filename" >/dev/null 2>&1
    then
        echo "ALERT=\"No package for module=$module filename=$filename\""
    fi
    ((modcount++))
    dosleep "$totalmodcount" "$modcount" 518400
    timeoutcheck "$timeout" "$startepoch"
done

gotoexit "$startepoch" "completed modcount=$modcount"
