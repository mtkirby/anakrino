start-sleep (get-random -maximum 72000 -minimum 1800)
$starttime = get-date
write-host starttime=`"$starttime`"
(Get-Process -Id $pid).priorityclass = "Idle"

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$PrincipalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $env:computername)
Get-WmiObject -Class Win32_UserAccount -ComputerName $env:computername -Filter "LocalAccount='True'" |where-object { $_.Status -eq 'OK' } | foreach-object { $User = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($PrincipalContext, $_.Name) ; write-host "username="$_.Name " lastpasswordset="$User.LastPasswordSet " disabled="$_.Disabled " passwordexpires="$_.PasswordExpires " passwordrequired="$_.PasswordRequired " FullName="$_.FullName ' ' -Separator `" }


$endtime = get-date
$runtime = (new-timespan -start $starttime -end $endtime).totalseconds
write-host endtime=`"$endtime`" runtime=`"$runtime`"

