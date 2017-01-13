#!/bin/bash
# set -x
# Set version and other global variables:
version="1.0.0"
backtitle="SuperBackup Restore"
backtitle_files="SuperBackup Restore > File/Folder Restore"
backtitle_databases="SuperBackup Restore > Database Restore"
title=" SuperBackup Restore "
pid=$(echo $$)
logger -t backup_restore "Started the SuperBackup Restore Script"
date=`date '+%Y-%m-%dT%H:%M:%S'`
# Functions:
trap control_c INT
escaper()
{
    action=$?
    if [ $action = 1 -o $action = 255 ];
    then
        dialog --backtitle "$backtitle" --title "$title" --yesno "\nAre you sure you want to quit?" 7 50
        sure=$?
        if [ $sure = 0 ];
        then
            clear
            exit
        fi
    fi
}
clear
# Make sure you are root
if [ "$(id -u)" != "0" ]; then
    if [ -f /usr/bin/dialog ];
    then
        dialog --title " You are not root " --msgbox "\nYou need to be root in order to use this installer.\n\nInstaller will now exit." 10 40
        clear; exit
    else
        clear; echo -e "You need to be root in order to use this installer.\n\nInstaller will now exit."
        exit
    fi
fi
# Check if configfile exists:
if ! [[ -f /etc/superbackup/backup.conf ]];
then
	dialog --backtitle "$backtitle" --title "$title" --msgbox "\nConfigfile not found, please run the installer first!" 7 60
	logger -t backup_restore "SuperBackup Backupscript not installed, please install it first!"
	clear
	exit
else
	source /etc/superbackup/backup.conf
	logger -t backup_restore "Loaded the backup configuration file"
fi
# Check logging dir:
if ! [ -d /var/log/superbackup/recovery/ ];
then
	if mkdir -p /var/log/superbackup/recovery/ > /dev/null 2>&1
	then
		logger -t backup_restore "Created recovery logging directory in /var/log/superbackup/recovery/"
	fi
fi
# Start the greeter:
dialog --backtitle "$backtitle" --title "$title" --msgbox "\nWelcome to the SuperBackup restore script.\n\nThis script offers basic and quick restore functions for your lost files and/or databases.\nWhile this tool is designed to recover your data, improper usage of it may destroy the data on your local machine. In order to avoid this, please read the documentation thoroughly and be sure you know what you are doing!\n\nThe team of SuperBackup can not be held responsible in any case of data loss or other issues and the use of this script is at your own risk." 17 70
escaper
# Restore type
if [ $MYSQLBACKUP = "Y" ];
then
	logger -t backup_restore "MySQL Dumps are enabled, showing appropriate menu"
	dialog --backtitle "$backtitle" --title "$title" --menu "\nWhat type of restore do you want to perform?" 0 0 0 "1" "File/folder restore" "2" "MySQL database restore" 2> /tmp/$pid-restoretype
	escaper
	restoretype=$(cat /tmp/$pid-restoretype; rm -f /tmp/$pid-restoretype > /dev/null 2>&1)
else
	logger -t backup_restore "MySQL Dumps not enabled, only showing file/folder restore option"
	dialog --backtitle "$backtitle" --title "$title" --menu "\nWhat type of restore do you want to perform?" 0 0 0 "1" "File/folder restore" 2> /tmp/$pid-restoretype
	escaper
	restoretype=$(cat /tmp/$pid-restoretype; rm -f /tmp/$pid-restoretype > /dev/null 2>&1)
fi
case $restoretype in
1)
	logger -t backup_restore "Retention is set to $WEKEN W / $MAANDEN M"
	logger -t backup_restore "Started file/folder recovery procedure"
	dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nYou've chosen to restore files and/or folders.\nWe need a few more details, which will be asked in the next steps" 10 50
    if [[ $WEKEN = 0 && $MAANDEN = 0 ]];
    then
        dialog --backtitle "$backtitle_files" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" 2> /tmp/$pid-backuppool
		escaper
        backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
    elif [[ $WEKEN > 0 && $MAANDEN = 0 ]];
    then
        dialog --backtitle "$backtitle_files" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" "2" "Weekly pool" 2> /tmp/$pid-backuppool
		escaper
        backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
    elif [[ $WEKEN = 0 && $MAANDEN > 0 ]];
    then
        dialog --backtitle "$backtitle_files" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" "3" "Monthly pool" 2> /tmp/$pid-backuppool
		escaper
        backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
    elif [[ $WEKEN > 0 && $MAANDEN > 0 ]];
    then
        dialog --backtitle "$backtitle_files" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" "2" "Weekly pool" "3" "Monthly pool" 2> /tmp/$pid-backuppool
		escaper
        backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
    fi
	case $backuppool in
	1)
        dialog --backtitle "$backtitle_files" --title "$title" --menu "\nChoose the day you want to restore from:" 0 40 8 "1" "Monday" "2" "Tuesday" "3" "Wednesday" "4" "Thursday" "5" "Friday" "6" "Saturday" "7" "Sunday" 2> /tmp/$pid-day
		escaper
        day=$(cat /tmp/$pid-day; rm -f /tmp/$pid-day > /dev/null 2>&1)
		if [ $day = 1 ];
		then 
			hrday="Monday"
			logger -t backup_restore "Day selected for restore: Monday"
		elif [ $day = 2 ];
		then 
			hrday="Muesday"
			logger -t backup_restore "Day selected for restore: Tuesday"
		elif [ $day = 3 ];
		then
			hrday="Wednesday"
			logger -t backup_restore "Day selected for restore: Wednesday"
		elif [ $day = 4 ];
		then 
			hrday="Thursday"
			logger -t backup_restore "Day selected for restore: Thursday"
		elif [ $day = 5 ];
		then
			hrday="Friday"
			logger -t backup_restore "Day selected for restore: Friday"
		elif [ $day = 6 ];
		then
			hrday="Saturday"
			logger -t backup_restore "Day selected for restore: Saturday"
		elif [ $day = 7 ];
		then
			hrday="Sunday"
			logger -t backup_restore "Day selected for restore: Sunday"
		fi
        dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEnter the absolute location of the file or folder you want to restore.\n\nExamples:\n\nFile...: /my/file\nFolder.: /my/folder/" 15 60 2> /tmp/$pid-location
		escaper
        location=$(cat /tmp/$pid-location; rm -f /tmp/$pid-location > /dev/null 2>&1)
        while [ -z $location ]
        do
            dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the absolute location of the file or folder you want to restore.\n\nExamples:\n\nFile...: /my/file\nFolder.: /my/folder/" 17 60 2> /tmp/$pid-location
			escaper
            location=$(cat /tmp/$pid-location; rm -f /tmp/$pid-location)
        done
		logger -t backup_restore "Location set for restore: $location"
		dialog --backtitle "$backtitle_files" --title "$title" --yesno "\nThe following file or folder will be restored from $hrday in the daily pool:\n\n$location\n\nDo you agree?" 12 60
		escaper
		accept=$?
		if [ $accept = 0 ];
		then
			dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nYou have accepted the restore of $location.\n\nWill now start the restore process." 9 60
			logger -t backup_restore "Accepted data recovery"
		else
			dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nYou did not accept the values entered.\n\nWill now exit to prevent data loss." 9 60
			logger -t backup_restore "Did not accept data recovery, will now exit"
			clear
			exit
		fi
		echo "50" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Retrieving...\n\n(may take up to several minutes)" 10 50
		rsync --log-file=/var/log/superbackup/recovery/$date.log -avpSH -e 'ssh -oStrictHostKeyChecking=no -p '$SSHPORT' -i '$PRIVKEY'' $BUSER@$BSERVER:$REMOTEPATH$H-daily/$day$location $location > /dev/null 2>&1
		return=$?
		if [ $return = 0 ];
		then
			echo "100" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Done" 8 50; sleep 1
			logger -t backup_restore "Data recovery for $location from $hrday complete!"
		elif [ $return = 12 ];
		then
			dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThere was an error establishing a connection to the remote backupserver.\n\nWill now exit." 10 60
			logger -t backup_restore "Could not connect to server $BSERVER with username $BUSER and port $SSHPORT"
			clear
			exit
		elif [ $return = 23 ];
		then
            echo "100" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Done" 8 50; sleep 1
            logger -t backup_restore "Data recovery for $location from $hrday complete!"
		else
			dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThere was an error ($return) restoring from $location.\n\nWill now exit!" 9 60
			logger -t backup_restore "An unknown error (exit code $return) was thrown, will now exit"
			clear
			exit
		fi
        dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThe restore of $location was successful!\n\nThe recovery log can be found at:\n/var/log/superbackup/recovery/$date.log" 10 60
        logger -t backup_restore "The recovery log has been placed at /var/log/superbackup/recovery/$date.log"
        clear
		exit
	;;
	2)
		dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEnter the weekly pool number (0 - $WEKEN):" 9 50 2> /tmp/$pid-week
		escaper
		week=$(cat /tmp/$pid-week; rm -f /tmp/$pid-week > /dev/null 2>&1)
		while [ -z $week ]
		do
			dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the weekly pool number (0 - $WEKEN):" 11 50 2> /tmp/$pid-week
			escaper
			week=$(cat /tmp/$pid-week; rm -f /tmp/$pid-week > /dev/null 2>&1)
		done
		while ! [ $week -ge 0 -a $week -le $WEKEN ];
		do
			dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nIncorrect entry!\n\nEnter the weekly pool number (0 - $WEKEN):" 11 50 2> /tmp/$pid-week
			escaper
			week=$(cat /tmp/$pid-week; rm -f /tmp/$pid-week > /dev/null 2>&1)
		done
			logger -t backup_restore "Week selected for restore: $week"
            dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEnter the absolute location of the file or folder you want to restore.\n\nExamples:\n\nFile...: /my/file\nFolder.: /my/folder/" 15 60 2> /tmp/$pid-location
			escaper
            location=$(cat /tmp/$pid-location; rm -f /tmp/$pid-location > /dev/null 2>&1)
		while [ -z $location ]
		do
			dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the absolute location of the file or folder you want to restore.\n\nExamples:\n\nFile...: /my/file\nFolder.: /my/folder/" 17 60 2> /tmp/$pid-location
			escaper
			location=$(cat /tmp/$pid-location)
		done
			logger -t backup_restore "Location set for restore: $location"
            dialog --backtitle "$backtitle_files" --title "$title" --yesno "\nThe file or folder $location will be restored from week $week in the weekly pool.\n\nDo you agree?" 12 60
            accept=$?
		case $accept in
		0)
			logger -t backup_restore "Agreed to recovery, starting recovery"
        	echo "50" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Retrieving...\n\n(may take up to several minutes)" 10 50
        	rsync --log-file=/var/log/superbackup/recovery/$date.log -avpSH -e 'ssh -oStrictHostKeyChecking=no -p '$SSHPORT' -i '$PRIVKEY'' $BUSER@$BSERVER:$REMOTEPATH$H-weekly/$week$location $location > /dev/null 2>&1
			rsyncstatus=$?
			if [ $rsyncstatus = 0 ];
        	then
            	echo "100" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Done" 8 50; sleep 1;
				logger -t backup_restore "Recovery for $location from $week is complete!"
        	elif [ $return = 12 ];
        	then
            	dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThere was an error establishing a connection to the remote backupserver.\n\nWill now exit." 10 60
				logger -t backup_restore "Could not connect to server $BSERVER and username $BUSER on port $SSHPORT"
            	clear
            	exit
        	elif [ $return = 23 ];
        	then
            	echo "100" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Done" 8 50; sleep 1
            	logger -t backup_restore "Data recovery for $location from $hrday complete!"
        	else
            	dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThere was an error ($return) restoring from $location.\n\nWill now exit!" 9 60
				logger -t backup_restore "There was an unknown error (code $return), will now exit"
            	clear
            	exit
        	fi
        	dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThe restore of $location was successful!\n\nThe recovery log can be found at:\n/var/log/superbackup/recovery/$date.log" 10 60
			logger -t backup_restore "The recovery log has been placed at /var/log/superbackup/recovery/$date.log"
			clear
			exit
		;;
		1)
			dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nYou did not agree to continue, will now exit!" 7 60
			logger -t backup_restore "Did not agree to recovery, exiting"
			clear
			exit
		;;
		esac
	;;
    3)
        dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEnter the monthly pool number (0 - $MAANDEN):" 9 50 2> /tmp/$pid-month
        month=$(cat /tmp/$pid-month; rm -f /tmp/$pid-month > /dev/null 2>&1)
        while [ -z $month ]
        do
            dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the monthly pool number (0 - $MAANDEN):" 11 50 2> /tmp/$pid-month
            month=$(cat /tmp/$pid-month; rm -f /tmp/$pid-month > /dev/null 2>&1)
        done
        while ! [ $month -ge 0 -a $month -le $MAANDEN ];
        do
            dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nIncorrect entry!\n\nEnter the monthly pool number (0 - $MAANDEN):" 1 50 2> /tmp/$pid-month
            month=$(cat /tmp/$pid-month; rm -f /tmp/$pid-month > /dev/null 2>&1)
        done
		logger -t backup_restore "Month selected for restore: $month"
		dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEnter the absolute location of the file or folder you want to restore.\n\nExamples:\n\nFile...: /my/file\nFolder.: /my/folder/" 15 60 2> /tmp/$pid-location 
        location=$(cat /tmp/$pid-location; rm -f /tmp/$pid-location > /dev/null 2>&1)
        while [ -z $location ]
        do
            dialog --backtitle "$backtitle_files" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the absolute location of the file or folder you want to restore.\n\nExamples:\n\nFile...: /my/file\nFolder.: /my/folder/" 17 60 2> /tmp/$pid-location
            location=$(cat /tmp/$pid-location; rm -f /tmp/$pid-location > /dev/null 2>&1)
        done
		logger -t backup_restore "Location set for restore: $location"
        dialog --backtitle "$backtitle_files" --title "$title" --yesno "\nThe file or folder $location will be restored from month $month in the monthly pool.\n\nDo you agree?" 12 60
        accept=$?
        case $accept in
        0)
			logger -t backup_restore "Agreed to recovery, starting procedure"
            echo "50" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Retrieving...\n\n(may take up to several minutes)" 10 50
            rsync --log-file=/var/log/superbackup/recovery/$date.log -avpSH -e 'ssh -oStrictHostKeyChecking=no -p '$SSHPORT' -i '$PRIVKEY'' $BUSER@$BSERVER:$REMOTEPATH$H-monthly/$month$location $location > /dev/null 2>&1
            rsyncstatus=$?
            if [ $rsyncstatus = 0 ];
            then
                echo "100" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Done" 8 50; sleep 1;
				logger -t backup_restore "Recovery for $location from month $month was successful!"
            elif [ $return = 12 ];
            then
                dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThere was an error establishing a connection to the remote backupserver.\n\nWill now exit." 10 60
				logger -t backup_restore "Could not connect to server $BSERVER with username $BUSER and port $SSHPORT"
                clear
                exit
            elif [ $return = 23 ];
            then
                echo "100" | dialog --backtitle "$backtitle_files" --title "$title" --gauge "\nRestoring data: Done" 8 50; sleep 1
                logger -t backup_restore "Data recovery for $location from $hrday complete!"
            else
                dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThere was an error ($return) restoring from $location.\n\nWill now exit!" 9 60
				logger -t backup_restore "There was an unknown error (error $return), exiting"
                clear
                exit
            fi
            dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nThe restore of $location was successful!\n\nThe recovery log can be found at:\n/var/log/superbackup/recovery/$date.log" 10 60
            logger -t backup_restore "The recovery log has been placed at /var/log/superbackup/recovery/$date.log"
            clear
            exit
        ;;
        1)
        dialog --backtitle "$backtitle_files" --title "$title" --msgbox "\nYou did not agree to continue, will now exit!" 7 60
		logger -t backup_restore "Did not agree to recovery, exiting"
        clear
        exit
    ;;
    esac
;;
esac
;;
2)
	logger -t backup_restore "Retention is set to $WEKEN W / $MAANDEN M"
	logger -t backup_restore "Starting MySQL recovery procedure"
	dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nYou've chosen to restore a MySQL database.\n\nWe need a few more details, which will be asked in the next steps." 10 60
	if [[ $WEKEN = 0 && $MAANDEN = 0 ]];
	then
		dialog --backtitle "$backtitle_databases" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" 2> /tmp/$pid-backuppool
		escaper
		backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
	elif [[ $WEKEN > 0 && $MAANDEN = 0 ]];
	then
		dialog --backtitle "$backtitle_databases" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" "2" "Weekly pool" 2> /tmp/$pid-backuppool
		escaper
		backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
	elif [[ $WEKEN = 0 && $MAANDEN > 0 ]];
	then
		dialog --backtitle "$backtitle_databases" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" "3" "Monthly pool" 2> /tmp/$pid-backuppool
		escaper
		backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
	elif [[ $WEKEN > 0 && $MAANDEN > 0 ]];
	then
		dialog --backtitle "$backtitle_databases" --title "$title" --menu "\nChoose the backup pool you want to restore from:" 0 0 0 "1" "Daily pool" "2" "Weekly pool" "3" "Monthly pool" 2> /tmp/$pid-backuppool
		escaper
		backuppool=$(cat /tmp/$pid-backuppool; rm -f /tmp/$pid-backuppool > /dev/null 2>&1)
	fi
	case $backuppool in
	1)
		dialog --backtitle "$backtitle_databases" --title "$title" --menu "\nChoose the day you want to restore from:" 0 0 0 "1" "Monday" "2" "Tuesday" "3" "Wednesday" "4" "Thursday" "5" "Friday" "6" "Saturday" 2> /tmp/$pid-day
		escaper
		day=$(cat /tmp/$pid-day; rm -f /tmp/$pid-day > /dev/null 2>&1)
		dialog --backtitle "$backtitle_database" --title "$title" --inputbox "\nEnter the source database:" 9 50 2> /tmp/$pid-dbsource
		escaper
		dbsource=$(cat /tmp/$pid-dbsource; rm -f /tmp/$pid-dbsource > /dev/null 2>&1)
		while [ -z $dbsource ]
		do
			dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the source database:" 11 50 2> /tmp/$pid-dbsource
			escaper
			dbsource=$(cat /tmp/$pid-dbsource; rm -f /tmp/$pid-dbsource > /dev/null 2>&1)
		done
		logger -t backup_restore "Source database: $dbsource"
		dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the target database:" 9 50 2> /tmp/$pid-dbtarget
		escaper
		dbtarget=$(cat /tmp/$pid-dbtarget; rm -f /tmp/$pid-dbtarget > /dev/null 2>&1)
		while [ -z $dbtarget ]
		do
			dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the target database:" 11 50 2> /tmp/$pid-dbtarget
			escaper
			dbtarget=$(cat /tmp/$pid-dbtarget; rm -f /tmp/$pid-dbtarget > /dev/null 2>&1)
		done
		logger -t backup_restore "Target database: $dbtarget"
		if [[ "$dbsource" == "$dbtarget" ]];
		then
			dialog --backtitle "$backtitle_databases" --title "$title" --yesno "\nThe source and target database are the same.\n\nIn this case the current database on the server will be overwritten with the one you are restoring, is this OK?" 11 50
			dboverwrite=$?
			case $dboverwrite in
			0)
				logger -t backup_restore "Db source and target are the same, accepted overwriting the target database"
			;;
			1)
				dialog --backtitle "$backtitle_databases" --title "$backtitle_databases" --msgbox "\nYou have not accepted the overwrite, the script will now halt to prevent data loss..." 8 50
				logger -t backup_restore "Db source and target are the same, not accepted overwrite, exiting"
				clear
				exit
			;;
			esac
		fi
        if [ $day = 1 ];
        then
            hrday="Monday"
			logger -t backup_restore "Day selected for restore: Monday"
        elif [ $day = 2 ];
        then
            hrday="Tuesday"
			logger -t backup_restore "Day selected for restore: Tuesday"
        elif [ $day = 3 ];
        then
            hrday="Wednesday"
			logger -t backup_restore "Day selected for restore: Wednesday"
        elif [ $day = 4 ];
        then
            hrday="Thursday"
			logger -t backup_restore "Day selected for restore: Thursday"
        elif [ $day = 5 ];
        then
            hrday="Friday"
			logger -t backup_restore "Day selected for restore: Friday"
        elif [ $day = 6 ];
        then
            hrday="Saturday"
			logger -t backup_restore "Day selected for restore: Saturday"
        elif [ $day = 7 ];
		then
			hrday="Sunday"
			logger -t backup_restore "Day selected for restore: Sunday"
		fi
		dialog --backtitle "$backtitle_databases" --title "$title" --yesno "\nBelow is a small summary of the actions taking place:\n\nRestore type.....: MySQL restore\nBackup pool......: Daily\nWeekday..........: $hrday\nSource database..: $dbsource\nTarget database..: $dbtarget\n\nIs the above information correct?" 15 60
		dbaccept=$?
		if [ $dbaccept = 0 ];
		then
			echo "10" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Retrieving $dbsource" 8 60
			if scp -oStrictHostKeyChecking=no -oPort=$SSHPORT -o 'IdentityFile '$PRIVKEY $BUSER@$BSERVER:$REMOTEPATH$H-daily/$day$MYSQLBACKUPDIR$dbsource.gz ./ > /dev/null 2>&1
			then
				echo "20" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Retrieved $dbsource" 8 60
				logger -t backup_restore "Retrieved $dbsource from backupserver"
			else
				dialog --backtitle "$backtitle_databses" --title "$title" --msgbox "\nThere was an error retrieving database $dbsource!\n\nWill now exit." 9 60
				logger -t backup_restore "Could not retrieve $dbsource from backupserver, exiting"
				clear
				exit
			fi
			echo "30" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Extracting $dbsource" 8 60
			if gzip -df $dbsource.gz > /dev/null 2>&1
			then
				echo "40" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Extracted $dbsource" 8 60
				logger -t backup_restore "Extracted database $dbsource"
			else
				dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error while extracting $dbsource!\n\nWill now exit." 9 60
				logger -t backup_restore "Could not extract database $dbsource"
				rm -f $dbsource.gz > /dev/null 2>&1
				clear
				exit
			fi
			# cPanel check, else continue regular restore:
			if [ -d /usr/local/cpanel/ ];
			then
                if [ $dboverwrite = 0 ];
                then
                    echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropping $dbsource" 8 60
                    if mysql --user=$MYSQLUSER -e "DROP DATABASE "$dbsource";"
                    then
                        echo "56" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropped $dbsource" 8 60; sleep 1
						logger -t backup_restore "Dropped database $dbsource"
                    else
                        echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: $dbsource does not exit" 8 60; sleep 1
						logger -t backup_restore "Could not drop database $dbsource, does not exist (anymore)"
	                fi
	                echo "62" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbsource" 8 60
	                if mysql --user=$MYSQLUSER -e "CREATE DATABASE "$dbtarget";"
	                then
                        echo "68" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbsource" 8 60
						logger -t backup_restore "Created new database $dbsource"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not create new database $dbsource, exiting"
						rm -f $dbsource > /dev/null 2>&1
						clear
						exit
                    fi
	                echo "74" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbtarget" 8 60
	                if mysql --user=$MYSQLUSER --database="$dbtarget" < "$dbsource"
	                then
                        echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource" 8 60; sleep 1
						logger -t backup_restore "Imported backup database $dbsource"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not import backup database $dbsource, exiting"
						rm -f $dbsource > /dev/null 2>&1
						clear
						exit
                    fi
                    echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                    if rm -f "$dbsource" > /dev/null 2>&1
                    then
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
						logger -t backup_restore "Removed downloaded backup database $dbsource"
                    else
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
						logger -t backup_restore "Could not remove downloaded backup database $dbsource, remove it manually"
		            fi
                else
                    echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbsource" 8 60
                    if mysql --user=$MYSQLUSER -e "CREATE DATABASE "$dbtarget";" > /dev/null 2>&1
                    then
                        echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbsource" 8 60; sleep 1
						logger -t backup_restore "Created new database $dbsource"
	                else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not create new database $dbsource, exiting"
						rm -f $dbsource > /dev/null 2>&1
						clear
						exit
                    fi
                    echo "70" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource to $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER --database="$dbtarget" < "$dbsource" > /dev/null 2>&1
                    then
                        echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource to $dbtarget" 8 60; sleep 1
						logger -t backup_restore "Imported backup database $dbsource"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource to $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not import backup database $dbsource, exiting"
						rm -f $dbsource > /dev/null 2>&1
						clear
						exit
					fi
                    echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                    if rm -f "$dbsource" > /dev/null 2>&1
                    then
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
						logger -t backup_restore "Removed downloaded backup database $dbsource"
                    else
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 3
						logger -t backup_restore "Could not remove downloaded backup database $dbsource, remove it manually"
                    fi
	            fi
			else
                if [ $dboverwrite = 0 ];
                then
                    echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropping $dbsource" 8 60
                    if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "DROP DATABASE "$dbsource";"
                    then
                        echo "56" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropped $dbsource" 8 60; sleep 1
						logger -t backup_restore "Dropped database $dbsource"
                    else
                        echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: $dbsource does not exit" 8 60; sleep 1
						logger -t backup_restore "Could not drop database $dbsource, does not exist (anymore)"
                    fi
                    echo "62" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbsource" 8 60
                    if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "CREATE DATABASE "$dbtarget";"
                    then
                        echo "68" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbsource" 8 60
						logger -t backup_restore "Created new database $dbsource"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not create new database $dbtarget, exiting"
                        clear
                        exit
                    fi
                    echo "74" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER --password=$MYSQLPASS --database="$dbtarget" < "$dbsource"
                    then
                        echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbtarget" 8 60; sleep 1
						logger -t backup_restore "Imported backup database $dbsource"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not import database backup $dbsource, exiting"
                        clear
                        exit
                    fi
                    echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                    if rm -f "$dbsource" > /dev/null 2>&1
                    then
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
						logger -t backup_restore "Removed downloaded database backup $dbsource"
                    else
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 3
						logger -t backup_restore "Could not remove downloaded database backup $dbsource, remove it manually"
                    fi
                else
                    echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "CREATE DATABASE "$dbtarget";" > /dev/null 2>&1
                    then
                        echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60; sleep 1
						logger -t backup_restore "Created new database $dbtarget"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not create new database $dbtarget"
                        clear
                        exit
                    fi
                    echo "70" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource to $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER --password=$MYSQLPASS --database="$dbtarget" < "$dbsource" > /dev/null 2>&1
                    then
                        echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource to $dbtarget" 8 60; sleep 1
						logger -t backup_restore "Imported backup database $dbsource into database $dbtarget"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource to $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not import backup database $dbsource into database $dbtarget"
                        clear
                        exit
	                fi
                    echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                    if rm -f "$dbsource" > /dev/null 2>&1
                    then
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
						logger -t backup_restore "Removed downloaded backup database $dbsource"
                    else
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
						logger -t backup_restore "Could not remove downloaded backup database $dbsource, remove it manually"
                    fi
                fi
			fi
			dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThe restore of $dbsource to $dbtarget is complete!\n\nThe script will now exit." 9 60
			logger -t backup_restore "Recovery of database $dbsource to database $dbtarget was successful!"
			clear
			exit
		else
			dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nYou did not accept the given settings.\n\nWill now exit to prevent dataloss." 9 50
			logger -t backup_restore "Did not accept to database recovery, will now exit"
			clear
			exit
		fi
	;;
	2)
        dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the weekly pool number (0 - $WEKEN):" 9 50 2> /tmp/$pid-week
        week=$(cat /tmp/$pid-week; rm -f /tmp/$pid-week > /dev/null 2>&1)
        while [ -z $week ]
        do
            dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the weekly pool number (0 - $WEKEN):" 11 50 2> /tmp/$pid-week
            week=$(cat /tmp/$pid-week; rm -f /tmp/$pid-week > /dev/null 2>&1)
        done
        while ! [ $week -ge 0 -a $week -le $WEKEN ];
        do
            dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nIncorrect entry!\n\nEnter the weekly pool number (0 - $WEKEN):" 11 50 2> /tmp/$pid-week
            week=$(cat /tmp/$pid-week; rm -f /tmp/$pid-week > /dev/null 2>&1)
        done
		logger -t backup_restore "Week selected for restore: $week"
        dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the source database:" 9 50 2> /tmp/$pid-dbsource
        dbsource=$(cat /tmp/$pid-dbsource; rm -f /tmp/$pid-dbsource)
        while [ -z $dbsource ]
        do
            dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the source database:" 11 50 2> /tmp/$pid-dbsource
            dbsource=$(cat /tmp/$pid-dbsource; rm -f /tmp/$pid-dbsource)
        done
		logger -t backup_restore "Source database: $dbsource"
        dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the target database:" 9 50 2> /tmp/$pid-dbtarget
        dbtarget=$(cat /tmp/$pid-dbtarget; rm -f /tmp/$pid-dbtarget)
        while [ -z $dbtarget ]
        do
            dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the target database:" 11 50 2> /tmp/$pid-dbtarget
            dbtarget=$(cat /tmp/$pid-dbtarget; rm -f /tmp/$pid-dbtarget)
        done
		logger -t backup_restore "Target database: $dbtarget"
        if [[ "$dbsource" == "$dbtarget" ]];
        then
            dialog --backtitle "$backtitle_databases" --title "$title" --yesno "\nThe source and target database are the same.\n\nIn this case the current database on the server will be overwritten with the one you are restoring, is this OK?" 11 50
            dboverwrite=$?
            case $dboverwrite in
			0)
				logger -t backup_restore "DB source and target are the same, accepted overwrite"
			;;
            1)
                dialog --backtitle "$backtitle_databases" --title "$backtitle_databases" --msgbox "\nYou have not accepted the overwrite, the script will now halt to prevent data loss..." 8 50
				logger -t backup_restore "Did not accept DB overwrite, exiting"
                clear
                exit
	        ;;
	        esac
        fi
        dialog --backtitle "$backtitle_databases" --title "$title" --yesno "\nBelow is a small summary of the actions taking place:\n\nRestore type.....: MySQL restore\nBackup pool......: Weekly\nWeek.............: $week\nSource database..: $dbsource\nTarget database..: $dbtarget\n\nIs the above information correct?" 15 60
        dbaccept=$?
        if [ $dbaccept = 0 ];
        then
            echo "10" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Retrieving $dbsource" 8 60
            if scp -oStrictHostKeyChecking=no -oPort=$SSHPORT -o 'IdentityFile '$PRIVKEY $BUSER@$BSERVER:$REMOTEPATH$H-weekly/$week$MYSQLBACKUPDIR$dbsource.gz ./ > /dev/null 2>&1
            then
                echo "20" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Retrieved $dbsource" 8 60; sleep 1;
				logger -t backup_restore "Retrieved backup database $dbsource"
            else
                dialog --backtitle "$backtitle_databses" --title "$title" --msgbox "\nThere was an error retrieving database $dbsource!\n\nWill now exit." 9 60
				logger -t backup_restore "Could not retrieve backup database $dbsource from server $BSERVER, please check settings, exiting"
                clear
                exit
            fi
            echo "30" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Extracting $dbsource" 8 60
            if gzip -df $dbsource.gz > /dev/null 2>&1
            then
                echo "40" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Extracted $dbsource" 8 60; sleep 1
				logger -t backup_restore "Extracted backup database $dbsource"
            else
                dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error while extracting $dbsource!\n\nWill now exit." 9 60
				logger -t backup_restore "Could not extract backup database $dbsource"
                clear
                exit
            fi
            # cPanel check, else continue regular restore:
            if [ -d /usr/local/cpanel/ ];
            then
                if [ $dboverwrite = 0 ];
                then
                    echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropping $dbsource" 8 60
                    if mysql --user=$MYSQLUSER -e "DROP DATABASE "$dbsource";"
                    then
                        echo "56" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropped $dbsource" 8 60; sleep 1
						logger -t backup_restore "Dropped database $dbsource"
                    else
                        echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: $dbsource does not exit" 8 60; sleep 1
						logger -t backup_restore "Could not drop database $dbsource, does not exist (anymore)"
                    fi
                    echo "62" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER -e "CREATE DATABASE "$dbtarget";"
                    then
                        echo "68" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60
						logger -t backup_restore "Created new database $dbtarget"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not create new database $dbtarget, exiting"
						rm -f $dbsource > /dev/null 2>&1
                        clear
                        exit
                    fi
                    echo "74" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER --database="$dbtarget" < "$dbsource"
                    then
                        echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource" 8 60; sleep 1
						logger -t backup_restore "Imported database $dbsource"
	                else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not import database $dbsource, exiting"
						rm -f $dbsource > /dev/null 2>&1
                        clear
                        exit
	                fi
                    echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                    if rm -f "$dbsource" > /dev/null 2>&1
                    then
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
						logger -t backup_restore "Removed downloaded database backup $dbsource"
                    else
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
						logger -t backup_restore "Could not remove downloaded database backup $dbsource, remove it manually"
                    fi
                else
                    echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER -e "CREATE DATABASE "$dbtarget";" > /dev/null 2>&1
                    then
                        echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60; sleep 1
						logger -t backup_restore "Created new database $dbtarget"
                    else
                        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not create new database $dbtarget, exiting"
                        clear
                        exit
	                fi
                    echo "70" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource to $dbtarget" 8 60
                    if mysql --user=$MYSQLUSER --database="$dbtarget" < "$dbsource" > /dev/null 2>&1
                    then
                        echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource to $dbtarget" 8 60; sleep 1
						logger -t backup_restore "Imported $dbsource in $dbtarget"
                    else
				        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource to $dbtarget!\n\nWill now exit" 9 60
						logger -t backup_restore "Could not import database $dbsource to $dbtarget, exiting"
	                clear
	                exit
                fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed downloaded backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
					logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            fi
        else
            if [ $dboverwrite = 0 ];
            then
                echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropping $dbsource" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "DROP DATABASE "$dbsource";"
                then
                    echo "56" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropped $dbsource" 8 60; sleep 1
					logger -t backup_restore "Dropped database $dbsource"
                else
                    echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: $dbsource does not exit" 8 60; sleep 1
					logger -t backup_restore "Could not drop database $dbsource, does not exist (anymore)"
	            fi
                echo "62" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "CREATE DATABASE "$dbtarget";"
                then
                    echo "68" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60
					logger -t backup_restore "Created new database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not create new database $dbtarget, exiting"
					rm -f $dbsource > /dev/null 2>&1
                    clear
                    exit
                fi
                echo "74" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS --database="$dbtarget" < "$dbsource"
                then
                    echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource" 8 60; sleep 1
					logger -t backup_restore "Imported database $dbsource to $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not import sourcee $dbsource to target $dbtarget"
					rm -f $dbsource > /dev/null 2>&1
                    clear
                    exit
                fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                        echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
						logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            else
                echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "CREATE DATABASE "$dbtarget";" > /dev/null 2>&1
                then
                    echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60; sleep 1
					logger -t backup_restore "Created new database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not create new database $dbtarget, exiting"
					rm -f $dbsource > /dev/null 2>&1
                    clear
                    exit
	            fi
                echo "70" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource to $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS --database="$dbtarget" < "$dbsource" > /dev/null 2>&1
                then
                    echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource to $dbtarget" 8 60; sleep 1
					logger -t backup_restore "Imported database source $dbsource in target database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource to $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not import source database $dbsource in target database $dbtarget, exiting"
					rm -f $dbsource > /dev/null 2>&1
                    clear
                    exit
	            fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
					logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            fi
	    fi
        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThe restore of $dbsource to $dbtarget is complete!\n\nThe script will now exit." 9 60
		logger -t backup_restore "Database restore is complete"
        clear
        exit
    else
        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nYou did not accept the given settings.\n\nWill now exit to prevent dataloss." 9 60
		logger -t backup_restore "Did not agree to database recovery, exiting"
        clear
        exit
    fi
;;
3)
    dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the monthly pool number (0 - $MAANDEN):" 9 50 2> /tmp/$pid-month
    month=$(cat /tmp/$pid-month; rm -f /tmp/$pid-month > /dev/null 2>&1)
    while [ -z $month ]
    do
        dialog --title " File/folder restore " --inputbox "\nEmpty entry not allowed!\n\nEnter the monthly pool number (0 - $MAANDEN):" 11 50 2> /tmp/$pid-month
        month=$(cat /tmp/$pid-month; rm -f /tmp/$pid-month)
    done
    while ! [ $month -ge 0 -a $month -le $MAANDEN ];
    do
        dialog --title " File/folder restore " --inputbox "\nIncorrect entry!\n\nEnter the monthly pool number (0 - $MAANDEN):" 11 50 2> /tmp/$pid-month
        month=$(cat /tmp/$pid-month; rm -f /tmp/$pid-month > /dev/null 2>&1)
    done
	logger -t backup_restore "Month selected for restore: $month"
    dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the source database:" 9 50 2> /tmp/$pid-dbsource
    dbsource=$(cat /tmp/$pid-dbsource; rm -f /tmp/$pid-dbsource)
    while [ -z $dbsource ]
    do
        dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the source database:" 11 50 2> /tmp/$pid-dbsource
        dbsource=$(cat /tmp/$pid-dbsource; rm -f /tmp/$pid-dbsource)
    done
	logger -t backup_restore "Source database: $dbsource"
    dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEnter the target database:" 9 50 2> /tmp/$pid-dbtarget
    dbtarget=$(cat /tmp/$pid-dbtarget; rm -f /tmp/$pid-dbtarget)
    while [ -z $dbtarget ]
    do
        dialog --backtitle "$backtitle_databases" --title "$title" --inputbox "\nEmpty entry not allowed!\n\nEnter the target database:" 11 50 2> /tmp/$pid-dbtarget
        dbtarget=$(cat /tmp/$pid-dbtarget; rm -f /tmp/$pid-dbtarget)
    done
    if [[ "$dbsource" == "$dbtarget" ]];
    then
        dialog --backtitle "$backtitle_databases" --title "$title" --yesno "\nThe source and target database are the same.\n\nIn this case the current database on the server will be overwritten with the one you are restoring, is this OK?" 11 50
        dboverwrite=$?
        case $dboverwrite in
		0)
			logger -t backup_restore "Accepted database overwrite, due to same names"
		;;
        1)
            dialog --backtitle "$backtitle_databases" --title "$backtitle_databases" --msgbox "\nYou have not accepted the overwrite, the script will now halt to prevent data loss..." 8 60
			logger -t backup_restore "Did not agree to database overwrite, exiting"
            clear
            exit
        ;;
        esac
    fi
	logger -t backup_restore "Target database: $dbtarget"
    dialog --backtitle "$backtitle_databases" --title "$title" --yesno "\nBelow is a small summary of the actions taking place:\n\nRestore type.....: MySQL restore\nBackup pool......: Weekly\nWeek.............: $month\nSource database..: $dbsource\nTarget database..: $dbtarget\n\nIs the above information correct?" 15 60
    dbaccept=$?
    if [ $dbaccept = 0 ];
    then
        echo "10" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Retrieving $dbsource" 8 60
        if scp -oStrictHostKeyChecking=no -oPort=$SSHPORT -o 'IdentityFile '$PRIVKEY $BUSER@$BSERVER:$REMOTEPATH$H-monthly/$month$MYSQLBACKUPDIR$dbsource.gz ./ > /dev/null 2>&1
        then
            echo "20" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Retrieved $dbsource" 8 60; sleep 1;
			logger -t backup_restore "Downloaded database backup from backupserver"
        else
            dialog --backtitle "$backtitle_databses" --title "$title" --msgbox "\nThere was an error retrieving database $dbsource!\n\nWill now exit." 9 60
			logger -t backup_restore "Could not download database backup from server $BSERVER and username $BUSER on port $SSHPORT, exiting"
            clear
            exit
        fi
        echo "30" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Extracted $dbsource" 8 60
        if gzip -df $dbsource.gz > /dev/null 2>&1
        then
            echo "40" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Extracted $dbsource" 8 60; sleep 1
			logger -t backup_restore "Extracted downloaded database $dbsource.gz"
        else
            dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error while extracting $dbsource!\n\nWill now exit." 9 60
			logger -t backup_restore "Could not extract downloaded database sourcefile $dbsource.gz, exiting"
			rm -f $dbsource.gz > /dev/null 2>&1
            clear
            exit
        fi
        # cPanel check, else continue regular restore:
        if [ -d /usr/local/cpanel/ ];
        then
            if [ $dboverwrite = 0 ];
            then
                echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropping $dbsource" 8 60
                if mysql --user=$MYSQLUSER -e "DROP DATABASE "$dbsource";"
                then
                    echo "56" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropped $dbsource" 8 60; sleep 1
					logger -t backup_restore "Dropped old database $dbsource"
                else
                    echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: $dbsource does not exit" 8 60; sleep 1
					logger -t backup_restore "Could not drop database $dbsource, does not exist (anymore)"
                fi
                echo "62" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                if mysql --user=$MYSQLUSER -e "CREATE DATABASE "$dbtarget";"
                then
                    echo "68" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60
					logger -t backup_restore "Created new database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not create new database $dbtarget, exiting"
					rm -f $dbsource.gz > /dev/null 2>&1
                    clear
                    exit
	            fi
                echo "74" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --database="$dbtarget" < "$dbsource"
                then
                    echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource" 8 60; sleep 1
					logger -t backup_restore "Imported source database $dbsource in target database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not import source database $dbsource in target database $dbtarget, exiting"
					rm -f $dbsource.gz > /dev/null 2>&1
                    clear
                    exit
                fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
					logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            else
                echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                if mysql --user=$MYSQLUSER -e "CREATE DATABASE "$dbtarget";" > /dev/null 2>&1
                then
                    echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60; sleep 1
					logger -t backup_restore "Created new database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not create new database $dbtarget, exiting"
					rm -f $dbsource.gz > /dev/null 2>&1
                    clear
                    exit
                fi
                echo "70" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource to $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --database="$dbtarget" < "$dbsource" > /dev/null 2>&1
                then
                    echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource to $dbtarget" 8 60; sleep 1
					logger -t backup_restore "Imported source database $dbsource in target database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource to $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not import source database $dbsource in target database $dbtarget, exiting"
					rm -f $dbsource.gz > /dev/null 2>&1
                    clear
                    exit
                fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
					logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            fi
        else
            if [ $dboverwrite = 0 ];
            then
                echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropping $dbsource" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "DROP DATABASE "$dbsource";"
                then
                    echo "56" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Dropped $dbsource" 8 60; sleep 1
					logger -t backup_restore "Dropped old database $dbsource"
                else
                    echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: $dbsource does not exit" 8 60; sleep 1
					logger -t backup_restore "Could not drop database $dbsource, does not exist (anymore)"
	            fi
                echo "62" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "CREATE DATABASE "$dbtarget";"
                then
                    echo "68" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60
					logger -t backup_restore "Created new databse $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not create new database $dbtarget"
					rm -f $dbsource.gz > /dev/null 2>&1
                    clear
                    exit
	            fi
                echo "74" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS --database="$dbtarget" < "$dbsource"
                then
                    echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource" 8 60; sleep 1
					logger -t backup_restore "Imported source database $dbsource in target database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not import source database $dbsource in target database $dbtarget, exiting"
					rm -f $dbsource.gz > /dev/null 2>&1
                    clear
                    exit
	            fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
					logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            else
                echo "50" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Creating $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS -e "CREATE DATABASE "$dbtarget";" > /dev/null 2>&1
                then
                    echo "60" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Created $dbtarget" 8 60; sleep 1
					logger -t backup_restore "Created new database $dbtarget"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error creating database $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not create new database $dbtarget, exiting"
                    clear
                    exit
                fi
                echo "70" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Importing $dbsource to $dbtarget" 8 60
                if mysql --user=$MYSQLUSER --password=$MYSQLPASS --database="$dbtarget" < "$dbsource" > /dev/null 2>&1
                then
                    echo "80" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Imported $dbsource to $dbtarget" 8 60; sleep 1
					logger -t backup_restore "Imported source database $dbsource in target database $dbsource"
                else
                    dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThere was an error importing database $dbsource to $dbtarget!\n\nWill now exit" 9 60
					logger -t backup_restore "Could not import source database $dbsource in target database $dbtarget, exiting"
                    clear
                    exit
	            fi
                echo "90" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Remove downloaded backup" 8 60
                if rm -f "$dbsource" > /dev/null 2>&1
                then
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Removed backup" 8 60; sleep 1
					logger -t backup_restore "Removed downloaded database backup"
                else
                    echo "100" | dialog --backtitle "$backtitle_databases" --title "$title" --gauge "\nRestoring database: Could not delete backup" 8 60; sleep 1
					logger -t backup_restore "Could not remove downloaded database backup, remove it manually"
                fi
            fi
        fi
        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nThe restore of $dbsource to $dbtarget is complete!\n\nThe script will now exit." 9 60
		logger -t backup_restore "Database recovery is now complete!"
        clear
        exit
    else
        dialog --backtitle "$backtitle_databases" --title "$title" --msgbox "\nYou did not accept the given settings.\n\nWill now exit to prevent dataloss." 9 60
		logger -t backup_restore "Did not accept to recovery, exiting"
        clear
        exit
    fi
    ;;
	esac
;;
esac
logger -t backup_restore "Stopped the SuperBackup Restore Script"
