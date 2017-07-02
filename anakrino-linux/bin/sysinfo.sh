#!/bin/bash
# 20170701 Kirby

renice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

export dIFS=$IFS
export rnIFS=$'\r\n'
export tIFS=$'\t'


# startup sleep for server farms sharing disk
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 300 ))
startepoch=$(date +%s)
#echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep


##################################################
function gotoexit() {
    local result=$1
    endepoch=$(date +%s)
    runtime=$(( endepoch - startepoch ))
    runhour=$(( runtime / 3600 ))
    runmin=0$(( (runtime - ( runhour * 3600 )) / 60 ))
    runmin=${runmin:$((${#runmin}-2)):${#runmin}}
    runsec=0$(( (runtime - ( runhour * 3600 )) % 60 ))
    runsec=${runsec:$((${#runsec}-2)):${#runsec}}
    #echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"$result\""
}

##################################################
function join_by {
    local IFS="$1"
    shift
    echo "$*"
}


##################################################
# MAIN


id_arr=()

for flag in '-s' '-n' '-r' '-v' '-m' '-p' '-i' '-o'
do
    id="uname${flag}"
    if id_data=$(uname $flag 2>/dev/null)
    then
        id_arr+=("$id=\"$id_data\"")
    fi
done

if [[ -f /etc/os-release ]]
then
    for id in NAME VERSION VERSION_ID ID ID_LIKE PRETTY_NAME VARIANT VARIANT_ID
    do
        if id_data=$(egrep "^$id=" /etc/os-release |cut -d'=' -f2 |head -1 |sed -e 's/"//g'|egrep .)
        then
            id=$(echo "os-$id" | tr '[:upper:]' '[:lower:]')
            id_arr+=("$id=\"$id_data\"")
        fi
    done
elif [[ -f /etc/redhat-release ]]
then
    redhatrel=$(head -1 /etc/redhat-release)
    id_arr+=("redhat-release=\"$redhatrel\"")
fi


for id in 'model name' siblings 'cpu cores'
do
    if [[ ! -f /proc/cpuinfo ]]
    then
        break
    fi
    id_data=$(egrep "^$id" /proc/cpuinfo |cut -d':' -f2|head -1|sed -e 's/^ //')
    id=${id/ /_}
    id_arr+=("$id=\"$id_data\"")
done


if cd /sys/class/dmi/id >/dev/null 2>&1
then
    for id in bios_date \
    bios_vendor \
    bios_version \
    board_asset_tag \
    board_name \
    board_serial \
    board_vendor \
    board_version \
    chassis_asset_tag \
    chassis_serial \
    chassis_type \
    chassis_vendor \
    chassis_version \
    product_name \
    product_serial \
    product_uuid \
    product_version \
    sys_vendor
    do
        if [[ -f "$id" ]]
        then
            id_data=$(head -1 "$id")
        else
            id_data=""
        fi
        id_arr+=("$id=\"$id_data\"")
    done
fi

oneline=$(join_by ' ' "${id_arr[@]}")
echo "$oneline"


gotoexit "completed"
