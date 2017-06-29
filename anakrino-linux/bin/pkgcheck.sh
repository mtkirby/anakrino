#!/bin/bash
# 20170624 Kirby

if uname -n |egrep -q 'dev|test|lte|sys|cte|\.dt0'
then
    echo "NON-PCI SYSTEM"
    exit 0
fi

renice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

dIFS=$IFS
nlIFS='
'


# terminate script after $timeout seconds pass
# 1 week minus 10 minutes
timeout=$(( $(date +"%s") + 604200 ))

# startup sleep for server farms sharing disk
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 36000 ))
startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
function join_by { 
    local IFS="$1"
    shift
    echo "$*"
}

##################################################
function rpmcheck() {
    local pkg=$1
    local comments=()
    local filemode=''
    local filegroup=''
    local pkgmode=''
    local pkguser=''
    local pkggroup=''
    local file=""
    local attr=""
    local flatcomments=""

    # Check to see if package still exists.
    # Ignore package if this system is in the middle of patching
    if ! rpm -q "$pkg" >/dev/null 2>&1
    then
        return 1
    fi

    IFS=$nlIFS
    for line in $(rpm -V --nodeps --nomtime "$pkg")
    do
        file="${line##* }"
        attr="${line%% *}"
        comments=()

        if [[ "x$file" != "x" ]]
        then
            [[ "$attr" == "missing" ]] && comments+=("file is missing.")
            [[ "${attr:0:1}" == "S" ]] && comments+=("file size differs.")
            if [[ "${attr:1:1}" == "M" ]]
            then
                pkgmode=$(rpm -qil --dump "$pkg" |egrep "^$file " |head -1 |awk '{print $5}' |sed -e 's/.*\(....\)/\1/')
                filemode=$(stat -c "%a" "$file")
                comments+=("mode differs: was $pkgmode and is now $filemode.")
            fi
            [[ "${attr:2:1}" == "5" ]] && comments+=("digest differs.")
            [[ "${attr:3:1}" == "D" ]] && comments+=("device major/minor mismatch.")
            [[ "${attr:4:1}" == "L" ]] && comments+=("readlink path mismatch.")
            if [[ "${attr:5:1}" == "U" ]]
            then
                pkguser=$(rpm -qil --dump "$pkg" |egrep "^$file " |head -1 |awk '{print $6}')
                fileuser=$(stat -c "%U" "$file")
                comments+=("user ownership differs: was $pkguser, is now $fileuser.")
                fi
            if [[ "${attr:6:1}" == "G" ]]
            then
                pkggroup=$(rpm -qil --dump "$pkg" |egrep "^$file " |head -1 |awk '{print $7}')
                filegroup=$(stat -c "%G" "$file")
                comments+=("group ownership differs: was $pkggroup, is now $filegroup.")
            fi
            [[ "${attr:7:1}" == "T" ]] && comments+=("mtime differs. ")
            [[ "${attr:8:1}" == "P" ]] && comments+=("capabilities differ. ")
            flatcomments=$(join_by '  ' "${comments[@]}")
            echo "pkg=\"$pkg\" attr=\"$attr\" file=\"$file\" comments=\"$flatcomments\""
        fi
    done
    IFS=$dIFS
}

##################################################
function dpkgcheck() {
    local pkg=$1
    local comments=()
    local file=""
    local attr=""
    local flatcomments=""

    # Check to see if package still exists.
    # Ignore package if this system is in the middle of patching
    if ! dpkg -s "$pkg" >/dev/null 2>&1
    then
        return 1
    fi

    IFS=$nlIFS
    for line in $(dpkg -V "$pkg")
    do
        file="${line##* }"
        attr="${line%% *}"
        comments=()
        # dpkg doesn't have all the features that rpm has
        if [[ "x$file" != "x" ]]
        then
            [[ "$attr" == "missing" ]] && comments+=("file is missing.")
            [[ "${attr:2:1}" == "5" ]] && comments+=("digest differs.")
            flatcomments=$(join_by '  ' "${comments[@]}")
            echo "pkg=\"$pkg\" attr=\"$attr\" file=\"$file\" comments=\"$flatcomments\""
        fi
    done
    IFS=$dIFS

}

##################################################
function dosleep() {
    local pkgcount=$1
    local count=$2
    local sleep=''
    local avgsleep=''

    # 518400 = 6 days
    avgsleep=$(( 518400 / pkgcount ))
    sleep=$(( avgsleep + ( RANDOM % ( avgsleep / 3 ) ) - ( RANDOM % ( avgsleep / 3 ) ) ))
    #echo "$count / $pkgcount sleep $sleep avg $avgsleep"
    sleep $sleep >/dev/null 2>&1
}

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
function timeoutcheck() {
    local timeout=$1
    if [[ "$(date +"%s")" -gt "$timeout" ]]
    then
        gotoexit "FAILED: Went over $timeout seconds"
        exit 1
    fi
}

##################################################
function lagkill() {
    # Self-terminate if a pkg check takes too long.
    # This is to prevent a snowball effect on shared storage.
    local lagstart=$1
    local lagstop=$2
    local pkg=$3
    local lag=$(( lagstop - lagstart ))
    if [[ $lag -ge 15 ]]
    then
        gotoexit "FAILED: lagged out on $pkg"
        exit 1
    fi
}


##################################################
# MAIN

totalcount=0
if which rpm >/dev/null 2>&1
then
    declare -a rpms
    # ignore kernel packages on the first run.  
    for pkg in $(rpm -qa |egrep -v 'logstash|clamav-data|emacs-common|\-devel\-|\-headers\-|^kernel-|fonts|logos|theme')
    do
        rpms+=("$pkg")
    done
    # add kernel packages only for revision we are running
    for pkg in $(rpm -qa kernel-* |grep "$(uname -r)" |egrep -v '\-devel\-|\-headers\-')
    do
        rpms+=("$pkg")
    done
    pkgcount=${#rpms[@]}
    count=0
    if [[ $pkgcount -ge 1 ]] \
    || [[ $pkgcount =~ ^[[:digit:]]+$ ]]
    then
        for pkg in ${rpms[*]}
        do
            count=$((count + 1))
            lagstart=$(date +%s)
            rpmcheck "$pkg"
            lagstop=$(date +%s)
            lagkill "$lagstart" "$lagstop" "$pkg"
            timeoutcheck "$timeout"
            dosleep "$pkgcount" "$count"
        done
    else
        echo "pkgcount for rpm failed"
    fi
    totalcount=$(( totalcount + count ))
fi


if which dpkg >/dev/null 2>&1
then
    declare -a dpkgs
    # ignore kernel packages on the first run.  
    for pkg in $(dpkg -l |awk '/^ii / {print $2}' |egrep -v 'logstash|clamav|\-dev|\-headers\-|linux-image|fonts|theme')
    do
        dpkgs+=("$pkg")
    done
    # add kernel packages only for revision we are running
    for pkg in $(dpkg -l linux-image*  |awk '/^ii / {print $2}' |grep "$(uname -r)")
    do
        dpkgs+=("$pkg")
    done
    # add kernel packages only for revision we are running
    pkgcount=${#dpkgs[@]}
    count=0
    if [[ $pkgcount -ge 1 ]] \
    || [[ $pkgcount =~ ^[[:digit:]]+$ ]]
    then
        for pkg in ${dpkgs[*]}
        do
            count=$((count + 1))
            lagstart=$(date +%s)
            dpkgcheck "$pkg"
            lagstop=$(date +%s)
            lagkill "$lagstart" "$lagstop" "$pkg"
            timeoutcheck "$timeout"
            dosleep "$pkgcount" "$count"
        done
    else
        echo "pkgcount for dpkg failed"
    fi
    totalcount=$(( totalcount + count ))
fi

gotoexit "completed pkgcount=$totalcount"
