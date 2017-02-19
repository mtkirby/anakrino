start-sleep (get-random -maximum 72000 -minimum 1800)
$starttime = get-date
write-host starttime=`"$starttime`"
(Get-Process -Id $pid).priorityclass = "Idle"

$cmd = "& `"$env:SPLUNK_HOME\etc\apps\anakrino-windows\bin\autorunsc.exe`" /accepteula -a * -m -ct -s -h"
Invoke-Expression $cmd 2>$null | % {$_.replace("`"","")} |ConvertFrom-CSV -Delimiter "`t" |ForEach-Object { if (( $_.Verified -ne 'Signed' ) -and ( $_.Publisher -ne 'Microsoft Corporation' ) -and ( $_.Publisher -ne '(Verified) Microsoft Windows' ) -and ( $_.Path -notmatch "InfusedApps" ) -and ( $_.Enabled -eq 'Enabled' )) { write-host "FileTimeStamp="$_.Time " EntryLocation="$_.'Entry Location' " Entry="$_.Entry " Enabled="$_.Enabled " Category="$_.Category " Profile="$_.Profile " Description="$_.Description " Publisher="$_.Publisher " ImagePath="$_.'Image Path' " Version="$_.Version " LaunchString="$_.'Launch String' " MD5="$_.MD5 " SHA-1="$_.'SHA-1' " PESHA-1="$_.'PESHA-1' " PESHA-256="$_.'PESHA-256' " SHA-256="$_.'SHA-256' " IMP="$_.IMP ' ' -Separator `" } }


$endtime = get-date
$runtime = (new-timespan -start $starttime -end $endtime).totalseconds
write-host endtime=`"$endtime`" runtime=`"$runtime`"
