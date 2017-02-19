start-sleep (get-random -maximum 72000 -minimum 1800)
$starttime = get-date
write-host starttime=`"$starttime`"
(Get-Process -Id $pid).priorityclass = "Idle"

get-process |select-object Path |foreach-object { if ( $_.Path -match ".*:\.*" ) { & "$env:SPLUNK_HOME\etc\apps\anakrino-windows\bin\sigcheck.exe" /accepteula -h -ct -e -q $_.Path  | % {$_.replace("`"","")} |convertfrom-csv -Delimiter "`t" |foreach-object { if (( $_.Verified -ne 'Signed' ) -and ( $_.Publisher -ne 'Microsoft Corporation' ) -and ( $_.Publisher -ne '(Verified) Microsoft Windows' ) -and ( $_.Path -notmatch "InfusedApps" )) { write-host "Path="$_.Path " Verified="$_.Verified " Date="$_.Date " Publisher="$_.Publisher " Description="$_.Description " Product="$_.Product " ProductVersion="$_.'Product Version' " FileVersion="$_.'File Version' " MD5="$_.MD5 " SHA1="$_.SHA1 " PESHA1="$_.PESHA1 " PESHA256="$_.PESHA256 " SHA256="$_.SHA256 ' ' -Separator `" } } } }


$endtime = get-date
$runtime = (new-timespan -start $starttime -end $endtime).totalseconds
write-host endtime=`"$endtime`" runtime=`"$runtime`"


