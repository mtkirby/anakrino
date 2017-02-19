start-sleep (get-random -maximum 72000 -minimum 1800)
$starttime = get-date
write-host starttime=`"$starttime`"
(Get-Process -Id $pid).priorityclass = "Idle"


$cmd = "& `"$env:SPLUNK_HOME\etc\apps\anakrino-windows\bin\sigcheck.exe`" /accepteula -h -ct -e -q -s c:\windows"
Invoke-Expression $cmd 2>$null |% {$_.replace("`"","")} |% {$_.replace('\r\n',"`n")} |% {$_.replace('[^"6]\n',".")} |% {$_.replace('[^"6]\n',".")} |convertfrom-csv -Delimiter "`t" |foreach-object { if (( $_.Verified -ne 'Signed' ) -and ( $_.Publisher -ne 'Microsoft Corporation' ) -and ( $_.Publisher -ne '(Verified) Microsoft Windows' ) -and ( $_.Path -notmatch "InfusedApps" )) { write-host "Path="$_.Path " Verified="$_.Verified " Date="$_.Date " Publisher="$_.Publisher " Description="$_.Description " Product="$_.Product " ProductVersion="$_.'Product Version' " FileVersion="$_.'File Version' " MD5="$_.MD5 " SHA1="$_.SHA1 " PESHA1="$_.PESHA1 " PESHA256="$_.PESHA256 " SHA256="$_.SHA256 ' ' -Separator `" } }

# old method
#$logfile = "$env:SPLUNK_HOME\var\log\sigcheck.log"
#& "$env:SPLUNK_HOME\etc\apps\anakrino-windows\bin\sigcheck.exe" /accepteula -h -ct -e -q -s c:\windows > $logfile
#( Get-Content $logfile -Raw ) -replace '\r\n',"`n" -replace '[^"6]\n',"." -replace '[^"6]\n',"." |convertfrom-csv -Delimiter "`t" |foreach-object { if (( $_.Verified -ne 'Signed' ) -and ( $_.Publisher -ne 'Microsoft Corporation' ) -and ( $_.Publisher -ne '(Verified) Microsoft Windows' ) -and ( $_.Path -notmatch "InfusedApps" )) { write-host "Path="$_.Path " Verified="$_.Verified " Date="$_.Date " Publisher="$_.Publisher " Description="$_.Description " Product="$_.Product " ProductVersion="$_.'Product Version' " FileVersion="$_.'File Version' " MD5="$_.MD5 " SHA1="$_.SHA1 " PESHA1="$_.PESHA1 " PESHA256="$_.PESHA256 " SHA256="$_.SHA256 ' ' -Separator `" } }

$endtime = get-date
$runtime = (new-timespan -start $starttime -end $endtime).totalseconds
write-host endtime=`"$endtime`" runtime=`"$runtime`"
