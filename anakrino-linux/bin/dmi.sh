#!/bin/bash
# 20170628 Kirby

renice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

export dIFS=$IFS
export rnIFS=$'\r\n'
export tIFS=$'\t'


# startup sleep for server farms sharing disk
#startsleep=$(( ( RANDOM * RANDOM + 1 ) % 3600 ))
startepoch=$(date +%s)
#echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
#sleep $startsleep


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
    echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"$result\""
}

##################################################
function join_by {
    local IFS="$1"
    shift
    echo "$*"
}


##################################################
# MAIN


if ! cd /sys/class/dmi/id
then
    gotoexit "unable to cd /sys/class/dmi/id"
    exit 1
fi

id_arr=()

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

dmidata=$(join_by ' ' "${id_arr[@]}")
echo "$dmidata"


gotoexit "completed"
