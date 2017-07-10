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


# terminate script after $timeout seconds pass
timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 18000 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
# MAIN

IFS=$'\n'

#
# find all the includes
#
includes=()
includes+=("/etc/sudoers")
for line in $(sed -e 's/^\s*//g' /etc/sudoers |egrep -i '^#include |^#includedir ' |awk '{print $2}')
do
    if echo "$line" |grep -q '%h'
    then
        hostname=$(uname -n)
        line=$(echo "$line" |sed -e "s/%h/$hostname/g")
    fi
    if [[ -d "$line" ]]
    then
        for file in ${line}/*
        do
            if [[ -f "$file" ]]
            then
                includes+=("$file")
            fi
        done
    elif [[ -f "$line" ]]
    then
        includes+=("$line")
    fi
done


#
# collect all the aliases
#
for sudofile in ${includes[*]}
do
    for line in $(sed -e 's/^\s*//g' "$sudofile" |sed -e 's/\s*$//g' |sed -e ':a;/\\$/{N;s/\n//;ba}' |egrep -v '^#|^Defaults'|egrep -i '^\S+_Alias' |grep '=' |sed -e 's/\t/ /g' |tr -s " " |sed -e 's/\\//g')
    do
        declare -A user_alias_hash
        declare -A runas_alias_hash
        declare -A host_alias_hash
        declare -A cmnd_alias_hash
        if echo "$line" |awk '{print $1}' |grep -qi User_Alias
        then
            key=$(echo "$line" |cut -d'=' -f1|awk '{print $2}')
            val=$(echo "$line" |sed -e 's/.*=\(.*\)/\1/' |tr -d " " )
            #echo "HASH $key $val"
            user_alias_hash["$key"]="$val"
        fi
        if echo "$line" |awk '{print $1}' |grep -qi Runas_Alias
        then
            key=$(echo "$line" |cut -d'=' -f1|awk '{print $2}')
            val=$(echo "$line" |sed -e 's/.*=\(.*\)/\1/' |tr -d " " )
            #echo "HASH $key $val"
            runas_alias_hash["$key"]="$val"
        fi
        if echo "$line" |awk '{print $1}' |grep -qi Host_Alias
        then
            key=$(echo "$line" |cut -d'=' -f1|awk '{print $2}')
            val=$(echo "$line" |sed -e 's/.*=\(.*\)/\1/' |tr -d " " )
            #echo "HASH $key $val"
            host_alias_hash["$key"]="$val"
        fi
        if echo "$line" |awk '{print $1}' |grep -qi Cmnd_Alias
        then
            key=$(echo "$line" |cut -d'=' -f1|awk '{print $2}')
            val=$(echo "$line" |sed -e 's/.*=\(.*\)/\1/' |sed -e 's/^\s*//g' )
            #echo "HASH $key $val"
            cmnd_alias_hash["$key"]="$val"
        fi
    done
done

#
# then read the rest
#
for sudofile in ${includes[*]}
do
    for line in $(sed -e 's/^\s*//g' "$sudofile" |sed -e 's/\s*$//g' |sed -e ':a;/\\$/{N;s/\n//;ba}'|egrep -vi '^#|^Defaults|^\S+_Alias'|grep '=' |sed -e 's/\t/ /g' |tr -s " " |sed -e 's/\\//g')
    do
        user=$(echo "$line" |cut -d'=' -f1 |awk '{print $1}')
        if echo "$user" |grep -qv '%'
        then
            if [[ "${user_alias_hash[$user]}" != '' ]]
            then
                user_alias="${user_alias_hash[$user]}"
            else
                user_alias=""
            fi
        fi
        if echo "$user" |grep -q '%'
        then
            # this is a group
            group=$(echo "$user" |sed -e 's/%//g')
            user_alias="$user:"$(getent group "$group" |cut -d':' -f4)
        fi
    
        if [[ "$user" == "root" ]]
        then
            continue
        fi
    
        # hosts
        hosts=$(echo "$line" |cut -d'=' -f1 |awk '{print $2}')
        if [[ "${host_alias_hash[$hosts]}" != '' ]]
        then
            hosts_alias="${host_alias_hash[$hosts]}"
        else
            hosts_alias=""
        fi
    
        # runas
        if echo "$line" |cut -d'=' -f2 |awk '{print $1}' |grep -q '(' 
        then
            runas=$(echo "$line" |cut -d'=' -f2|awk '{print $1}'|grep '(' |grep ')' |cut -d')' -f1 |cut -d'(' -f2)
        else
            runas=ALL
        fi
        if [[ "${runas_alias_hash[$runas]}" != '' ]]
        then
            runas_alias="${runas_alias_hash[$runas]}"
        else
            runas_alias=""
        fi
    
        # NOPASSWD
        if echo "$line" |cut -d'=' -f2 |grep -q 'NOPASSWD:'
        then
            auth="nopasswd"
        else
            auth="yes"
        fi
    
        # commands
        cmnd=$(echo "$line" |cut -d'=' -f2|cut -d':' -f2-|cut -d')' -f2- |sed -e 's/^\s*//g')
        IFS=','
        cmnd_alias_array=()
        cmnds=()
        for cmnd_element in $cmnd
        do
            cmnd_chomp=$(echo "$cmnd_element" |awk '{print $1}')
            if echo "$cmnd_chomp" |grep -qv '/'
            then
                if [[ "${cmnd_alias_hash[$cmnd_chomp]}" != '' ]]
                then
                    cmnd_alias_array+=("$cmnd_chomp:${cmnd_alias_hash[$cmnd_chomp]} ")
                    for cmnd_alias_element in ${cmnd_alias_hash[$cmnd_chomp]}
                    do
                        cmnd_alias_chomp=$(echo "$cmnd_alias_element" |awk '{print $1}')
                        cmnds+=($cmnd_alias_chomp)
                    done
                fi
            else
                cmnds+=($cmnd_chomp)
            fi
        done
        IFS=$'\n'
        cmnd_alias=$(echo "${cmnd_alias_array[@]}" |sed -e 's/\s*$//g')
    
        # check perms/owners of @cmnds
        for file in ${cmnds[*]}
        do
            # aliases have caused issues
            unset "$file" >/dev/null 2>&1
            unalias "$file" >/dev/null 2>&1
    
            which "$file" >/dev/null 2>&1 || continue
            file=$(which "$file")

            printfileinfo "$file" "$runas" "Runas user" "user=\"$user\" user_alias=\"$user_alias\" hosts=\"$hosts\" hosts_alias=\"$hosts_alias\" runas=\"$runas\" runas_alias=\"$runas_alias\" auth=\"$auth\" cmnd=\"$cmnd\" cmnd_alias=\"$cmnd_alias\""
        done
    
    
        #echo $line
        echo "user=\"$user\" user_alias=\"$user_alias\" hosts=\"$hosts\" hosts_alias=\"$hosts_alias\" runas=\"$runas\" runas_alias=\"$runas_alias\" auth=\"$auth\" cmnd=\"$cmnd\" cmnd_alias=\"$cmnd_alias\""
        
        timeoutcheck "$timeout" "$startepoch"
        sleep $(( ( RANDOM * RANDOM + 1 ) % 30 + 30 ))
    done
done

gotoexit "$startepoch" "completed"
