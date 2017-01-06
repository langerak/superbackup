#!/bin/bash
#
# The SuperBackup Suite created by Jeffrey Langerak
#
# Bugs and/or features can be left at the repository below:
# https://github.com/langerak/superbackup
#
# Setting global version used for updates:
VERSION="0.9.0"
cur_epoch=`date +%s`
export LANG="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
logger -t superbackup_script "Started the SuperBackup Script version $VERSION"
# Load configfile:
if [ -f /etc/superbackup/backup.conf ];
then
    source /etc/superbackup/backup.conf
	logger -t superbackup_script "Loaded the backup configuration file"
else
    clear
    echo -e "Could not find the configfile located in:\n/etc/superbackup/backup.conf"; echo
    echo -e "Please download and run the installer:"
    echo -e "wget -O superbackup-installer.sh https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-installer.sh\nchmod +x superbackup-installer.sh\n./superbackup-installer.sh"
	logger -t superbackup_script "Could not find the configfile, exiting..."
    exit
fi
# Checking for log directory:
if ! [ -d /var/log/superbackup/rsync/ ];
then
    if mkdir -p /var/log/superbackup/ > /dev/null 2>&1; mkdir -p /var/log/superbackup/rsync/ > /dev/null 2>&1; mkdir -p /var/log/superbackup/warn/ > /dev/null 2>&1; mkdir -p /var/log/superbackup/error/ > /dev/null 2>&1; mkdir -p /var/log/superbackup/temp/ > /dev/null 2>&1
	then
		logger -t superbackup_script "Created backup logging directory: /var/log/superbackup/"
	else
		logger -t superbackup_script "Error creating backup logging directory: /var/log/superbackup/"
	fi
fi
# Checking for SQL backup directory:
if ! [ -d $MYSQLBACKUPDIR ];
then
	if mkdir -p $MYSQLBACKUPDIR > /dev/null 2>&1
	then
		logger -t superbackup_script "MySQL dump directory created: $MYSQLBACKUPDIR"
	else
		logger -t superbackup_script "Could not create MySQL dump directory: $MYSQLBACKUPDIR"
	fi
fi
if [[ "$1" == "--no-dumps" ]];
then
	MYSQLBACKUP="N"
elif [[ "$1" == "--debug" ]];
then
	set -x
fi
# Functions used in the script:
trap control_c INT
control_c()
{
	echo -e "\n\nCTRL + C caught. Backup will now halt..."
	logger -t superbackup_script "Backupscript halted due to a Control + C"
	if [ -f /var/run/superbackup.lock ];
	then
		if rm /var/run/superbackup.lock > /dev/null 2>&1
		then
			logger -t superbackup_script "Backup lockfile removed"
		else
			logger -t superbackup_script "Backup lockfile could not be removed"
		fi
	fi
	exit
}
sqldumps()
{
	logger -t superbackup_script "Started MySQL dump procedure"
	if [ -d /usr/local/cpanel ];
	then
	        echo -e "\n[MYSQL DATABASE DUMPS]"
		echo -ne "Testing MySQL connectivity: Please wait...  \r"
		mysql -u $MYSQLUSER > /dev/null 2>&1 << TEST
exit
TEST
		mysql=$?
		if [ $mysql = 0 ];
		then
			echo -ne "Testing MySQL connectivity: OK                     \r"; echo
			logger -t superbackup_script "MySQL connection successful"
			# Clear local SQL dump directory:
			echo -ne "Clearing SQL dump directory: Please wait...  \r"
			if [ ! -z "$MYSQLBACKUPDIR" ];
			then
				# We only delete the gzip files as we do not want to trash the filesystem in case of a user fuckup in the config:
				if rm -f "$MYSQLBACKUPDIR"*.gz > /dev/null 2>&1
				then
					echo -ne "Clearing SQL dump directory: OK                     \r"; echo
					logger -t superbackup_script "Cleared the MySQL dump directory: $MYSQLBACKUPDIR"
				else
					echo -ne "Clearing MySQL dump directory: FAILED               \r"; echo
					logger -t superbackup_script "Could not clear the MySQL dump directory: $MYSQLBACKUPDIR"
				fi
			fi
    		databases=`mysql --user=$MYSQLUSER -e 'SHOW DATABASES;' | grep -Ev '(Database|information_schema)'`
    		for db in $databases; do
        		echo -ne "Dumping $db: Please wait...  \r"
				if [[ "$db" == "mysql" ]]
				then
					$NICE_OPTS mysqldump --opt --single-transaction --quick --hex-blob --events --force --user=$MYSQLUSER $db | $NICE_OPTS gzip > $MYSQLBACKUPDIR$db.gz 2> /dev/null
	                echo -ne "Dumping $db: OK (`ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B)            \r"; echo
	                logger -t superbackup_script "Database $db dumped with a size of `ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B"
				elif $NICE_OPTS mysqldump --opt --single-transaction --quick --hex-blob --force --user=$MYSQLUSER $db | $NICE_OPTS gzip > $MYSQLBACKUPDIR$db.gz 2> /dev/null
	            then
	               	echo -ne "Dumping $db: OK (`ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B)            \r"; echo
	               	logger -t superbackup_script "Database $db dumped with a size of `ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B"
	            else
	               	echo -ne "Dumping $db: FAILED               \r"; echo
	               	logger -t superbackup_script "Database $db could not be dumped due to errors!"
	            fi
    		done
    		dumpsize=$(cd $MYSQLBACKUPDIR; du -sch * | grep "tota*l" | awk '{print $1}')
    		echo -e "Total size of dumps: $dumpsize""B"
			logger -t superbackup_script "MySQL dump procedure completed, total size of the dumps is $dumpsize""B"
		else
			echo -e "FAILED\n\nPlease check your MySQL login credentials for MySQL dumps."
			logger -t superbackup_script "MySQL connection could not be set up"
        	if [[ $NOTIFICATIONS == "Y" ]];
        	then
            	for emailaddress in `cat /etc/superbackup/recipients.mail`
            	do
                	mysql_error
            	done
        	fi
		fi
	else
		echo -e "\n[MYSQL DATABASE DUMPS]"
        echo -ne "Testing MySQL connectivity: Please wait... \r"
        mysql -u $MYSQLUSER -p$MYSQLPASS > /dev/null 2>&1 << TEST
exit
TEST
        mysql=$?
        if [ $mysql = 0 ];
        then
            echo -ne "Testing MySQL connectivity: OK                    \r"; echo
            logger -t superbackup_script "MySQL connection successful"
        	# Clear local SQL dump directory:
        	echo -ne "Clearing MySQL dump directory: Please wait... \r"
        	if [ ! -z "$MYSQLBACKUPDIR" ];
			then
				# We only delete the gzip files as we do not want to trash the filesystem in case of a user fuckup in the config:
				if rm -f "$MYSQLBACKUPDIR"*.gz > /dev/null 2>&1
        		then
            		echo -ne "Clearing MySQL dump directory: OK                  \r"; echo
					logger -t superbackup_script "Cleared the MySQL dump directory: $MYSQLBACKUPDIR"
        		else
            		echo -ne "Clearing MySQL dump directory: FAILED              \r"; echo
					logger -t superbackup_script "Could not clear the MySQL dump directory: $MYSQLBACKUPDIR"
				fi
        	fi
			databases=`mysql --user=$MYSQLUSER --password=$MYSQLPASS -e 'SHOW DATABASES;' | grep -Ev '(Database|information_schema)'`
			for db in $databases; do
				echo -ne "Dumping $db: Please wait...   \r"
                if [[ "$db" == "mysql" ]]
                then
                    $NICE_OPTS mysqldump --opt --single-transaction --quick --hex-blob --events --force --user=$MYSQLUSER --password=$MUSQLPASS $MYSQLBACKUPDIR$db | $NICE_OPTS gzip > $db.gz 2> /dev/null
                    echo -ne "Dumping $db: OK (`ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B)            \r"; echo
                    logger -t superbackup_script "Database $db dumped with a size of `ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B"
                elif $NICE_OPTS mysqldump --opt --single-transaction --hex-blob --force --quick --user=$MYSQLUSER --password=$MYSQLPASS $MYSQLBACKUPDIR$db | $NICE_OPTS gzip > $db.gz 2> /dev/null
                then
                   	echo -ne "Dumping $db: OK (`ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B)            \r"; echo
                   	logger -t superbackup_script "Database $db dumped with a size of `ls -hl $MYSQLBACKUPDIR | grep $db.gz | awk '{print $5}'`B"
                else
                   	echo -ne "Dumping $db: FAILED                \r"; echo
                   	logger -t superbackup_script "Database $db could not be dumped due to errors!"
                fi
			done
			dumpsize=$(cd $MYSQLBACKUPDIR; du -sch * | grep "tota*l" | awk '{print $1}')
			echo -e "Total size of dumps: "$dumpsize"B"
			logger -t superbackup_script "MySQL dump procedure completed, total size of the dumps is $dumpsize""B"
        else
            echo -ne "Testing MySQL connectivity: FAILED                \r"; echo
			echo -e "\nPlease check your MySQL login credentials for MySQL dumps."
            logger -t superbackup_script "MySQL connection could not be set up"
			echo "BACKUP WARNING - MySQL password incorrect ($MYSQLUSER)" > /etc/superbackup/nagios.state
            if [[ $NOTIFICATIONS == "Y" ]];
            then
                    for email in `cat /etc/superbackup/recipients.mail`
                    do
                            mysql_error
                    done
            fi
        fi
	fi
}
autoupgrademail()
{
mail -s '[BACKUP] Backupscript upgraded on '$H'' $email <<AUTOUPGRADEMAIL
Dear customer,

Via this way we would like to let you know that the backupscript running
on $H has been automatically upgraded.

The script has been upgraded from version $version to $newversion and is now
available for use.

Changelog:
The changelog can be found at the URL below:
http://download.superbackup.com/pub/files/scripts/backup/changelog-backupscript.txt

Documentation:
For more information, please refer to the backup manual found below:
http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-manual.pdf

Kind regards,

superbackup Support
AUTOUPGRADEMAIL
logger -t superbackup_script "Emailed notification to $email"
}
upgrademail()
{
mail -s '[BACKUP] Backup update available on '$H'!' $email <<UPGRADEMAIL
Dear customer,

Via this way we would like to let you know there is an upgrade available for the backupscript
running on machine $H.

You currently have version $version installed and available is version $newversion.

Upgrade Instructions:
1: Open the SuperBackup installer (see 1a for download instructions)
1a: If you need to download the tool, please use the following commands:
wget -O superbackup-backup-installer http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-installer.txt
chmod +x superbackup-backup-installer
./superbackup-backup-installer
2: Select the upgrade option and select OK.
3: Let the script search for the update and let it install the script for you.
4: Now your backupscript is up-to-date.

Changelog:
The changelog can be found at the URL below:
http://download.superbackup.com/pub/files/scripts/backup/changelog-backupscript.txt

Documentation:
For more information, please refer to the backup manual found below:
http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-manual.pdf

Kind regards,

superbackup Support
UPGRADEMAIL
logger -t superbackup_script "Emailed notification to $email"
}
accountalmostfull()
{
mail -s '[BACKUP] Backupaccount '$BUSER' is almost full!' $email <<ALMOSTFULLMAIL
Dear customer,

Via this way we would like to draw your attention regarding your backupaccount $BUSER used
at $H on backupserver $BSERVER.

Currently, the account $BUSER has used $QUOTAUSE% of it's quota, meaning that the account
is almost full! This could lead to undesirable situations if the account reaches 100%.

There are 3 solutions available:

1. Upgrade your backupaccount (if using a SuperBackupaccount)
If you want to upgrade your backupaccount, refer to the URL below for our pricing page
and send an email to support@superbackup.nl regarding this backupaccount and to what size
the account should be upgraded:
(for pricing, see the URL below)
https://www.superbackup.com/configurator/prices/

2. Lower the retention of the backups.
If you have given extra weekly and/or monthly retention, try lowering it and remove the
appropriate week and/or month from the backupserver in order to free up the space that
is not needed anymore.
The retention can be lowered via the SuperBackup Installer using the Configuration
Editor and the backups can be cleared using (S)FTP or via the Installer using the
Backup Explorer option.

3. Clean up any unneeded files from the server and backupserver.
Check if there are unneeded files and/or folders on the VPS that can be removed. If
there are files and/or folders that do not need to be backupped, please place them
on the exclude list of rsync (can be done via the Installer using the Excludes List
option. Also make sure to remove these files and/or folders from the backupserver
as well, this can be done using (S)FTP or via the Installer using the Backup Explorer
option.

Manual:
The SuperBackup Operation Manual can be found below:
http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-manual.pdf

Support:
Before contacting superbackup, please make sure that you have looked into options 2 and 3
and have read the manual, else we will not be able to fully assist and support you.
Should you not know what is best to do, please send an email to support@superbackup.nl
regarding this backupaccount and state your question

Kind regards,

superbackup Support
ALMOSTFULLMAIL
logger -t superbackup_script "Emailed notification to $email"
}
accountfull()
{
mail -s '[BACKUP] Backupaccount '$BUSER' is full!' $email <<FULLMAIL
Dear customer,

Via this way we would like to draw your attention regarding your backupaccount $BUSER
used at $H on backupserver $BSERVER.

Currently this account has reached it's quota limit, meaning that the account
is completely filled and no backups are made from this point. This could lead
to undesirable situations if your server fails and you are in need of your backups.

There are 3 solutions available:

1. Upgrade your backupaccount (if using a SuperBackupaccount)
If you want to upgrade your backupaccount, refer to the URL below for our pricing page
and send an email to support@superbackup.nl regarding this backupaccount and to what size
the account should be upgraded:
(for pricing, see the URL below)
https://www.superbackup.com/configurator/prices/

2. Lower the retention of the backups.
If you have given extra weekly and/or monthly retention, try lowering it and remove the
appropriate week and/or month from the backupserver in order to free up the space that
is not needed anymore.
The retention can be lowered via the SuperBackup Installer using the Configuration
Editor and the backups can be cleared using (S)FTP or via the Installer using the
Backup Explorer option.

3. Clean up any unneeded files from the server and backupserver.
Check if there are unneeded files and/or folders on the VPS that can be removed. If
there are files and/or folders that do not need to be backupped, please place them
on the exclude list of rsync (can be done via the Installer using the Excludes List
option. Also make sure to remove these files and/or folders from the backupserver
as well, this can be done using (S)FTP or via the Installer using the Backup Explorer
option.

Manual:
The SuperBackup Operation Manual can be found below:
http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-manual.pdf

Support:
Before contacting superbackup, please make sure that you have looked into options 2 and 3
and have read the manual, else we will not be able to fully assist and support you.
Should you not know what is best to do, please send an email to support@superbackup.nl
regarding this backupaccount and state your question

Kind regards,

superbackup Support
FULLMAIL
logger -t superbackup_script "Emailed notification to $email"
}
mysql_error()
{
mail -s "[BACKUP] MySQL connection error on $H" $wmail <<MAIL
Dear customer,

This is a message to inform you that there is a problem regarding the MySQL
dumps feature.

The backupscript has tested the MySQL connection before the dumps are started
and this connection has failed.

Currently, the following credentials are given:

[MYSQL]
Username..: $MYSQLUSER
Password..: See backup config

Please check if these credentials are still in use, if they have changed, please
change the credentials using the Configuration Editor via the backup installer.

At this time, no SQL dumps have been made.

Kind regards,

SuperBackup Script
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
lockmail()
{
mail -s "[BACKUP] Current job not started on $H" $email <<MAIL
Dear customer,

This is a message to inform you that the backupscript could not start, because
the backup lockfile still exists.

The script has investigated this problem and has stated that the current
running backup process has not passed the 24 hour run limit yet.

Therefore this backup job will not continue to make sure that the current process
can succeed without errors.

Should the next backup task result in a running process as well, then the old
backup process will be killed and that job will start instead of it, this to
prevent any hanging scripts and backups not being made.

Currently, there is no intervention needed from your side, the backupscript has
already chosen the appropriate solution at this point.

Your files have not been backupped during this session.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
lockmail24h()
{
mail -s "[BACKUP] Notification regarding backup process on $H" $email <<MAIL
Dear customer,

This is a message to inform you that the backupscript has stated that the last
initiated job was still running after 24 hours. Since this is unusual behaviour
and could lead to hanging backup processes the script has killed the old
task so this session can be started.

At this point, if you do not receive an account warning stating that the account
is (almost) full, all should be fine again. 
Should this process hang for 24 hours as well, you will receive this message
again, then the backupscript needs investigation to see what is causing the troubles.

The details that the script uses are (for investigational purposes):
Backupserver...: $BSERVER
Username.......: $BUSER
SSH Port.......: $SSHPORT

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_12()
{
mail -s "[BACKUP] Critical error occurred during the backup on $H" $email <<MAIL
Dear customer,

This is a message to inform you that your backup has not succeeded, because the
backupscript was not able to connect to the given backupserver.

The details that the script uses are:
Backupserver...: $BSERVER
Username.......: $BUSER
SSH Port.......: $SSHPORT

Please check the above settings and make sure they are correct, in addition, try
connecting to the server by hand using a FTP client like FileZilla.

A sample SSH connection can be setup using the example below:
ssh -p $SSHPORT -i $PRIVKEY $BUSER@$BSERVER quota

This should return the current quota for that account, if this works, the SSH
connection was successful.

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_20()
{
mail -s "[BACKUP] Critical error occurred during the backup on $H" $email <<MAIL
Dear customer,

This is a message to inform you that your backup has not succeeded during this
session, because the backupscript received a kill from the system.
It's possible that you or another admin stopped the backup on purpose, if so,
please ignore this error.

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_30()
{
mail -s "[BACKUP] Notification regarding the backup on $H!" $email <<MAIL
Dear customer,

This is a message to inform you that the this backup session did not run
because there was a timeout connecting to $BSERVER using user $BUSER.
Please check your network settings and try if you are able to set
up a connection manually from the VPS using FTP/SFTP.

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_35()
{
mail -s "[BACKUP] Notification regarding the backup on $H!" $email <<MAIL
Dear customer,

This is a message to inform you that the this backup session did not run
because of the following reasons:
- Rsync is not installed on the backupserver $BSERVER
- Rsyncd is not running on the backupserver $BSERVER

Please check the above on $BSERVER and try again.

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_134()
{
mail -s "[BACKUP] Notification regarding the backup on $H!" $email <<MAIL
Dear customer,

This is a message to inform you that the this backup session did not run
because it received an abort signal from the system.

Please check if any process limiting facilities are running, or if another
administrator of this server has stopped the job and try again.

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_137()
{
mail -s "[BACKUP] Notification regarding the backup on $H!" $email <<MAIL
Dear customer,

This is a message to inform you that the backup has generated an internal
error and therefore halted. This is mostly caused by folders that use
a chroot environment and is often used with DNS servers.

There is a log available with those warnings and is placed at the following
location:
/var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn

Please refer to the logfile above and locate the file and/or folder that
is cuasing the crash and place it on the exclude list via the installer and
try again.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
rsync_error_unknown()
{
mail -s "[BACKUP] Critical error occurred during the backup!" $email <<MAIL
Dear customer,

This is a message to inform you that your backup has not succeeded, because the
backup process stopped with a unkown error code $retval.

The details that the script uses are:
Backupserver...: $BSERVER
Username.......: $BUSER
SSH Port.......: $SSHPORT
Remote path....: $REMOTEPATH
Local path.....: $BACKUPROOT

Please check the above settings and make sure they are correct, in addition, try
connecting to the server by hand using a FTP client like FileZilla.

In case of error 255 this mostly means that the backupserver cannot be reached.
Please make sure that you are able to login via password and check if the key
is present in the .ssh folder in authorized_keys file.

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
csferror()
{
mail -s "[BACKUP] Critical error occurred during the backup!" $email <<MAIL
Dear customer,

This is a message to inform you that your backup has not succeeded, because the
backupscript could not add the backupserver IP to the CSF whitelist!

Please issue the following command manually to fix this issue:

csf -a $backupip

Your files have not been backupped at this time.

Kind regards,

SuperBackupscript
MAIL
logger -t superbackup_script "Emailed notification to $email"
}
# Start the backup process with some output of the configuration first
echo "[BACKUP STARTED ON `date '+%d-%m-%Y'` AT `date '+%H:%M:%S'`]"
# Checking for updates:
currentday=$(date +%e | sed 's/\ //g')
version=$(cat /etc/superbackup/backup.conf | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g')
versionstripped=$(echo $version | sed 's/\.//g')
# Get remote version:
newversion=$(curl -s https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g' | head -1)
newversionstripped=$(echo $newversion | sed 's/\.//g')
if [[ $NOTIFICATIONS == "Y" ]];
then
	if [[ $currentday == $UPDATECHECK ]];
	then
		if [[ $versionstripped < $newversionstripped ]];
		then
			if [[ $AUTOUPDATE == "Y" ]];
			then
                if curl -s -o /usr/local/bin/superbackup https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh > /dev/null 2>&1
                then
                    chmod +x /usr/local/bin/superbackup > /dev/null 2>&1
                    chattr -i /etc/superbackup/backup.conf
                    perl -pi -w -e "s/VERSION=\"$version\"/VERSION=\"$newversion\"/" /etc/superbackup/backup.conf > /dev/null 2> /dev/null
                    chattr +i /etc/superbackup/backup.conf
                    echo -e "Upgrade from $version to $newversion successfuly installed.\n\nThe new script will be used during the next run.\n"
                    logger -t superbackup_script "Found backupscript update, version $newversion is available, update is succesfully installed"
                    clear
                    for email in `cat /etc/superbackup/recipients.mail`
                    do
                            autoupgrademail
                    done
                else
                    echo -e "Upgrade failed, please run the SuperBackup installer to perform the upgrade.\n\nWill now continue...\n\n"
                    logger -t superbackup_script "Found backupscript update, version $newversion, but failed to apply the update..."
                    clear
                fi
			else
				for email in `cat /etc/superbackup/recipients.mail`
				do
        				upgrademail
				done
			fi
		fi
	fi
fi
# Checking for a lockfile and else, create it:
if [ -f /var/run/backup.lock ];
then
	old_epoch=$(cat /var/run/backup.lock | grep Epoch | awk '{print $2}')
	old_pid=$(cat /var/run/backup.lock | grep Pid | awk '{print $2}')
	diff_epoch=$(echo $cur_epoch-$old_epoch | bc)
	if [[ $diff_epoch -gt 86400 ]];
	then
		echo -e "\nThe backupscript is running for 24 hours now, therefore the old instance will now be killed so this session will start..."
		echo -n "Killing pid $old_pid: "
		if kill $old_pid > /dev/null 2>&1
		then
			echo -e "OK"
		else
			echo -e "FAILED, process may have halted and left the lockfile in place, removing..."
			echo -n "Removing lockfile: "
			if rm /var/run/backup.lock > /dev/null 2>&1
			then
				echo -e "OK"
			else
				echo -e "FAILED, no lockfile found"
			fi
		fi
		if [[ $NOTIFICATIONS == "Y" ]];
		then
			echo "BACKUP WARNING - Backup still running after 24 hours" > /etc/superbackup/nagios.state
			for email in `cat /etc/superbackup/recipients.mail`
			do
				lockmail24h
			done
		fi
	else
		echo -e "\nThe backupscript is still running (lockfile exists), but 24 hours have not passed yet, checking if process is alive:\n"
		echo -n "Checking pid $old_pid: "
		if kill -s 0 $old_pid > /dev/null 2>&1
		then
			echo -e "Running"
			echo -e "\nThis session will not continue, because there is another instance of the backupscript running"
			logger -t superbackup_script "Script halted because another instance is still running"
			echo "BACKUP WARNING - Backup still running but within 24 hours period" > /etc/superbackup/nagios.state
			if [[ $NOTIFICATIONS == "Y" ]];
			then
				for email in `cat /etc/superbackup/recipients.mail`
				do
					lockmail
				done
			fi
			exit
		else
			echo -e "Not running, removing lockfile instead to continue:"
			echo -n "Removing lockfile: "
			if rm /var/run/backup.lock > /dev/null 2>&1
			then
				echo -e "OK\n\nThe backupscript will now continue it's normal operation!"
				logger -t superbackup_script "Lockfile removed, because pid $old_pid is not running anymore"
			else
				echo -e "FAILED\n\nThe backupscript will now halt, because of errors with the lockfile..."
				logger -t superbackup_script "Could not remove lockfile, script halted"
				exit
			fi
		fi
	fi 
else
	echo -e "Epoch: `date +%s`\nPid: $$" > /var/run/superbackup.lock
	logger -t superbackup_script "Created backup lockfile"
fi
# Checking if CSF is running on the server, if so, check to see if the backupserver is whitelisted:
if [ -d /etc/csf/ ];
then
    backupip=`dig +short $BSERVER`
    # Check if IP is on the whitelist:
	if ! cat /etc/csf/csf.allow | grep "$backupip" > /dev/null 2>&1
	then
		echo -e "\n[FIREWALL]"
		echo -ne "Adding backupserver IP to CSF whitelist: Please wait... \r"
        if csf -a $backupip > /dev/null 2>&1
		then
			echo -ne "Adding backupserver IP to CSF whitelist: OK                 \r"; echo
        	logger -t superbackup_script "Added IP address $backupip to the whitelist of CSF"
		else
			echo -ne "Adding backupserver IP to CSF whitelist: FAILED             \r"; echo
			echo -e "\nCould not add IP to the whitelist, please do so manually!"
			echo "BACKUP CRITICAL - Could not whitelist backupserver ($backupip)" > /etc/superbackup/nagios.state
            for email in `cat /etc/superbackup/recipients.mail`
            do
                csferror
				logger -t superbackup_script "Could not add $backupip to whitelist, exiting, email sent to $i"
			done
			rm /var/run/superbackup.lock > /dev/null 2>&1
			exit
		fi
	fi
fi
# Log in to the remote server and retrieve local disk usage information for quota calculations:
if ssh -oStrictHostKeyChecking=no -p $SSHPORT -i $PRIVKEY $BUSER@$BSERVER "df -hT --block-size=G $REMOTEPATH | tail -n1" > /tmp/backup_quota 2>&1
then
	REMOTE_BLOCKDEVICE=$(cat /tmp/backup_quota | awk '{print $1}')
	REMOTE_PARTITIONTYPE=$(cat /tmp/backup_quota | awk '{print $2}')
	QUOTATOTALSIZE=$(cat /tmp/backup_quota | awk '{print $3}' | cut -d G -f 1)
	QUOTAUSE=$(cat /tmp/backup_quota | awk '{print $4}' | cut -d G -f 1)
	QUOTASTARTFREE=$(cat /tmp/backup_quota | awk '{print $5}' | cut -d G -f 1)
	QUOTAPERCUSE=$(cat /tmp/backup_quota | awk '{print $6}' | cut -d % -f 1)
	# UNIT=$(grep $BUSER /tmp/backup_quota | awk '{print $2}' | rev | cut -c -1)
    # QUOTATOTALSIZE=$(grep $BUSER /tmp/backup_quota | awk '{print $2}' | tail -1 | cut -d $UNIT -f 1)
    # QUOTAUSE=$(grep $BUSER /tmp/backup_quota | awk '{print $5}' | tail -1 | cut -d % -f 1)
    # QUOTASTARTFREE=$(grep $BUSER /tmp/backup_quota | awk '{print $4}' | tail -1 | cut -d $UNIT -f 1)
	# If the quota is above 90% we send out an email:
	if [ "$NOTIFICATIONS" = 'Y' ];
	then
		if [ $QUOTAPERCUSE -ge 90  -a $QUOTAPERCUSE -le 99 ];
		then
			echo "BACKUP WARNING - Account almost full ("$QUOTAPERCUSE"%)" > /etc/superbackup/nagios.state
			for email in `cat /etc/superbackup/recipients.mail`
			do
				accountalmostfull
				logger -t superbackup_script "The account $BUSER almost reached it's quota limit ("$QUOTAPERCUSE"%)"
			done
		elif [ $QUOTAPERCUSE = 100 ];
		then
			echo "BACKUP CRITICAL - Backupaccount is full" > /etc/superbackup/nagios.state
			for email in `cat /etc/superbackup/recipients.mail`
			do
				accountfull
			done
			echo -e "The backupscript will not start, because the account $BUSER has reached it's quota limit.\n\nA notification has just been sent to $OLDRSYNCMAIL with more details and actions.\n\nWill now exit..."
			rm /var/run/backup.lock > /dev/null 2> /dev/null
			logger -t superbackup_script "The user has reached it's quota limit for account $BUSER on $BSERVER, will now exit!"
			exit
		fi
	fi
	rm -f /tmp/backup_quota > /dev/null 2>&1
fi
# Global settings for differentials, do not change this:
WEEKDAY=$(date +%u)                     # 1-7
MONTHDAY=$(date +%d | sed s/^0\\+// )   # 1-31
MONTH=$(date +%m | sed s/^0\\+//)       # 01-12
WEEK=$(date +%U | sed s/^0\\+// )       # 00-53
# Global controlpanel check with extra options for the controlpanel:
#
# Plesk
if [ -d /usr/local/psa/ ];
then
    CONTROLPANEL="- The controlpanel is Parallels Plesk."
	CPEXCLUDES="--exclude /usr/local/psa/admin/sbin/"
# DirectAdmin
elif [ -d /usr/local/directadmin/ ];
then
    CONTROLPANEL="- The controlpanel is DirectAdmin."
	CPEXCLUDES="--exclude /var/run/ --exclude /var/www/"
# cPanel
elif [ -d /usr/local/cpanel/ ];
then
    CONTROLPANEL="- The controlpanel is cPanel / WHM."
	CPEXCLUDES="--exclude /home/cpbackuptmp/ --exclude /backup/cpbackup/ --exclude /home/virtfs/ --exclude /usr/local/cpanel/3rdparty/mailman/cgi-bin/ --exclude /usr/local/apache/ --exclude /etc/exim/"
# ISPConfig 3
elif [ -d /usr/local/ispconfig/ ];
then
	CONTROLPANEL="- The controlpanel is ISPConfig 3."
# No CP
else
    CONTROLPANEL="- There is no controlpanel on this server."
fi
# Daily
if [ $WEEKDAY = 1 ]
then
	PREVDAY=6     # On Monday we fall back to Saturday as we do not create a daily backup on Sunday
else
	PREVDAY=$[WEEKDAY-1]
fi
DIR=$H-daily/$WEEKDAY/
PREVDIR=../../$H-daily/$PREVDAY/
# Checking to see if there is weekly retention enabled and if so, create the weekly backup
if ! [ $WEKEN = 0 ];
then
	if [ $WEEKDAY = 7 ]
	then
		N=$[WEEK%WEKEN]
		DIR=$H-weekly/$N/
	fi
fi
if ! [ $MAANDEN = 0 ]
then
	# of de eerste van de maand
	if [ $MONTHDAY = 1 ]
	then
		N=$[MONTH%MAANDEN]
		DIR=$H-monthly/$N/
	fi
fi
echo -e "\n[GENERAL BACKUP INFORMATION]"
echo "- The version of the backupscript is $VERSION."
if [ "$AUTOUPDATE" = "Y" ];
then
	echo "- Updates are checked once a month on day $UPDATECHECK and automatically installed."
else
	echo "- Updates will be checked once a month on day $UPDATECHECK."
fi
echo "- The backupserver is $BSERVER and the accountname is $BUSER."
echo "- The remote block device is $REMOTE_BLOCKDEVICE and uses the $REMOTE_PARTITIONTYPE partition."
echo "- The transfer speed is limited at "$XFERSPEED"KB/sec."
echo "- The backup root path is $BACKUPROOT and the remote backup path is $REMOTEPATH."
if [ "$LOGGING" = "Y" ];
then
	echo "- The logging functionality is enabled and the log is placed in /var/log/superbackup/rsync/`date '+%Y-%m-%d'`.log.gz"
else
	echo "- The logging functionality is disabled."
fi
if [ "$NOTIFICATIONS" = 'Y' ];
then
	echo "- The alert system is activated."
else
	echo "- The alert system is disabled (dangerous)."
fi
echo -e "$CONTROLPANEL"
echo -e "\n[RETENTION]"
echo "- Backups for the current week, using incrementals."
if [ $WEKEN = 0 ];
then
	echo "- No extra weekly retention."
else
	echo "- $WEKEN week(s) extra retention."
fi
if [ $MAANDEN = 0 ];
then
	echo "- No extra monthly retention."
else
	echo "- $MAANDEN month(s) extra retention."
fi
echo -e "\n[MYSQL]"
if [ $MYSQLBACKUP = 0 -o $MYSQLBACKUP = "Y" ];
then
    echo "- MySQL dumps are created in $MYSQLBACKUPDIR"
	sqldumps
else
    echo "- MySQL dumps are not enabled."
fi
echo -e "\n[BACKUP]"
echo -e "The backups for this session are stored in \"/$H-daily/$WEEKDAY/\" on the backupserver."
# Creating backupfolders based on the current retention:
if [ $WEKEN -gt 0 ];
then
	echo -ne "mkdir $H-weekly\nmkdir $DIR\n" | sftp -oStrictHostKeyChecking=no -oPort=$SSHPORT -o 'IdentityFile '$PRIVKEY $BUSER@$BSERVER:$REMOTEPATH > /dev/null 2>&1
fi
if [ $MAANDEN -gt 0 ];
then
	echo -ne "mkdir $H-monthly\nmkdir $DIR\n" | sftp -oStrictHostKeyChecking=no -oPort=$SSHPORT -o 'IdentityFile '$PRIVKEY $BUSER@$BSERVER:$REMOTEPATH > /dev/null 2>&1
fi
echo -ne "mkdir $H-daily\nmkdir $DIR\n" | sftp -oStrictHostKeyChecking=no -oPort=$SSHPORT -o 'IdentityFile '$PRIVKEY $BUSER@$BSERVER:$REMOTEPATH > /dev/null 2>&1
# Start the rsync procedure:
logger -t superbackup_script "Starting rsync backup procedure"
echo -ne "Creating backup: Please wait... \r"
if [[ $LOGGING == "Y" ]];
then
        rsync --log-file=/var/log/superbackup/rsync/`date '+%Y-%m-%d'`.log -e 'ssh -oStrictHostKeyChecking=no -p '$SSHPORT' -i '$PRIVKEY --bwlimit=$XFERSPEED --link-dest=$PREVDIR --delete -apSH --exclude-from "/etc/superbackup/excludes.rsync" $CPEXCLUDES $BACKUPROOT $BUSER@$BSERVER:$REMOTEPATH$DIR > /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp 2>&1; retval=$?
else
        rsync -e 'ssh -oStrictHostKeyChecking=no -p '$SSHPORT' -i '$PRIVKEY --bwlimit=$XFERSPEED --link-dest=$PREVDIR --delete -apSH --exclude-from "/etc/superbackup/excludes.rsync" $CPEXCLUDES $BACKUPROOT $BUSER@$BSERVER:$REMOTEPATH$DIR > /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp 2>&1; retval=$?
fi
# Exit codes of the script:
if [ $retval = 0 ];
then
	echo -ne "Creating backup: OK                   \r"; echo
	logger -t superbackup_script "There were no errors during the rsync backup procedure"
elif [ $retval = 1 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nThere are syntax errors, please check the configuration details to see if they are correct!"
	logger -t superbackup_script "The used rsync syntax contains errors, please check the configuration, backup not started!"
	echo "BACKUP CRITICAL - Configuration contains syntax errors" > /etc/superbackup/nagios.state
elif [ $retval = 2 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nThe used rsync version is incompatible. Version 3.0.0 or higher is required, please update rsync!"
	logger -t superbackup_script "The rsync version on this or the remote machine is/are incompatible, make sure that both machines run rsync 3"
	echo "BACKUP CRITICAL - Rsync incompatible" > /etc/superbackup/nagios.state
elif [ $retval = 12 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nThere was an error connecting to $BSERVER, backup will not run.\n- Please make sure that the following items are correct:\n-- rsync is installed\n-- rsync daemon is running\n-- You connect to the correct machine\n-- Any firewall is open for access on port $SSHPORT"
	logger -t superbackup_script "Rsync could not connect to $BSERVER with username $BUSER on port $SSHPORT!"
	echo "BACKUP CRITICAL - Could not connect to remote host ($BACKUPSERVER)" > /etc/superbackup/nagios.state
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        cat /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_12
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
elif [ $retval = 20 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nThe backupprocess received a kill from the system and therefore halted!"
	echo "BACKUP CRITICAL - Received kill from system" > /etc/superbackup/nagios.state
	logger -t superbackup_script "Rsync received a kill and therefore the backup did not succeed"
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        cat /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_20
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
elif [ $retval = 23 ];
then
	# We now mute this output, because this is mostly caused by hidden files on the server and only confuses people:
	echo -ne "Creating backup: OK                   \r"; echo
	echo "BACKUP OK - Backup succeeded" > /etc/superbackup/nagios.state
	logger -t superbackup_script "Rsync file copy was successful, but some files were not readable"
	if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
	then
		logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
	else
		logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
	fi
elif [ $retval = 24 ];
then
	# We now mute this output, because this is mostly caused by hidden files on the server and only confuses people:
	echo -ne "Creating backup: OK                   \r"; echo
	echo "BACKUP OK - Backup succeeded" > /etc/superbackup/nagios.state
    logger -t superbackup_script "Rsync file copy was successful, but some files have vanished during the backup process" 
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
	else
		logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
	fi
elif [ $retval = 30 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nA timeout occurred when connecting to the backupserver!"
	echo "BACKUP CRITICAL - Timeout occurred" > /etc/superbackup/nagios.state
	logger -t superbackup_script "A timeout occurred connecting to $BSERVER"
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        cat /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_30
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
elif [ $retval = 35 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nRsync on the backupserver $BSERVER is not available!"
	echo "BACKUP CRITICAL - Rsync not running on $BACKUPSERVER" > /etc/superbackup/nagios.state
	logger -t superbackup_script "Rsync is not running or installed on the backupserver"
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        cat /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_35
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
elif [ $retval = 134 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nThe backupprocess received an abort signal from the system, the backup has halted!"
	logger -t superbackup_script "The rsync process received an abort from the system"
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        cat /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_134
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
elif [ $retval = 137 ];
then
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nThe rsync process halted because the system has a generated an error.\n\nSee below for the files and/or directories that generated the crash and probably should be excluded in order to avoid this for the future:"
	logger -t superbackup_script "Rsync has crashed due to a file/folder, please see the report for the file(s)/folder(s)"
	echo "BACKUP CRITICAL - Backup segfaulted" > /etc/superbackup/nagios.state
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        cat /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_137
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
else
	echo -ne "Creating backup: FAILED               \r"; echo
	echo -e "\nRsync exited with an unknown error. The return code is $retval.\nPlease refer to the rsync manpage (man rsync) for more information."
	echo "BACKUP CRITICAL - Unknown error" > /etc/superbackup/nagios.state
	logger -t superbackup_script "Rsync has quit due to unknown reasons, the return status is $retval"
    if mv /var/log/superbackup/temp/`date '+%Y-%m-%d'`.temp /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn > /dev/null 2>&1
    then
        logger -t superbackup_script "Warn log placed in /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
        if [[ $NOTIFICATIONS == "Y" ]];
        then
            for email in `cat /etc/superbackup/recipients.mail`
            do
                rsync_error_unknown
            done
        fi
    else
        logger -t superbackup_script "Failed to move warn log to /var/log/superbackup/warn/`date '+%Y-%m-%d'`.warn"
    fi
fi
# Gzip the rsync log:
if [ $LOGGING = "Y" ];
then
	echo -ne "Compressing log: Please wait... \r"
	if gzip -f /var/log/superbackup/rsync/`date '+%Y-%m-%d'`.log
	then
    	echo -e "Compressing log: OK                \r"; echo
	else
    	echo -e "Compressing log: FAILED            \r"; echo
	fi
fi
# Log in to the remote server and retrieve local disk usage information for quota calculations:
if ssh -oStrictHostKeyChecking=no -p $SSHPORT -i $PRIVKEY $BUSER@$BSERVER "df -hT --block-size=G $REMOTEPATH | tail -n1" > /tmp/backup_quota 2>&1
then
    QUOTAPERCENTSTART=$QUOTAPERCUSE
    QUOTAPERCENTFINISH=$(cat /tmp/backup_quota | awk '{print $6}' | cut -d % -f 1)
    QUOTAPERCENTDIFF=$(($QUOTAPERCENTFINISH-$QUOTAPERCUSE))
    QUOTAPERCENTFREE=$((100-$QUOTAPERCENTFINISH))
    QUOTAENDFREE=$(cat /tmp/backup_quota | awk '{print $5}' | cut -d G -f 1)
    QUOTADIFF=$(echo $QUOTASTARTFREE-$QUOTAENDFREE | bc)
	rm -f /tmp/backup_quota > /dev/null 2>&1
    echo -e "\n[QUOTA]"
    echo -e "- The account is "$QUOTATOTALSIZE"GB in size and there is "$QUOTAENDFREE"GB ($QUOTAPERCENTFREE%) left."
    echo -e "- This session consumed "$QUOTADIFF"GB of diskspace."
fi
echo -e "\n[BACKUP ENDED ON `date '+%d-%m-%Y'` AT `date '+%H:%M:%S'`]"
# Removing lockfile:
if rm -f /var/run/superbackup.lock > /dev/null 2>&1
then
	logger -t superbackup_script "Backup lockfile removed"
else
	logger -t superbackup_script "Could not remove the backup lockfile"
fi
logger -t superbackup_script "The SuperBackup Script has finished"
exit