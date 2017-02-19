#!/bin/bash
# 20160909 Kirby

renice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

dIFS=$IFS
nlIFS='
'

startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\""

# terminate script after $killsec seconds pass
killsec=$(( $(date +"%s") + 86400 ))

# startup sleep for server farms sharing disk
sleep $(( $RANDOM % 1800 ))

function rpmcheck() {
    local pkg=$1
    local file=$2
    local attr=$3
    local comments=()
    local filemode=''
    local filegroup=''
    local pkgmode=''
    local pkguser=''
    local pkggroup=''

    if [ "x$file" != "x" ]; then
        [ "$attr" == "missing" ] && comments+=("file is missing. ")
        [ "${attr:0:1}" == "S" ] && comments+=("file size differs. ")
        if [ "${attr:1:1}" == "M" ]; then
            pkgmode=$(rpm -qil --dump $pkg |egrep "^$file " |head -1 |awk '{print $5}' |sed -e 's/.*\(....\)/\1/')
            filemode=$(stat -c "%a" $file)
            comments+=("mode differs: was $pkgmode and is now $filemode. ")
        fi
        [ "${attr:2:1}" == "5" ] && comments+=("digest differs. ")
        [ "${attr:3:1}" == "D" ] && comments+=("device major/minor mismatch. ")
        [ "${attr:4:1}" == "L" ] && comments+=("readlink path mismatch. ")
        if [ "${attr:5:1}" == "U" ]; then
            pkguser=$(rpm -qil --dump $pkg |egrep "^$file " |head -1 |awk '{print $6}')
            fileuser=$(stat -c "%U" $file)
            comments+=("user ownership differs: was $pkguser, is now $fileuser. ")
            fi
        if [ "${attr:6:1}" == "G" ]; then
            pkggroup=$(rpm -qil --dump $pkg |egrep "^$file " |head -1 |awk '{print $7}')
            filegroup=$(stat -c "%G" $file)
            comments+=("group ownership differs: was $pkggroup, is now $filegroup. ")
        fi
        [ "${attr:7:1}" == "T" ] && comments+=("mtime differs. ")
        [ "${attr:8:1}" == "P" ] && comments+=("capabilities differ. ")
        echo "pkg=\"$pkg\" attr=\"$attr\" file=\"$file\" comments=\"${comments[@]}\""
    fi
}

function dpkgcheck() {
    local pkg=$1
    local file=$2
    local attr=$3
    local comments=()

    # dpkg doesn't have all the features that rpm has
    if [ "x$file" != "x" ]; then
        [ "$attr" == "missing" ] && comments+=("file is missing. ")
        [ "${attr:2:1}" == "5" ] && comments+=("digest differs. ")
        echo "pkg=\"$pkg\" attr=\"$attr\" file=\"$file\" comments=\"${comments[@]}\""
    fi
}

function dosleep() {
    local pkgcount=$1
    local count=$2
    local sleep=''
    local avgsleep=''

    # spread randomly throughout 20 hours
    # +2 to avoid division by 0 in rare cases
    avgsleep=$(( ( 72000 / $pkgcount ) + 2 ))
    sleep=$(( $avgsleep + ( $RANDOM % ( $avgsleep / 2 ) ) - ( $RANDOM % ( $avgsleep / 2 ) ) - 2 ))
    #echo "$count / $pkgcount sleep $sleep avg $avgsleep"
    sleep $sleep >/dev/null 2>&1
}

function dokill() {
    local killsec=$1
    if [ $(date +"%s") -gt $killsec ]; then
        endepoch=$(date +%s)
        runtime=$(( $endepoch - $startepoch ))
        runhour=$(( $runtime / 3600 ))
        runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
        runmin=${runmin:$((${#runmin}-2)):${#runmin}}
        runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
        runsec=${runsec:$((${#runsec}-2)):${#runsec}}
        echo "end=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"FAILED: Went over $killsec seconds\""
        exit 1
    fi
}


if which rpm >/dev/null 2>&1; then
    pkgcount=$(rpm -qa |wc -l)
    count=0
    for pkg in $(rpm -qa); do 
        count=$(($count + 1))

        # Check to see if package still exists.
        # Ignore package if this system is in the middle of patching
        if ! rpm -q $pkg >/dev/null 2>&1; then
            continue
        fi
    
        IFS=$nlIFS
        for line in $(rpm -V --nodeps --nomtime $pkg); do
            rpmcheck "$pkg" "${line##* }" "${line%% *}" 
        done
        IFS=$dIFS
        dokill $killsec
        dosleep $pkgcount $count
    done
fi


if which dpkg >/dev/null 2>&1; then
    pkgcount=$(dpkg -l |awk '/^ii /' |wc -l)
    count=0
    for pkg in $(dpkg -l |awk '/^ii / {print $2}'); do 
        count=$(($count + 1))
    
        # Check to see if package still exists.
        # Ignore package if this system is in the middle of patching
        if ! dpkg -s $pkg >/dev/null 2>&1; then
            continue
        fi
    
        IFS=$nlIFS
        for line in $(dpkg -V $pkg); do
            dpkgcheck "$pkg" "${line##* }" "${line%% *}" 
        done
        IFS=$dIFS
        dokill $killsec
        dosleep $pkgcount $count
    done
fi

endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""
