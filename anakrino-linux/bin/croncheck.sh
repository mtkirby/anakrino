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
timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 18000 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep


##################################################
# MAIN
for tab in /var/spool/cron/*; do
    if [[ ! -e $tab ]]
    then
        # no crontabs
        continue
    fi
    username=${tab##*/}
    for proc in $(egrep -v "^#" "$tab" |awk '{print $6}'|sed -e 's/(//g' |egrep "."|sort|uniq)
    do 
        # aliases and functions have caused problems
        unset "$proc" >/dev/null 2>&1
        unalias "$proc" >/dev/null 2>&1
        if ! exe=$(which "$proc" 2>/dev/null)
        then
            echo "$proc not found"
            continue
        fi
        
        printfileinfo "$exe" "$username" "Cron user"

        sleep $(( ( RANDOM * RANDOM + 1 ) % 30 + 30 ))
        timeoutcheck "$timeout" "$startepoch"
    done
done

gotoexit "$startepoch" "completed"
