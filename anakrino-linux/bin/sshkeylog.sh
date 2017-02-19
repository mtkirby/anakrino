#!/bin/bash
# 20161203 Kirby

nice 20 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

if ! which ssh-keygen >/dev/null 2>&1
then
    echo "ERROR=\"ssh-keygen not installed\""
    exit 1
fi

startepoch=$(date +%s)
echo "starttime=\"$(date)\" startepoch=\"$startepoch\""

IFS='
'

function do_fingerprint()
{
    local file=$1
    if fingerprint=$(ssh-keygen -E md5 -l -f "$file" 2>/dev/null || ssh-keygen -l -f "$file")
    then
        local keysize=$(echo $fingerprint |awk '{print $1}')
        # sometimes there is a MD5: prefix and sometimes there isn't.
        # strip it if it exists and then add it.
        local md5=$(echo $fingerprint |awk '{print $2}' |sed -e 's/^MD5://' |sed -e 's/^/MD5:/')
        local keyowner=$(echo $fingerprint |awk '{print $3}')
        local keyalgo=$(echo $fingerprint |awk '{print $4}')
        local fileowner=$(stat -c "%U" "$file")
        local filedate=$(stat -c "%y" "$file")
        if ssh-keygen -E sha256 -l -f "$file" >/dev/null 2>&1
        then
            local sha256=$(ssh-keygen -E sha256 -l -f "$file" |awk '{print $2}')
        elif [ -f "${file}.pub" ]
        then
            # Try the .pub file.  Cannot regenerate via -y cuz it may prompt for passphrase.
            if which awk base64 sha256sum xxd sed >/dev/null 2>&1
            then
                local sha256=SHA256:$(cat ${file}.pub |awk '{print $2}' |base64 -d |sha256sum -b |awk '{print $1}'|xxd -r -p |base64 |sed -e 's/=\+$//')
            else
                local sha256=""
            fi
        else
            local sha256=""
        fi
        echo "file=\"$file\" keysize=\"$keysize\" md5=\"$md5\" sha256=\"$sha256\" keyowner=\"$keyowner\" keyalgo=\"$keyalgo\" fileowner=\"$fileowner\" filedate=\"$filedate\""
    fi
}

for homedir in $(cat /etc/passwd |cut -d':' -f 6 |sort|uniq)
do
    for file in $(grep -l 'PRIVATE KEY' ${homedir}/.ssh/* 2>/dev/null)
    do
        do_fingerprint "$file"
    done

    file="${homedir}/.ssh/authorized_keys"
    if [ -f "$file" ]
    then
        if ! which base64 md5sum >/dev/null 2>&1
        then
            continue
        fi
        for line in $(cat "$file" |egrep -v '^$|^#' |egrep ".*-.* .*" |sort|uniq)
        do
            keysize=""
            if which base64 md5sum >/dev/null 2>&1
            then
                md5=MD5:$(echo $line |awk '{print $2}'|base64 -d|md5sum |awk '{print $1}'|sed -e 's/\(..\)/:\1/g' |sed -e 's/^://')
            else
                md5=""
            fi
            if which base64 sha256sum >/dev/null 2>&1
            then
                sha256=SHA256:$(echo $line |awk '{print $2}'|base64 -d|sha256sum |awk '{print $1}')
            else
                sha256=""
            fi
            keyowner=$(echo $line |awk '{print $3}')
            keyalgo=$(echo $line |awk '{print $1}')
            fileowner=$(stat -c "%U" "$file")
            filedate=$(stat -c "%y" "$file")
            echo "file=\"$file\" keysize=\"$keysize\" md5=\"$md5\" sha256=\"$sha256\" keyowner=\"$keyowner\" keyalgo=\"$keyalgo\" fileowner=\"$fileowner\" filedate=\"$filedate\""
        done
    fi
done



endepoch=$(date +%s)
runtime=$(( $endepoch - $startepoch ))
runhour=$(( $runtime / 3600 ))
runmin=0$(( ($runtime - ( $runhour * 3600 )) / 60 ))
runmin=${runmin:$((${#runmin}-2)):${#runmin}}
runsec=0$(( ($runtime - ( $runhour * 3600 )) % 60 ))
runsec=${runsec:$((${#runsec}-2)):${#runsec}}
echo "endtime=\"$(date)\" endepoch=\"$endepoch\" runtimesec=\"$runtime\" runtime=\"${runhour}:${runmin}:${runsec}\" result=\"complete\""


