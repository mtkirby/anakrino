start-sleep (get-random -maximum 72000 -minimum 180)
$starttime = get-date
write-host starttime=`"$starttime`"
(Get-Process -Id $pid).priorityclass = "Idle"

$w32os=Get-WmiObject -Class Win32_OperatingSystem
$w32cs=Get-WmiObject -Class Win32_ComputerSystem
$w32bios=Get-WmiObject -Class Win32_BIOS 
$cim=Get-CimInstance CIM_Processor 

write-host "OSComputerName="$w32os.PSComputerName " OSBuildNumber="$w32os.BuildNumber " OSCaption="$w32os.Caption " OSCSDVersion="$w32os.CSDVersion " OSVersion="$w32os.Version " CSManufacturer="$w32cs.Manufacturer " CSModel="$w32cs.Model " CSDomain="$w32cs.Domain " BiosVersion="$w32.Version " BiosManufacturer="$w32bios.Manufacturer " BiosSerialNumber="$w32bios.SerialNumber " BiosSMBIOSVersion="$w32bios.SMBIOSBIOSVersion " CimName="$cim.Name " CimNumberOfCores="$cim.NumberOfCores " CimNumberOfLogicalProcessors="$cim.NumberOfLogicalProcessors ' ' -Separator `"


$endtime = get-date
$runtime = (new-timespan -start $starttime -end $endtime).totalseconds
write-host endtime=`"$endtime`" runtime=`"$runtime`"

