Anakrino is a Splunk application that utilizes the fschange function and several bash scripts to examine Linux settings and changes.

INSTALLATION:
1) zip the anakrino-linux directory and install it as an application in Splunk.
2) Modify the shell scripts in the scripts directory to email you the reports.

DATA COLLECTION SCRIPTS:
1) croncheck.sh - Outputs to the anakrino index with sourcetype croncheck.  This script shows what executable is run through cron along with the executable owner, permissions, mountpoint, and filesystem.
    Things admins should look for:
    1) Scripts that are owned by a different user than the cron user.  This could lead to a compromise of the cron user's account.  The script owner has the ability to execute commands as the cron user.
    2) Scripts that have world-writable permissions that could allow manipulation.
    3) Scripts that are run from an NFS share.  The scripts could be manipulated by a compromised or rogue server that has access to that NFS share.

2) localusers.sh - Outputs to the anakrino index with the localuserslinux sourcetype.  This script will show the shell, password age, password expiration date, if a password is set, and if the user has an authorization ssh key.
    Things admins should look for:
    1) Service accounts with shells and passwords that otherwise should not.
    2) Password expired accounts.

3) modpkgcheck.sh - Outputs to anakrino index with the modpkgcheck sourcetype.  This script will show active kernel modules that do not belong to an rpm or dpkg package.
    Things admins should look for:
    1) Any kernel module that is not part of an rpm or dpkg package could be a rootkit.

4) pkgcheck.sh - Outputs to anakrino index with the pkgcheck sourcetype.  This script will perform rpm and dpkg integrity checks and only report on files that do not match the package contents.  This is more useful than a traditional FIM as it continually alerts on file integrity mismatches.  Traditional FIM often has false positives resulting from system patching.  This script will randomly sleep between each package check to spread out the system utilization over a period of 20 hours.
    Things admins should look for:
    1) Any checksum mismatch could be a sign of a rootkit.
    2) Permission/ownership changes that could be a misconfiguration.
    3) There may be false positives caused by the application making changes to it's files.

5) procpkgcheck.sh - Outputs to anakrino index with procpkgcheck sourcetype.  This script will examine running processes and report on executables, checksums, owners, package information, etc.  It will ignore any processes in a docker and/or lxc container.
    Things admins should look for:
    1) Any process that does not belong to a known rpm or dpkg could be from a rootkit

6) sshkeyfp.sh - Outputs to the anakrino index with the sourcetype sshkeyfp.  This script will output sha256 and md5 hashes for the ssh keys and authorization keys for all local accounts.  This will help identify which keys can access which accounts.  If you enable verbose logging in sshd_config, it will log the fingerprint hash of the key that was used to authenticate.  Depending on your sshd version, it will output either md5 or sha256.  

7) sudoerscheck.sh - Outputs to the anakrino index with the sourcetype sudoers.  This script will parse the sudoers configuration and output in key=value pairs.  If the user is a %group, it will append the members of that group.  It will alert to bad ownership/permissions on scripts.
    Things admins should look for:
    1) Scripts that are owned by a different user than the runas user.  This could lead to a compromise.  The script owner has the ability to execute commands as the runas user.
    2) Excessive sudo permissions
8) docker.sh - Ouputs to the anakrino index with the sourcetype docker.  This script will list docker names, images, commands, and ports.
9) libkitcheck.sh - Outputs to the anakrino index with the sourcetype libkitcheck.  This script will examine the ld library cache and check each library file to make sure it belongs to a known installed package.  Next, it will examine the loaded libraries for each process and again check to make sure it belongs to a known installed package as well as alert for any process that was executed with LD_PRELOAD.
    Things admins should look for:
    1) Any output from this script should be examined.  It may be a library from a rootkit.
10) nonpkgcheck.sh - Outputs to the anakrino index with the sourcetype nonpkgcheck.  This script finds all the directories that were created by packages and then searches those directories for files that do not belong to a package.
    Things admins should look for:
    1) There will be false positives.  Look for mystery executables.
11) sysinfo.sh - Outputs to the anakrino index with the sourcetype sysinfo.  This will output OS and hardware information
12) patchinfo.sh - Outputs to the anakrino index with sourcetype patchinfo.  This script will show a count of missing security patches.
13) socketlist.sh - Outputs to the anakrino index with the sourcetype socketlist.  This script will show what programs, and users, that have listening sockets.
14) jarwarinfo.sh - Searches for java processes and outputs jar and war info.
15) javaversion.sh - Finds running java processes and outputs the version.


REPORT SCRIPTS:
The scripts directory contains bash and python scripts to schedule in Splunk.  These will generate email reports in html.  You will need to copy these to the bin/scripts directory where you installed Splunk.  Below is a list of the scripts and the search query I run in the scheduled searches.  You will need to edit all the bash scripts to update the --mailfrom --mailto and --smtp (the smtp server).  I schedule my scripts to run once per day and query the past 24 hours.
