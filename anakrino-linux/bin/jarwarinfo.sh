#!/bin/bash
# 20200301 Kirby

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
totalproccount=$(cat /proc/[0-9]*/cpuset 2>/dev/null |egrep -c '^/$')
proccount=0
chrootcount=0
for pid in /proc/[0-9]*
do
    if ! readlink $pid/exe |grep -q java
    then
        continue
    fi

    ((proccount++))
    dosleep "$totalproccount" "$proccount" 84600

    # Check to see if exe file exists.
    # Sometimes a program will create a temporary script and delete it while running.
    file=$(stat -c '%N' "$pid/exe" 2>/dev/null |grep ' -> '|sed -e "s/.*-> .\(\/.*\).$/\1/")
    file=$(readlink -f "$file")
    if [[ ! -f "$file" ]]
    then
        continue
    fi

    #
    # Ignore process if it is within a container or chroot
    #   
    if ! egrep -q '^/$' "$pid"/cpuset >/dev/null 2>&1
    then
        ((chrootcount++))
        echo "skipping containerized java at $file"
        continue
    fi
        
    if [[ ${seen["$file"]} == 1 ]]
    then
        continue
    else
        seen["$file"]=1
    fi 

    procowner=$(stat -c '%U' "$pid")
    procuid=$(stat -c '%u' "$pid")
    loginuid=$(cat "$pid"/loginuid)


	for jarwar in $(readlink $pid/fd/* |egrep '\.jar$|\.war$')
	do
		if ! rpm -qf "$jarwar" >/dev/null 2>&1 \
		&& ! dpkg-query -S "$jarwar" >/dev/null 2>&1
		then
			reportonfile "$jarwar" "$procowner" "Process owner" "pid=\"${pid##*/}\" procowner=\"$procowner\" procuid=\"$procuid\" loginuid=\"$loginuid\" NotFromAPackage"
		fi
		if dpkg-query -S "$jarwar" >/dev/null 2>&1
		then
			packagename=$(dpkg-query -S "$jarwar" |cut -d':' -f1)
			packageversion=$(dpkg-query -s $packagename |awk '/^Version: / {print $2}')
			reportonfile "$jarwar" "$procowner" "Process owner" "pid=\"${pid##*/}\" procowner=\"$procowner\" procuid=\"$procuid\" loginuid=\"$loginuid\" dpkg_package_name=\"$packagename\" dpkg_package_version=\"$packageversion\""   
		fi
		if rpm -qif "$jarwar" >/dev/null 2>&1
		then
			packagename=$(rpm -qif "$jarwar" |awk '/^Name/ {print $3}' |head -1)
			packageversion=$(rpm -qif "$jarwar" |awk '/^Version/ {print $3}' |head -1)
			packagerelease=$(rpm -qif "$jarwar" |awk '/^Release/ {print $3}' |head -1)
			reportonfile "$jarwar" "$procowner" "Process owner" "pid=\"${pid##*/}\" procowner=\"$procowner\" procuid=\"$procuid\" loginuid=\"$loginuid\" rpm_package_name=\"$packagename\" rpm_package_version=\"$packageversion\" rpm_package_release=\"$packagerelease\""   
		fi
	done
	
    timeoutcheck "$timeout" "$startepoch" "$startsleep"
done

printexitstats "$startepoch" "$startsleep" "\"completed\" totalproccount=\"$totalproccount\" chrootcount=\"$chrootcount\""

