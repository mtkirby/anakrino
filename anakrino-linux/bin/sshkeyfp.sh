#!/bin/bash
# 20170624 Kirby

if ! which ssh-keygen >/dev/null 2>&1
then
    echo "ERROR=\"ssh-keygen not installed\""
    exit 1
fi

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

# terminate script after $timeout seconds pass
timeout=$(( $(date +"%s") + 86400 ))

startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 18000 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep

##################################################
function join_by {
    local IFS="$1"
    shift
    echo "$*"
}

##################################################
function gotoexit() {
    local result=$1
    endepoch=$(date +%s)
    runtime=$(( endepoch - startepoch ))
    runhour=$(( runtime / 3600 ))
    runmin=0$(( ( runtime - ( runhour * 3600 )) / 60 ))
    runmin=${runmin:$((${#runmin}-2)):${#runmin}}
    runsec=0$(( ( runtime - ( runhour * 3600 )) % 60 ))
    runsec=${runsec:$((${#runsec}-2)):${#runsec}}
    echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"$result\""
}

##################################################
function timeoutcheck() {
    local timeout=$1
    if [[ "$(date +"%s")" -gt "$timeout" ]]
    then
        gotoexit "FAILED: Went over timeout seconds"
        exit 1
    fi  
}

##################################################
function do_fingerprint()
{
    local file=$1
    local keysize=''
    local md5=''
    local keyowner=''
    local keyalgo=''
    local fileowner=''
    local filedate=''
    local sha256=''
    local fpa=()

    if fingerprint=$(ssh-keygen -E md5 -l -f "$file" 2>/dev/null || ssh-keygen -l -f "$file")
    then
        local IFS=' ' fpa=($fingerprint)
        IFS=$rnIFS
        keysize=${fpa[0]}
        # sometimes there is a MD5: prefix and sometimes there isn't.
        # strip it if it exists and then add it.
        md5=$(echo "${fpa[1]}" |sed -e 's/^MD5://' |sed -e 's/^/MD5:/')
        keyowner=${fpa[2]}
        keyalgo=${fpa[3]}
        fileowner=$(stat -c "%U" "$file")
        filedate=$(stat -c "%y" "$file")
        if ssh-keygen -E sha256 -l -f "$file" >/dev/null 2>&1
        then
            sha256=$(ssh-keygen -E sha256 -l -f "$file" |awk '{print $2}')
        elif [[ -f "${file}.pub" ]]
        then
            # Try the .pub file.  Cannot regenerate via -y cuz it may prompt for passphrase.
            if which awk base64 sha256sum xxd sed >/dev/null 2>&1
            then
                sha256=SHA256:$(awk '{print $2}' "${file}.pub" |base64 -d |sha256sum -b |awk '{print $1}'|xxd -r -p |base64 |sed -e 's/=\+$//')
            else
                sha256=''
            fi
        else
            sha256=''
        fi
        echo "file=\"$file\" keysize=\"$keysize\" md5=\"$md5\" sha256=\"$sha256\" keyowner=\"$keyowner\" keyalgo=\"$keyalgo\" fileowner=\"$fileowner\" filedate=\"$filedate\""
    fi
}

##################################################
# MAIN

rnIFS='
'
IFS=$rnIFS
for homedir in $(cut -d':' -f 6 /etc/passwd |sort|uniq)
do
    for file in $(grep -l 'PRIVATE KEY' "$homedir"/.ssh/* 2>/dev/null)
    do
        do_fingerprint "$file"
    done

    file="${homedir}/.ssh/authorized_keys"
    if [[ -f "$file" ]]
    then
        if ! which base64 md5sum >/dev/null 2>&1
        then
            continue
        fi
        for line in $(egrep -v '^$|^#' "$file" |egrep ".*-.* .*" |sort|uniq)
        do
            md5=''
            sha256=''
            IFS=' ' aka=($line)
            IFS=$rnIFS
            if which base64 md5sum >/dev/null 2>&1
            then
                md5=MD5:$(echo "${aka[1]}" |base64 -d|md5sum |awk '{print $1}'|sed -e 's/\(..\)/:\1/g' |sed -e 's/^://')
            fi
            if which base64 sha256sum >/dev/null 2>&1
            then
                sha256=SHA256:$(echo "${aka[1]}" |base64 -d|sha256sum |awk '{print $1}')
            fi
            keyalgo=${aka[0]}
            keyowner=${aka[2]}
            fileowner=$(stat -c "%U" "$file")
            filedate=$(stat -c "%y" "$file")
            echo "file=\"$file\" md5=\"$md5\" sha256=\"$sha256\" keyowner=\"$keyowner\" keyalgo=\"$keyalgo\" fileowner=\"$fileowner\" filedate=\"$filedate\""
        done
    fi
    sleep $(( ( RANDOM * RANDOM + 1 ) % 60 + 30 ))
done


gotoexit "completed"

