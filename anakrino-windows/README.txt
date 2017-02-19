Anakrino is a Splunk application that utilizes the fschange function and several cmd/powershell scripts to examine Windows settings and changes.  You will need to download the autoruns.exe and sigcheck.exe from Sysinternals and place them with the powershell scripts in the bin directory.  https://download.sysinternals.com/files/Autoruns.zip and https://download.sysinternals.com/files/Sigcheck.zip
The .cmd scripts execute the respective powershell scripts with an unrestricted flag to bypass powershell execution policy.
All scripts will sleep for a random time between 30 minutes to 20 hours to avoid disk contention on virtual machine clusters.  In addition, the scripts will set their priority class to idle.

INSTALLATION:
1) zip the anakrino-windows directory and install it as an application in Splunk.
2) Modify the shell scripts in the scripts directory to email you the reports.

DATA COLLECTION SCRIPTS:
1) autorunsc.ps1 - Outputs to the anakrino-autoruns index.  This script shows drivers, tasks, services, logon processes, and more that are not signed and verified Microsoft applications.
    Things admins should look for:
    1) Anything that is not a signed and verified Microsoft application could be an infection.
    2) There are also md5/sha1&256 checksums that can be searched via VirusTotal to determine if it is a known virus.

2) localusers.ps1 - Outputs to the anakrino-localusers index.  This script will show the last password set, enabled/disabled, password expiration for local users.
    Things admins should look for:
    1) Suspicious accounts.
    2) Password expired accounts.

3) sigcheck.ps1 - Outputs to the anakrino-sigcheck index with the sourcetype sigcheck.  This script will crawl the c:\windows folder and report on executables that are not signed and verified by Microsoft.
    Things admins should look for:
    1) Anything that is not a signed and verified Microsoft application could be an infection.
    2) There are also md5/sha1&256 checksums that can be searched via VirusTotal to determine if it is a known virus.

3) procsigcheck.ps1 - Outputs to the anakrino-sigcheck index with the sourcetype procsigcheck.  This script will examine all running processes and report on executables that are not signed and verified by Microsoft.
    Things admins should look for:
    1) Anything that is not a signed and verified Microsoft application could be an infection.
    2) There are also md5/sha1&256 checksums that can be searched via VirusTotal to determine if it is a known virus.


REPORT SCRIPTS:
The scripts directory contains bash and python scripts to schedule in Splunk(Linux version).  These will generate email reports in html.  You will need to copy these to the bin/scripts directory where you installed Splunk.  Below is a list of the scripts and the search query I run in the scheduled searches.  You will need to edit all the bash scripts to update the --mailfrom --mailto and --smtp (the smtp server).  I schedule my scripts to run once per day and query the past 24 hours.
