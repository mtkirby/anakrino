start-sleep (get-random -maximum 36000 -minimum 1800)
$starttime = get-date
write-host starttime=`"$starttime`"
(Get-Process -Id $pid).priorityclass = "Idle"

Get-HotFix | measure-object InstalledOn -Maximum |foreach-object { write-host "updater="windows " lastpatchdate="$_.Maximum  ' ' -Separator `" }

$endtime = get-date
$runtime = (new-timespan -start $starttime -end $endtime).totalseconds
write-host endtime=`"$endtime`" runtime=`"$runtime`"

