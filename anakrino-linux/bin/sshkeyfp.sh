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


if ! which ssh-keygen >/dev/null 2>&1
then
    echo "ERROR=\"ssh-keygen not installed\""
    exit 1
fi


startepoch=$(date +%s)
startsleep=$(( ( RANDOM * RANDOM + 1 ) % 18000 ))
echo "starttime=\"$(date)\" startepoch=\"$startepoch\" startsleep=\"$startsleep\""
sleep $startsleep


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
        local IFS=$'\n'
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

IFS=$'\n'
for homedir in $(cut -d':' -f 6 /etc/passwd |sort|uniq)
do
    for file in $(grep -l 'PRIVATE KEY' "$homedir"/.ssh/* 2>/dev/null)
    do
        do_fingerprint "$file"
    done

    file="${homedir}/.ssh/authorized_keys"
    if [[ -f "$file" ]]
    then
        for line in $(egrep -v '^$|^#' "$file" |egrep ".*-.* .*" |sort|uniq)
        do
            md5=''
            sha256=''
            IFS=' ' aka=($line)
            IFS=$'\n'
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


gotoexit "$startepoch" "completed"

