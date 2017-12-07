#!/bin/bash
# 20171206 Kirby

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


# startup sleep for server farms sharing disk
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 1800 ))
startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
# MAIN


id_arr=()

for flag in 's' 'n' 'r' 'v' 'm' 'p' 'i' 'o'
do
    id="uname_${flag}"
    if id_data=$(uname -$flag 2>/dev/null)
    then
        id_arr+=("$id=\"$id_data\"")
    fi
    sleep 1
done

if [[ -f /etc/os-release ]]
then
    for id in NAME VERSION VERSION_ID ID ID_LIKE PRETTY_NAME VARIANT VARIANT_ID
    do
        if id_data=$(egrep "^$id=" /etc/os-release |cut -d'=' -f2 |head -1 |sed -e 's/"//g'|egrep .)
        then
            id=$(echo "os_$id" | tr '[:upper:]' '[:lower:]')
            id_arr+=("$id=\"$id_data\"")
        fi
        sleep 1
    done
elif [[ -f /etc/redhat-release ]]
then
    redhatrel=$(head -1 /etc/redhat-release)
    id_arr+=("redhat_release=\"$redhatrel\"")
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
    sleep 1
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
    sleep 1
fi

oneline=$(join_by ' ' "${id_arr[@]}")
echo "$oneline"


printexitstats "$startepoch" "$startsleep" "completed"
