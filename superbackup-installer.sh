#!/bin/bash
#
# The SuperBackup Suite created by Jeffrey Langerak
#
# Bugs and/or features can be left at the repository below:
# https://github.com/langerak/superbackup
# 
# Setting / getting global version, information and variables
version="1.0.0"
defaultsshport=22
defaultbackuppath=/
hostname=`hostname`
sqlbackupdefault=/var/sqlbackups/
primaryip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
kernel=$(uname -r)
system_uptime=$(uptime -p)
cpu_cores=$(nproc)
cpu_type=$(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d ':' -f 2 | sed 's/\ //')
cpu_arch=$(uname -m)
memory=$(free -m | grep Mem: | awk '{print $2}')
currentsize=$(df -hT --exclude-type="tmpfs" --exclude-type="devtmpfs" --block-size=G | grep "/" | awk '{print $3}' | tr -d G | head -1)
currentsizeused=$(df -hT --exclude-type="tmpfs" --exclude-type="devtmpfs" --block-size=G | grep "/" | awk '{print $4}' | tr -d G | head -1)
currentsizefree=$(df -hT --exclude-type="tmpfs" --exclude-type="devtmpfs" --block-size=G | grep "/" | awk '{print $5}' | tr -d G | head -1)
newversion=$(curl -s https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-installer.sh | grep "version=" | cut -d = -f 2 | sed 's/"//g' | head -1)
cur_epoch=`date +%s`
nice_opts="ionice -c2 nice -n19"
#
# Functions
trap control_c INT
escaper()
{
    action=$?
    if [ $action = 1 -o $action = 255 ];
    then
        dialog --backtitle "$backtitle" --title "$title" --yesno "\nAre you sure you want to quit?\n\nAny changes you made will be lost!" 9 50
        sure=$?
        if [ $sure = 0 ];
        then
    		logger -t superbackup_installer "Stopped the SuperBackup Installer"
            clear
            exit
        fi
    fi
}
genhour()
{
        genhour=9
        hour=$RANDOM
        let "hour %= $genhour"
}
genminute()
{
        genminute=59
        minute=$RANDOM
        let "minute %= $genminute"
}
genday()
{
        genday=28
        day=$RANDOM
        let "day %= $genday"
}
getkeyinformation()
{
    if [ -f $PRIVKEY ]
    then
        # Get cipher:
        keytype=$(ssh-keygen -lf $PRIVKEY | cut -d ' ' -f 4 | sed -e 's/^.//' -e 's/.$//' | tr '[:upper:]' '[:lower:]')
        # Get bitsize:
        keybits=$(ssh-keygen -lf $PRIVKEY | cut -d ' ' -f 1)
        # Get key name:
        keyname=$(echo $PRIVKEY | cut -d ' ' -f 3)
    fi
}
control_c()
{
	dialogloc=$(which dialog)
	if [ -z $dialogloc ];
	then
		echo -e "Control + C pressed, will exit."
		logger -t superbackup_installer "Quit due to Control + C"
		exit
	else
		dialog --msgbox "\nControl + C pressed, will exit." 8 50
		logger -t superbackup_installer "Quit due to Control + C"
		clear
		exit
	fi
}
mysqldumps()
{
    # DirectAdmin:
    if [ -d /usr/local/directadmin ];
    then
        source /usr/local/directadmin/conf/mysql.conf
        mysqldumps="Y"
        mysqluser=$user
        mysqlpass=$passwd
    # cPanel / WHM:
    elif [ -d /usr/local/cpanel ];
    then
        mysqldumps="Y"
        mysqluser="root"
        mysqlpass=""
    # Parallels Plesk:
    elif [ -d /usr/local/psa ];
    then
        mysqldumps="Y"
        mysqluser="admin"
        mysqlpass=$(cat /etc/psa/.psa.shadow)
    # Debian / Ubuntu:
    elif [ -f /etc/mysql/debian.cnf ];
    then
        mysqldumps="Y"
        mysqluser=$(grep ^user < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')
        mysqlpass=$(grep ^password < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')
    # ISPConfig 3:
    elif [ -f /usr/local/ispconfig/server/lib/mysql_clientdb.conf ];
    then
    	mysqldumps="Y"
    	mysqluser=$(grep user < /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk '{print $3'} | sed "s/[';]//g")
    	mysqlpass=$(grep password < /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk '{print $3'} | sed "s/[';]//g")
    # If no usable configurations are found, set to none (user can edit this during installation):
    else
        mysqldumps="N"
    	mysqluser="none"
    	mysqlpass="none"
    fi
}
softwarecheck()
{
    echo -n "Operating System detected: "
    # For Debian / Ubuntu based systems:
    if [ -f /etc/debian_version ];
    then
        source /etc/os-release
        echo -e $PRETTY_NAME
        logger -t superbackup_installer "$PRETTY_NAME detected"; echo
        echo -e "Checking if needed packages are present on the system:\n"
        if curl -f -s -o installdeps-debian https://raw.githubusercontent.com/langerak/superbackup/master/installdeps-debian.sh > /dev/null 2>&1
        then
            chmod +x installdeps-debian
            ./installdeps-debian
        else
            echo -e "Could not download the dependency installer for $PRETTY_NAME, please check your network settings!"
            exit
        fi
    # For ArchLinux and derivates
    elif [ -f /etc/manjaro-release ] || [ -f /etc/arch-release ];
    then
        source /etc/os-release
        echo -e $PRETTY_NAME
        echo -e "Checking if needed packages are present on the system:\n"
        logger -t superbackup_installer "$PRETTY_NAME detected"; echo
        if curl -f -s -o installdeps-archlinux https://raw.githubusercontent.com/langerak/superbackup/master/installdeps-archlinux.sh > /dev/null 2>&1
        then
            chmod +x installdeps-archlinux
            ./installdeps-archlinux
        else
            echo -e "Could not download the dependency installer for $PRETTY_NAME, please check your network settings!"
            exit
        fi
    # For Fedora
    elif [ -f /etc/fedora-release ];
    then
        source /etc/os-release
        echo -e $PRETTY_NAME
        echo -e "Checking if needed packages are present on the system:\n"
        logger -t superbackup_installer "$PRETTY_NAME detected"; echo
        if curl -f -s -o installdeps-fedora https://raw.githubusercontent.com/langerak/superbackup/master/installdeps-fedora.sh > /dev/null 2>&1
        then
            chmod +x installdeps-fedora
            ./installdeps-fedora
        else
            echo -e "Could not download the dependency installer for $PRETTY_NAME, please check your network settings!"
            exit
        fi
    # For (Open)SUSE
    elif [ -f /etc/SuSE-release ];
    then
        source /etc/os-release
        echo -e $PRETTY_NAME
        echo -e "Checking if needed packages are present on the system:\n"
        logger -t superbackup_installer "$PRETTY_NAME detected"; echo
        if curl -f -s -o installdeps-suse https://raw.githubusercontent.com/langerak/superbackup/master/installdeps-suse.sh > /dev/null 2>&1
        then
            chmod +x installdeps-suse
            ./installdeps-suse
        else
            echo -e "Could not download the dependency installer for $PRETTY_NAME, please check your network settings!"
            exit
        fi
    # For RedHat based systems and derivatives:
    elif [ -f /etc/redhat-release ];
    then
        if [ -f /etc/os-release ];
        then
            echo -e $PRETTY_NAME
            echo -e "Checking if needed packages are present on the system:\n"
            logger -t superbackup_installer "$PRETTY_NAME detected"; echo
            if curl -f -s -o installdeps-redhat https://raw.githubusercontent.com/langerak/superbackup/master/installdeps-redhat.sh > /dev/null 2>&1
            then
                chmod +x installdeps-redhat
                ./installdeps-redhat
            else
                echo -e "Could not download the dependency installer for $PRETTY_NAME, please check your network settings!"
                exit
            fi
        else
            # Detect CentOS version:
            vers=$(grep -Eo "[0-9]\.[0-9]" /etc/redhat-release | cut -d . -f 1)
            echo -e "CentOS / RedHat version $vers"
            echo -e "Checking if needed packages are present on the system:\n"        
            logger -t superbackup_installer "CentOS / RedHat detected"; echo
            if curl -f -s -o installdeps-redhat https://raw.githubusercontent.com/langerak/superbackup/master/installdeps-redhat.sh > /dev/null 2>&1
            then
                chmod +x installdeps-redhat
                ./installdeps-redhat
            else
                echo -e "Could not download the dependency installer for $PRETTY_NAME, please check your network settings!"
                exit
            fi
        fi
    else
        echo -e "Unkown operating system.\n\nWe found the following OS:"
        cat /etc/os-release
        echo -e "You may file a feature request for this OS over at the following URL: https://github.com/langerak/superbackup\nMake sure to copy the output above in your feature request!"
        echo -e "\nThe Installer will now exit."
        logger -t superbackup_installer "Unknown Linux distribution detected, exiting"
        exit
    fi
}		
commandlineuninstall()
{
	echo -e "SuperBackupscript Uninstaller"
	logger -t superbackup_installer "CLI: Started the uninstall procedure"
	if ! [[ -f /etc/superbackup/backup.conf ]];
	then
		echo -e "\nSuperBackup is not installed!\n"
		logger -t superbackup_installer "CLI: Cannot uninstall script, because it is not installed"
		exit
	fi
	echo -n "Removing configfile: "
	if chattr -i /etc/superbackup/backup.conf > /dev/null 2>&1; rm -rf /etc/superbackup/ > /dev/null 2>&1
	then
		echo -e "OK"
		logger -t superbackup_installer "CLI: Removed configfile"
	else
		echo -e "FAILED\n\nPlease remove the configfile manually."
		logger -t superbackup_installer "CLI: Could not remove configfile"
	fi
	echo -n "Removing cronjob: "
	crontab -u root -l > /tmp/cron.txt
	if grep superbackup /tmp/cron.txt > /dev/null
	then
    	if sed -i '/superbackup/ d' /tmp/cron.txt; crontab /tmp/cron.txt; rm -f /tmp/cron.txt > /dev/null 2>&1
    	then
            	echo -e "OK"
            	logger -t superbackup_installer "CLI: Cronjob removed"
    	else
            	echo -e "FAILED, remove manually via \"crontab -e\""
            	logger -t superbackup_installer "CLI: Failed to remove cronjob"
    	fi
	else
		echo -e "FAILED, no cronjob found!"
		logger -t superbackup_installer "CLI: Cronjob not found"
	fi
	echo -n "Removing backupscript: "
	if rm -f /usr/local/bin/superbackup > /dev/null 2>&1
	then
		echo -e "OK"
		logger -t superbackup_installer "CLI: Removed the backupscript"
	else
		echo -e "FAILED\n\nPlease remove the script manually."
		logger -t superbackup_installer "CLI: Could not remove the backupscript"
	fi
	echo -e "\nUninstall of the SuperBackup Script is completed!\n"
	logger -t superbackup_installer "CLI: Uninstall of the backupscript is now finished"
	exit
}
commandlineupdate()
{
	clear
	echo -e "SuperBackupscript Upgrade"
	# Check if the script is installed:
	if ! [[ -f /usr/local/bin/superbackup ]];
	then
		echo -e "\nThe SuperBackup Backupscript is not installed, please install it first!\n"
		logger -t superbackup_installer "CLI: Cannot update backupscript because it is not installed"
		exit
	fi
	# Load configfile:
	if [ -f /etc/superbackup/backup.conf ];
	then
		source /etc/superbackup/backup.conf
	fi
	# Software checks:
	softwarecheck
	echo -e "\n"
    # Get current installed version:
	echo -n "Version check: "
	if [ -f /etc/superbackup/backup.conf ];
	then
    	version=$(cat /etc/superbackup/backup.conf | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g')
        versionstripped=$(echo $version | sed 's/\.//g')
    fi	
    # Get remote version:
    newversion=$(curl -s https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g' | head -1)
    newversionstripped=$(echo $newversion | sed 's/\.//g')
	# If both versions are the same:
    if [[ $versionstripped == $newversionstripped ]];
    then
        echo -e "Up-to-date ($newversion)\n"
        exit
	# If the versions differ:
    elif [[ $versionstripped < $newversionstripped ]];
    then
    	# If the configfile is superbackup:
    	if [ -f /etc/superbackup/backup.conf ];
    	then
            if curl -s -o /usr/local/bin/superbackup https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh > /dev/null 2>&1
            then
                chmod +x /usr/local/bin/superbackup > /dev/null 2>&1
                chattr -i /etc/superbackup/backup.conf
                perl -pi -w -e "s/VERSION=\"$version\"/VERSION=\"$newversion\"/" /etc/superbackup/backup.conf > /dev/null 2>&1
                chattr +i /etc/superbackup/backup.conf
                echo -e "Upgrade from $version to $newversion successfuly installed.\n\nThe new script will be used during the next run.\n"
                logger -t superbackup_installer "Found backupscript update, version $newversion is available, update is succesfully installed"
            else
                echo -e "Upgrade failed...\n\n"
                logger -t superbackup_installer "Found backupscript update, version $newversion, but failed to apply the update..."
            fi
            exit
        fi
	fi
	exit
}
commandlinelogcleaner()
{
    logger -t superbackup_installer "CLI: Started the log cleaning procedure"
    space=$(du -sch /var/log/backups/ | grep total | awk '{print $1}')
    echo -e "SuperBackup Log Cleaner\n\nThis will clear all backup logfiles where you will save "$space"B of diskspace:\n"
	echo -n "Clearing logs: "
    if rm -rf /var/log/backups/rsync/* > /dev/null 2>&1; rm -rf /var/log/backups/error/* > /dev/null 2>&1; rm -rf /var/log/backups/warn/* > /dev/null 2>&1; rm -rf /var/log/backups/temp/* > /dev/null 2>&1  & pid=$!; spinner $pid; wait $pid
    then
        echo -e "OK"
	logger -t superbackup_installer "CLI: Cleared all logs in /var/log/backups/, saved "$space"B of diskspace"
    else
	echo -e "FAILED\n\nCould not clear logs, will now exit..."
        logger -t superbackup_installer "CLI: Could not clear logs"
    fi
	logger -t superbackup_installer "CLI: Finished log cleaning procedure"
	exit
}
commandlineshowquota()
{
    echo -e "SuperBackup Quota Usage:\n"
    logger -t superbackup_installer "CLI: Started the show quota procedure"
    source /etc/superbackup/backup.conf
    if ssh -oStrictHostKeyChecking=no -p $SSHPORT -i $PRIVKEY $BUSER@$BSERVER "df -hT --block-size=G $REMOTEPATH | tail -n1" > /tmp/backup_quota 2>&1
    then
        REMOTE_BLOCKDEVICE=$(cat /tmp/backup_quota | awk '{print $1}')
        REMOTE_PARTITIONTYPE=$(cat /tmp/backup_quota | awk '{print $2}')
        QUOTATOTALSIZE=$(cat /tmp/backup_quota | awk '{print $3}' | cut -d G -f 1)
        QUOTAUSE=$(cat /tmp/backup_quota | awk '{print $4}' | cut -d G -f 1)
        QUOTAFREE=$(cat /tmp/backup_quota | awk '{print $5}' | cut -d G -f 1)
        QUOTAPERCUSE=$(cat /tmp/backup_quota | awk '{print $6}' | cut -d % -f 1)
	else
        echo -e "Could not retrieve quota information from $BSERVER for account $BUSER."
	fi
    echo -e "Server.........: $BSERVER"
    echo -e "Username.......: $BUSER"
    echo -e "Remote device..: $REMOTE_BLOCKDEVICE"
    echo -e "Partition type.: $REMOTE_PARTITIONTYPE"
    echo -e "Size...........: "$QUOTATOTALSIZE"GB"
    echo -e "Usage..........: "$QUOTAUSE"GB ($QUOTAPERCUSE%)"
    echo -e "Free...........: "$QUOTAFREE"GB"
    logger -t superbackup_installer "CLI: Quota lookup: $QUOTAUSE"GB" of $QUOTATOTALSIZE"GB""
    # Remove the temporary quota information file:
	rm -f /tmp/backup_quota > /dev/null 2>&1
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
	exit
}
commandlineinstall()
{
	echo -e "SuperBackupscript Installation V$version\n"
    if [ -f /etc/superbackup/backup.conf ];
    then
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThe backupscript is already installed.\n\nIf you want to change the configuration, please use the configuration editor." 10 60
        clear
        exit
    fi
    # Generate some data needed for the installation:
    genhour
    genminute
    genday
	softwarecheck
	mysqldumps
	newversion=$(curl -s https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-installer.sh | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g' | head -1)
    keytype="ecdsa"
    keyname="superbackup"
    if [ -f /etc/redhat-release ]
    then
        centosvers=$(grep -Eo "[0-9]\.[0-9]" /etc/redhat-release | cut -d . -f 1)
        if [[ $centosvers == 5 ]]
        then
            keytype="rsa"
        fi
    fi
	hostname=`hostname`
    # Update check cannot be on day 0 as it does not exist :)
    while [ $genday = 0 ];
    do
        genday
    done
    # First check if CSF is present, if so add the appropriate rules:
    if [ -d /etc/csf/ ];
    then
        echo -n "Preparing CSF: "
        backupip=`dig +short '{print $4}'`
        # Add IP of the backupserver to the allow list
        if csf -a $backupip
        then
            echo -e "OK"
        	logger -t superbackup_installer "CLI: IP $backupip added to CSF whitelist"
        else
            echo -e "FAILED!\n\nPlease check your CSF configuration and try again"
        	logger -t superbackup_installer "CLI: Could not add $backupip to CSF whitelist"
        	exit
        fi
    fi
    # Continue installing the script
    echo -n "Creating config: "
    if ! [ -d /etc/superbackup/ ];
    then
        mkdir -p /etc/superbackup/ > /dev/null 2>&1
	logger -t superbackup_installer "CLI: Created config directory"
    fi
    # Create the backup configuration file:
    if ! touch /etc/superbackup/backup.conf > /dev/null 2>&1
	then
		echo -e "Could not create configuration file! Exiting...\n"
		logger -t superbackup_installer "CLI: Could touch new configfile"
		exit
	fi
    echo -e "BUSER=$account" >> /etc/superbackup/backup.conf
    echo -e "BSERVER=$server" >> /etc/superbackup/backup.conf
    echo -e "NOTIFICATIONS=Y" >> /etc/superbackup/backup.conf
    echo -e "WEKEN=$weeks" >> /etc/superbackup/backup.conf
    echo -e "MAANDEN=$months" >> /etc/superbackup/backup.conf
    echo -e "PRIVKEY=/root/.ssh/$keytype.$keyname" >> /etc/superbackup/backup.conf
    echo -e "REPORTS_EMAIL=$email" >> /etc/superbackup/backup.conf
    echo -e "BACKUPROOT=/" >> /etc/superbackup/backup.conf
    echo -e "XFERSPEED=7500" >> /etc/superbackup/backup.conf
    echo -e "SSHPORT=22" >> /etc/superbackup/backup.conf
    echo -e "REMOTEPATH=/home/$account/" >> /etc/superbackup/backup.conf
    echo -e "H=$hostname" >> /etc/superbackup/backup.conf
    echo -e "LOGGING=Y" >> /etc/superbackup/backup.conf
    if [[ "$mysqldumps" == "Y" ]] ;
    then
        echo -e "MYSQLBACKUP=Y" >> /etc/superbackup/backup.conf
        echo -e "MYSQLUSER=$mysqluser" >> /etc/superbackup/backup.conf
        echo -e "MYSQLPASS=$mysqlpass" >> /etc/superbackup/backup.conf
        echo -e "MYSQLBACKUPDIR=/var/sqlbackups/" >> /etc/superbackup/backup.conf
    else
        echo -e "MYSQLBACKUP=N" >> /etc/superbackup/backup.conf
        echo -e "MYSQLUSER=none" >> /etc/superbackup/backup.conf
        echo -e "MYSQLPASS=none" >> /etc/superbackup/backup.conf
        echo -e "MYSQLBACKUPDIR=/var/sqlbackups/" >> /etc/superbackup/backup.conf
    fi
    echo -e "NICE_OPTS=\"$nice_opts\"" >> /etc/superbackup/backup.conf
    echo -e "UPDATECHECK=$day" >> /etc/superbackup/backup.conf
    echo -e "VERSION=\"$newversion\"" >> /etc/superbackup/backup.conf
    echo -e "AUTOUPDATE=Y" >> /etc/superbackup/backup.conf
    echo -e "OK"
    # Lock down the config, so it's only readable by root
    chmod 600 /etc/superbackup/backup.conf > /dev/null 2>&1
    logger -t superbackup_installer "CLI: configfile successfuly created"
    # Now source the configuration file:
    source /etc/superbackup/backup.conf
    # Create email recipients file:
	echo -e "$email" > /etc/superbackup/recipients.mail
	echo -n "Checking keyfile: "
    # Create the new key if needed:
    if [ -d /root/.ssh/ ]
    then 
        if [ -f "$PRIVKEY" ];
        then
            echo -e "Existing key found"
            logger -t superbackup_installer "CLI: Keyfile already exists"
        else
            if ssh-keygen -t $keytype -N '' -f /root/.ssh/id_"$keytype"."$keyname" > /dev/null 2>&1
            then
                echo -e "New $keytype key generated"
                logger -t superbackup_installer "CLI: New $keytype key generated ($PRIVKEY)"
            else
                echo -e "Could not generate new $keytype key!\n\nWill now exit!"
                logger -t superbackup_installer "Could not create new $keytype key ($PRIVKEY)"
                exit
            fi
        fi
    # If not, create it:
    else
        if mkdir -p /root/.ssh > /dev/null 2>&1
        then
            logger -t superbackup_installer "CLI: Created .ssh folder"
            if ssh-keygen -t $keytype -N '' -f /root/.ssh/id_"$keytype"."$keyname" > /dev/null 2>&1
            then
                echo -e "New $keytype key generated"
                logger -t superbackup_installer "CLI: New $keytype key generated ($PRIVKEY)"
            else
                echo -e "Could not generate new $keytype key!\n\nWill now exit!"
                logger -t superbackup_installer "Could not create new $keytype key ($PRIVKEY)"
                exit
            fi
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create .ssh folder!\n\nWill now exit!" 9 50
            logger -t superbackup_installer "Could not create .ssh folder"
            clear
            exit
        fi
    fi
    # Now that we have a key, we need to transfer it to the remote machine but first check if a authorized_keys file exists on the remote end:
    echo -n "Exchange keyfile: "
    if /usr/bin/expect > /dev/null 2> /dev/null << EOF
        spawn sftp -oConnectTimeout=60 -oStrictHostKeyChecking=no -oPort=$defaultsshport $account@$server
        expect "password:"
        send "$password\r"
        expect "sftp>"
        send "get .ssh/authorized_keys /root/\r"
        expect "sftp>"
        send "quit\r"
EOF
    then
        if [ -f /root/authorized_keys ]
        then
            echo -n "Keyfile found, key added and uploading new keyfile -> "
            logger -t superbackup_installer "CLI: Keyfile on remote server exists"
            if cat "$PRIVKEY".pub >> /root/authorized_keys;
            then
                if /usr/bin/expect > /dev/null 2> /dev/null << EOF
                    spawn sftp -oConnectTimeout=60 -oStrictHostKeyChecking=no -oPort=$defaultsshport $account@$server
                    expect "password:"
                    send "$password\r"
                    expect "sftp>"
                    send "put authorized_keys .ssh/authorized_keys\r"
                    expect "sftp>"
                    send "quit\r"
EOF
                then
                    echo -e "OK"
                    logger -t superbackup_installer "CLI: Exchanged keyfile with backupserver"
                    rm -f /root/authorized_keys > /dev/null 2>&1
                else
                    echo -e "Failed to exchange key with remote server!\n\nWill now exit!"
                    logger -t superbackup_installer "CLI: Could not exchange keyfile with backupserver"
                    rm -f /root/authorized_keys > /dev/null 2>&1
                    exit
                fi
            else
                echo -e "Could not add public key to authorized_keys file!\n\nWill now exit!"
                logger -t superbackup_installer "CLI: Could not add keyfile to authorized_keys file"
                rm -f /root/authorized_keys > /dev/null 2>&1
                exit
            fi
        # If it does not exist, we simply create a new authorized_keys file
        else
            if /usr/bin/expect > /dev/null 2>&1 << EOF
            spawn sftp -oStrictHostKeyChecking=no -oPort=$defaultsshport $account@$server
            expect "password:"
            send "$password\r"
            expect "sftp>"
            send "mkdir .ssh\r"
            expect "sftp>"
            send "cd .ssh\r"
            expect "sftp>"
            send "put $PRIVKEY.pub authorized_keys\r"
            expect "sftp>"
            send "quit\r"
EOF
            then
                echo -e "OK"
                logger -t superbackup_installer "No keyfile found, uploaded new keyfile to backupserver"
            fi
        fi
    fi
    echo -n "Installing script: "
    if curl -f -s -o /usr/local/bin/superbackup https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-installer.sh > /dev/null 2>&1
    then
        echo -e "OK"
    	logger -t superbackup_installer "CLI: Downloaded and installed backupscript"
    else
        echo -e "FAILED!\n\nPlease check your network connections."
    	logger -t superbackup_installer "CLI: Could not download and/or install backupscript"
        exit
    fi
    echo -n "Setting permissions: "
	if chmod +x /usr/local/bin/superbackup > /dev/null 2>&1
	then
		echo -e "OK"
		logger -t superbackup_installer "CLI: Changed permissions for backupscript"
	else
		echo -e "FAILED, will continue..."
		logger -t superbackup_installer "CLI: Could not change permissions for backupscript, but will continue"
	fi
    # Download the excludes list for rsync:
    echo -n "Downloading exclude list: "
    if curl -f -s -o /etc/superbackup/excludes.rsync https://raw.githubusercontent.com/langerak/superbackup/master/excludes.rsync > /dev/null 2>&1
    then
        echo -e "OK"
        logger -t superbackup_installer "CLI: Downloaded exclude list"
    else
        echo -e "FAILED!\n\nPlease check your network connections."
        logger -t superbackup_installer "CLI: Could not download exclude list"
        exit
    fi
    echo -n "Installing cronjob: "
	if [[ "$reports" == "Y" ]];
	then
        if cat <(crontab -l) <(echo "$minute $hour * * * /usr/local/bin/superbackup 2>&1 | mail -s '[SUPERBACKUP] Backupreport for `hostname`' $email") | crontab -
        then
            echo -e "OK"
        	logger -t superbackup_installer "CLI: Installed cronjob with emailaddress $email"
        else
            echo -e "FAILED\n\nThere was an error installing the cronjob!"
        	logger -t superbackup_installer "CLI: Could not install cronjob"
            exit 10
        fi
	else
		if cat <(crontab -l) <(echo "$minute $hour * * * /usr/local/bin/superbackup > /dev/null 2>&1") | crontab -
		then
			echo -e "OK"
			logger -t superbackup_installer "CLI: Installed cronjob without mail reporting"
		else
			echo -e "FAILED\n\nThere was an error installing the cronjob!"
			logger -t superbackup_installer "CLI: Could not install cronjob"
			exit 10
		fi
	fi
	echo -n "Mailing report: "
		# With simple installs, we always mail a report:
mail -s '[BACKUP] Backup installation on '$hostname' was successful' $email <<MAILEINDE
Dear customer,

The backupscript is installed successfuly on `hostname`!

The settings that were given are:
Backupserver......: $server
Username..........: $account
Local path........: /
Remote path.......: /home/$account/
SSH port..........: 22
Private key.......: $PRIVKEY
Private key type..: $keytype
Private key name..: $keyname
MySQL dumps.......: $mysqldumps
MySQL dump path...: /var/sqlbackups/
Reports emailaddr.: $email
Notifications addr: $email

Retention:
Basic retention based on 1 complete backup created on monday and with
incremental backups during the other weekdays.

Extra retention given:
Week(s)...........: $weeks
Month(s)..........: $months

Notifications:
The backupscript will notify you on time before the space runs out.

Updates:
The backupscript will check for updates every month on day $day.
Automatic updates.: Y

Logging functionality:
In addition, the script can log it's output for reference or
debugging purposes.

- Logging enabled.: Y

Job settings:
The script will run every day at $hour:$minute.

Backup reports:
- Receive reports: $reports

Note that you will always receive notifications, warnings and errors
if they occur during the backup, the reports are the daily report
mails that the script sends and are optional.

Help and support:
For more information, please refer to the online documentation at:
https://github.com/langerak/superbackup/wiki
 
Running the installer:
You can run the installer via the following command (if placed in /root/ and you are in /root/):
$0

Kind regards,

SuperBackup Support
MAILEINDE
    echo -e "OK"
	logger -t superbackup_installer "CLI: Emailed report to $email"
	echo -e "The installation is now finished!\n"
	logger -t superbackup_installer "CLI: Installation of the backupscript was successful and has finished"
    exit
}
# Installation email for easy install:
backupadvancedinstallationreport()
{
mail -s '[BACKUP] Backup installation on '$hostname' was successful' ${array[19]} <<MAILEINDE
Dear customer,

The backupscript is installed successfuly on $hostname!

The settings that were given are:
Backupserver......: ${array[2]}
Username..........: ${array[0]}
Local path........: ${array[3]}
Remote path.......: ${array[4]}
SSH port..........: ${array[6]}
MySQL dumps.......: ${array[9]}
MySQL dump path...: ${array[12]}
Reports address...: ${array[19]}
Send reports......: ${array[20]}

Reports:
If "Send reports" is set to "N" you will not receive the daily backup reports
the script can send. If you need to see the report, please search the general
syslog on the server for "backup_script" for more information.

Retention:
Basic retention based on 1 complete backup created on monday and with incremental
backups during the other weekdays.

Extra retention given:
Week(s)...........: ${array[7]}
Month(s)..........: ${array[8]}

Notifications:
Alerts, warnings and other critical notifications will be delivered to ${array[21]}.

Updates:
The backupscript will check for updates every month on day $day.
Automatic updates.: ${array[18]}

Logging:
In addition, the script can log the verbose output of rsync for reference.
- Logging enabled.: ${array[16]}

Job settings:
The script will run every day at ${array[13]}:${array[14]}.

Help and support:
Should you have any questions, please refer to the help section SuperBackup installer for the
most common asked questions. It's also possible to change the configuration details after the
installation, simply start the SuperBackup installer that is usually located in the root homedir.

Running the installer:
You can run the installer via the following command (if placed in /root/ and you are in /root/):
$0

There is online documentation available as well, please refer to the URL below:
http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-manual.pdf

Kind regards,
superbackup Support
MAILEINDE
}
# Installation email for easy install:
backupinstallationreport()
{
mail -s '[BACKUP] Backup installation on '$hostname' was successful' ${array[11]} <<MAILEINDE
Dear customer,

The backupscript is installed successfuly on `hostname`!

Global settings:
Backupserver......: ${array[2]}
Username..........: ${array[0]}
Local path........: ${array[3]}
Remote path.......: /home/${array[0]}/
SSH port..........: $defaultsshport
MySQL dumps.......: ${array[6]}
MySQL dump path...: ${array[7]}
Reports address...: ${array[11]}
Send reports......: ${array[12]}

Reports:
If "Send reports" is set to "N" you will not receive the daily backup reports
the script can send. If you need to see the report, please search the general
syslog on the server for "backup_script" for more information.

Retention:
Basic retention based on 1 complete backup created on monday and with incremental
backups during the other weekdays.

Extra retention given:
Week(s)...........: ${array[4]}
Month(s)..........: ${array[5]}

Notifications:
Alerts, warnings and other critical notifications will be delivered to ${array[12]}.

Updates:
The backupscript will check for updates every month on day $day.
Automatic updates.: Yes

Logging:
In addition, the script can log the verbose output of rsync for reference.
- Logging enabled.: ${array[10]}

Job settings:
The script will run every day at ${array[8]}:${array[9]}.

Help and support:
Should you have any questions, please refer to the help section SuperBackup installer for the
most common asked questions. It's also possible to change the configuration details after the
installation, simply start the SuperBackup installer that is usually located in the root homedir.
 
Running the installer:
You can run the installer via the following command (if placed in /root/ and you are in /root/):
$0

There is online documentation available as well, please refer to the URL below:
http://download.superbackup.com/pub/files/scripts/backup/superbackup-backup-manual.pdf

Kind regards,
superbackup Support
MAILEINDE
}
# Assign PID to files:
pid=$(echo $$)
# Setting global variables:
title=" SuperBackup Tool "
backtitle="SuperBackup Installation Script V$version"
backtitle_config="SuperBackup Configuration Editor"
backtitle_uninstall="SuperBackup Uninstaller"
backtitle_upgrade="SuperBackup Upgrade"
backtitle_test="SuperBackup Tester"
backtitle_quotacalc="SuperBackup Quota Calculator"
backtitle_help="SuperBackup Help System"
backtitle_quota="SuperBackup Quota"
backtitle_runbackup="SuperBackup Run"
backtitle_exchangekey="SuperBackup Key Exchange"
backtitle_mail="SuperBackup Mail Recipients List"
backtitle_excludes="SuperBackup Rsync Excludes List"
backtitle_explorer="SuperBackup Explorer"
# Make sure you are root
if [ "$(id -u)" != "0" ]; then
	if [ -f /usr/bin/dialog ];
	then
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nYou need to be root in order to use this installer.\n\nInstaller will now exit." 10 40
       	clear; exit
	else
		clear; echo -e "You need to be root in order to use this installer.\n\nInstaller will now exit."
		exit
	fi
fi
# Commandline options:
if [[ "$1" == "--help" ]];
then
    echo -e "The SuperBackup Installer recognizes the following options:"
    echo -e "\n\033[1m--help\033[0m\nThis help text"
    echo -e "\n\033[1m--uninstall\033[0m\nThis will completely uninstall the backupscript and it's configuration from the server."
	echo -e "\n\033[1m--update\033[0m\nThis will check if there are any updates available and will download / apply them if an update is available"
	echo -e "\n\033[1m--show-quota\033[0m\nThis will show the current quota usage for the used backupaccount\nThis will only work for SuperBackupservers!"
	echo -e "\n\033[1m--install\033[0m\nVia this way, the backupscript can be installed via the commandline, please refer to the online documentation for more information"
	echo -e "\n\033[1m--clear-logs\033[0m\nThis will remove all backup logs that are on the server"
	echo -e "\n\033[1m--edit-config\033[0m\nThis will start the nano editor opening the backup configuration file\n"
	exit
elif [[ "$1" == "--update" ]];
then
	commandlineupdate
	exit
elif [[ "$1" == "--show-quota" ]];
then
	commandlineshowquota
	exit
elif [[ "$1" == "--clear-logs" ]];
then
	commandlinelogcleaner
	exit
elif [[ "$1" == "--uninstall" ]];
then
	commandlineuninstall
	exit
elif [[ "$1" == "--install" ]];
then
    option=$(echo $1)
    account=$(echo $2)
    password=$(echo $3)
    server=$(echo $4)
	if ! [[ "$5" =~ ^[0-9]+$ ]];
	then
		echo -e "Weekly retention must be a number!"
		exit 1
	else
		weeks=$(echo $5)
	fi
	if ! [[ "$6" =~ ^[0-9]+$ ]];
	then
		echo -e "Monthly retention must be a number!"
		exit 2
	else
		months=$(echo $6)
	fi
	if ! [[ "$7" == "Y" || "$7" == "N" ]];
	then
		echo -e "MySQL dumps must be Y or N!"
		exit 3
	else
		mysqldumps=$(echo $7)
	fi
	if ! [[ "$8" = *?"@"?* ]];
	then
		echo -e "You need to specify an email address!"
		exit 4
	else
		email=$(echo $8)
	fi
	if ! [[ "$9" == "Y" || "$9" == "N" ]];
	then
		echo -e "Receiving reports must be Y or N!"
		exit 5
	else
		reports=$(echo $9)
	fi
	commandlineinstall
elif [[ "$1" == "--edit-config" ]];
then
	if chattr -i /etc/superbackup/backup.conf > /dev/null 2>&1
	then
		logger -t superbackup_installer "CLI: Unlocked the backup configuration file"
	else
        echo -e "Failed to unlock the SuperBackup configuration file...\n"
        logger -t superbackup_installer "CLI: Failed to unlock the backup configuration file"
		exit
	fi
	if which nano > /dev/null 2>&1
	then
		nano=`which nano`
		logger -t superbackup_installer "CLI: Starting nano editor to edit configuration"
		$nano /etc/superbackup/backup.conf
		logger -t superbackup_installer "CLI: Closed nano editor, stopped editing configuration"
    	if chattr +i /etc/superbackup/backup.conf > /dev/null 2>&1
    	then
        	logger -t superbackup_installer "CLI: Locked the backup configuration file"
    	else
        	echo -e "Failed to ock the SuperBackup configuration file...\n"
        	logger -t superbackup_installer "CLI: Failed to lock the backup configuration file"
        	exit
    	fi
	else
		echo -e "No nano editor found, cannot start editor."
		logger -t superbackup_installer "CLI: Editor nano not found, cannot start edit function"
		exit
	fi
	exit
elif ! [ -z $1 ];
then
	echo -e "Unknown commandline option \"$1\".\n\nPlease run with \"$0 --help\" for more information about the available commandline options."
	exit
fi
# Starting output ot the script:
clear
logger -t superbackup_installer "Started the SuperBackup Installer version $version"
echo -e "============================================================"
echo -e "=       SuperBackup Installation Script V$version             ="
echo -e "============================================================\n"
# Some basic system information. This is merely used for debugging purposes in case a bug needs to be filed:
echo -e "[ System Information ]"
echo -e "Hostname: `hostname`"
echo -e "Kernel: $kernel"
echo -e "Uptime: $system_uptime"
echo -e "Main IP: $primaryip"
echo -e "CPU: $cpu_cores x $cpu_type"
echo -e "Arch: $cpu_arch"
echo -e "RAM: "$memory"MB"
echo -e "Disk: "$currentsize"GB, "$currentsizeused"GB used, "$currentsizefree"GB free\n\n"
# Some software checks after we made sure we are root:
echo -e "[ Software Check ]"
softwarecheck
# Starting the dialog renderings from here:
#
# Quick update check to see if this is the latest release:
currentversion=$(echo $version | sed 's/"//g' | head -1)
currentversionstripped=$(echo $currentversion | sed 's/\.//g')
newversionstripped=$(echo $newversion | sed 's/\.//g')
if [[ $currentversionstripped < $newversionstripped ]];
then
	logger -t superbackup_installer "Upgrade detected from version $currentversion to version $newversion"
	dialog --backtitle "$backtitle_upgrade" --title "$title" --yesno "\nThere is an update available for this tool.\n\nThe current version is $currentversion and available is version $newversion.\n\nDo you want to upgrade?" 12 60
	agree=$?
	case $agree in
	0)
		if curl -s -o $0 https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-installer.sh > /dev/null 2>&1
		then
			dialog --backtitle "$backtitle_upgrade" --title "$title" --yesno "\nThe update was successful!\n\nDo you want to run the updated installer?" 9 60
			run=$?
			case $run in
			0)
				./$0
				clear
				exit
			;;
			1)
				clear
				exit
			;;
			esac
			logger -t superbackup_installer "The upgrade has been downloaded and installed"
		else
			dialog --backtitle "$backtitle_upgrade" --title "$title" --msgbox "\nCould not download the update. Will now exit." 7 60
			logger -t superbackup_installer "There was an unknown error while updating the installer, exiting..."
			clear
			exit
		fi
	;;
	1)
		dialog --backtitle "$backtitle_upgrade" --title "$title" --msgbox "\nYou do not want to update. Please note that you'll now be using the old version." 8 60
		logger -t superbackup_installer "Upgrade cancelled by user"
		clear
	;;
	esac
fi
clear
# If old or no configfile is found draw different menu:
if [ -f /etc/superbackup/backup.conf ];
then
    dialog --backtitle "$backtitle" --title "$title" --menu "\nSelect action:" 9 50 0 \
    "3" "Configuration editor" \
    "4" "Uninstall backupscript" \
    "5" "Update backupscript" \
    "6" "Test functionality" \
    "7" "Quota calculator" \
    "8" "Clear backup logs" \
    "9" "Show account quota" \
    "10" "Data recovery (script)" \
    "11" "Run backupscript (manual run)" \
    "12" "Exchange SSH keyfile" \
    "13" "Mail recipients list" \
    "14" "Rsync excludes list" \
    "15" "Backup explorer" \
    "16" "Help" 2> /tmp/$pid-action
    escaper
    action=$(cat /tmp/$pid-action); rm -f /tmp/$pid-action > /dev/null 2> /dev/null
else
    dialog --backtitle "$backtitle" --title "$title" --menu "\nThis menu is currently not showing all options. Please install the backupscript in order to use all the functions.\n\nSelect action:" 12 50 0 \
    "1" "Install backupscript (easy)" \
    "2" "Install backupscript (advanced)" \
    "7" "Quota calculator" \
    "16" "Help" 2> /tmp/$pid-action
    escaper 
    action=$(cat /tmp/$pid-action); rm -f /tmp/$pid-action > /dev/null 2> /dev/null
fi
# The specific actions in the script:
case $action in
1)
	logger -t superbackup_installer "Started the easy backup installation procedure"
	if [ -f /etc/superbackup/backup.conf ];
	then
		dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThe backupscript is already installed.\n\nIf you want to change the configuration, please use the configuration editor." 10 60
		clear
		exit
	fi
	if [ -f /etc/backups/xlsbackup.conf ];
	then
		dialog --backtitle "$backtitle" --title "$title" --msgbox "\nOld configfile found, please upgrade the script instead of installing it again." 8 60
		clear
		exit
	fi
    # Global variable setup:
	genhour
	genminute
	genday
	mysqldumps
	while [ $genday = 0 ];
	do
		genday
	done
    keytype="ecdsa"
    keyname="superbackup"
    if [ -f /etc/redhat-release ]
    then
        centosvers=$(grep -Eo "[0-9]\.[0-9]" /etc/redhat-release | cut -d . -f 1)
        if [[ $centosvers == 5 ]]
        then
            keytype="rsa"
        fi
    fi
    # Starting the menu rendering
	dialog --column-separator "|" --backtitle "$backtitle" --title "$title" --form "\nBackup configurator\n" 22 65 0 \
	"Backup username....:" 1 1 "" 1 22 15 0 \
	"Backup password....:" 2 1 "" 2 22 30 0 \
	"Backup server......:" 3 1 "" 3 22 35 0 \
	"Backup root dir....:" 4 1 "/" 4 22 35 0 \
	"Weekly retention...:    $currentsizeused"GB" extra needed per week" 5 1 "0" 5 22 2 0 \
	"Monthly retention..:    $currentsizeused"GB" extra needed per month" 6 1 "0" 6 22 2 0 \
	"Enable MySQL dumps.:" 7 1 "$mysqldumps" 7 22 1 0 \
	"MySQL dump dir.....:" 8 1 "/var/sqlbackups/" 8 22 35 0 \
	"Hour schedule (HH).:" 9 1 "$hour" 9 22 2 0 \
	"Minute sched. (MM).:" 10 1 "$minute" 10 22 2 0 \
	"Extensive logging..:" 11 1 "Y" 11 22 1 0 \
	"Backup report email:" 12 1 "" 12 22 35 0 \
	"Send reports.......:" 13 1 "N" 13 22 1 0\
	"Alerts email.......:" 14 1 "" 14 22 35 0 2> /tmp/$pid-options
	escaper
	choice=$?
    array=( `cat /tmp/$pid-options `)
    if [ -f /tmp/$pid-options ];
    then
            rm -f /tmp/$pid-options > /dev/null 2> /dev/null
    fi
    while [ ${#array[@]} -lt 13 ]
    do
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nNot all fields are populated!\n\nPlease make sure you fill in all the fields." 10 50; clear
		logger -t superbackup_installer "Not all form fields are populated, returning to form..."
    	dialog --column-separator "|" --backtitle "$backtitle" --title "$title" --form "\nBackup configurator\n" 22 60 0 \
    	"Backup username....:" 1 1 "${array[0]}" 1 22 15 0 \
    	"Backup password....:" 2 1 "${array[1]}" 2 22 30 0 \
    	"Backup server......:" 3 1 "${array[2]}" 3 22 35 0 \
    	"Backup root dir....:" 4 1 "${array[3]}" 4 22 35 0 \
    	"Weekly retention...:    $currentsize"GB" extra needed per week" 5 1 "${array[4]}" 5 1 "${array[4]}" 5 22 2 0 \
    	"Monthly retention..:    $currentsize"GB" extra needed per month" 6 1 "${array[5]}" 6 22 2 0 \
    	"Enable MySQL dumps.:" 7 1 "${array[6]}" 7 22 1 0 \
    	"MySQL dump dir.....:" 8 1 "${array[7]}" 8 22 35 0 \
    	"Hour schedule (HH).:" 9 1 "${array[8]}" 9 22 2 0 \
    	"Minute sched. (MM).:" 10 1 "${array[9]}" 10 22 2 0 \
    	"Extensive logging..:" 11 1 "${array[10]}" 11 22 1 0 \
    	"Backup report email:" 12 1 "${array[11]}" 12 22 35 0 \
	    "Send reports.......:" 13 1 "${array[12]}" 13 22 1 0 \
    	"Alerts email.......:" 14 1 "${array[13]}" 14 22 35 0 2> /tmp/$pid-options
    	escaper
	    choice=$?
        array=( `cat /tmp/$pid-options` )
    	if [ -f /tmp/$pid-options ];
    	then
            	rm -f /tmp/$pid-options > /dev/null 2> /dev/null
    	fi
   	done
	case $choice in
    0)
	clear
	# First check if CSF is present, if so add the appropriate rules:
	if [ -d /etc/csf/ ];
	then
		backupip=`dig +short ${array[2]}`
		# Restart CSF
		echo "5" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nAdding backupserver IP to whitelist" 8 50
		if csf -a $backupip
		then
			echo "5" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nAdded backupserver IP to whitelist" 8 50; sleep 1
			logger -t superbackup_installer "Added backupserver IP to whitelist"
		else
			dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not add backupserver IP to whitelist, installation will not be possible!\n\nPlease check your CSF settings and re-run this installer" 9 60
			logger -t superbackup_installer "Could not add backupserver IP to whitelist, installation not possible at this time"
		exit
		fi
	fi
	# Creating the configfile
	echo "10" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating configfile" 8 50 0
	if ! [ -d /etc/superbackup/ ];
	then
    	if mkdir -p /etc/superbackup/ > /dev/null 2>&1
    	then
    		logger -t superbackup_installer "Created the config directory /etc/superbackup/"
    	else
    		dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the configuration directory /etc/superbackup/\n\nExiting..." 9 60
    		logger -t superbackup_installer "Failed to create the config directory /etc/superbackup/"
    		clear
    		exit
    	fi
	fi
    if ! touch /etc/superbackup/backup.conf > /dev/null 2>&1
    then
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the configfile!\n\nInstaller will now exit!" 10 50
    fi
    # Fill the configfile
	echo -e "BUSER=${array[0]}" >> /etc/superbackup/backup.conf
	echo -e "BSERVER=${array[2]}" >> /etc/superbackup/backup.conf
	echo -e "NOTIFICATIONS=Y" >> /etc/superbackup/backup.conf
	echo -e "WEKEN=${array[4]}" >> /etc/superbackup/backup.conf
	echo -e "MAANDEN=${array[5]}" >> /etc/superbackup/backup.conf
	echo -e "PRIVKEY=/root/.ssh/id_$keytype.$keyname" >> /etc/superbackup/backup.conf
	echo -e "BACKUPROOT=${array[3]}" >> /etc/superbackup/backup.conf
	echo -e "XFERSPEED=7500" >> /etc/superbackup/backup.conf
	echo -e "SSHPORT=$defaultsshport" >> /etc/superbackup/backup.conf
	echo -e "REMOTEPATH=/home/${array[0]}/" >> /etc/superbackup/backup.conf
	echo -e "H=$hostname" >> /etc/superbackup/backup.conf
	if [ ${array[10]} = "Y" ];
	then
    	echo -e "LOGGING=Y" >> /etc/superbackup/backup.conf
	else
    	echo -e "LOGGING=N" >> /etc/superbackup/backup.conf
	fi
	if [ ${array[6]} = "Y" ] ;
	then	
    	echo -e "MYSQLBACKUP=Y" >> /etc/superbackup/backup.conf
    	echo -e "MYSQLUSER=$mysqluser" >> /etc/superbackup/backup.conf
    	echo -e "MYSQLPASS=$mysqlpass" >> /etc/superbackup/backup.conf
    	echo -e "MYSQLBACKUPDIR=${array[7]}" >> /etc/superbackup/backup.conf
	else
    	echo -e "MYSQLBACKUP=N" >> /etc/superbackup/backup.conf
    	echo -e "MYSQLUSER=$mysqluser" >> /etc/superbackup/backup.conf
    	echo -e "MYSQLPASS=$mysqlpass" >> /etc/superbackup/backup.conf
    	echo -e "MYSQLBACKUPDIR=${array[7]}" >> /etc/superbackup/backup.conf
	fi
    echo -e "NICE_OPTS=\"$nice_opts\"" >> /etc/superbackup/backup.conf
	echo -e "UPDATECHECK=$day" >> /etc/superbackup/backup.conf
	echo -e "VERSION=\"$newversion\"" >> /etc/superbackup/backup.conf
	echo -e "AUTOUPDATE=Y" >> /etc/superbackup/backup.conf
	echo -e "PATCHED=Y" >> /etc/superbackup/backup.conf
	echo -e "REPORTS_EMAIL=${array[11]}" >> /etc/superbackup/backup.conf
    # Lock down the config, so it's only readable by root
    chmod 600 /etc/superbackup/backup.conf > /dev/null 2>&1
	echo -e "${array[13]}" > /etc/superbackup/recipients.mail
	logger -t superbackup_installer "Created the configfile"
    echo "12" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated configfile" 8 50 0; sleep 1
    # Source the configfile:
    source /etc/superbackup/backup.conf
    # Create the excludes list:
    echo "15" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating excludes list" 8 50 0
    echo -e $excludes > /etc/superbackup/excludes.rsync
    echo "17" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated excludes list" 8 50 0
    # Create SSH key / Reuse key
    if [ -d /root/.ssh/ ]
    then 
        if [ -f "$PRIVKEY" ];
        then
            echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile found, not generating a new one" 8 50 0
            logger -t superbackup_installer "Keyfile exists, reusing"
        else
            echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nGenerating new key" 8 50 0
            if ssh-keygen -t $keytype -N '' -f /root/.ssh/id_"$keytype"."$keyname" > /dev/null 2>&1
            then
                echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey successfully generated" 8 50 0
                logger -t superbackup_installer "Generated keyfile $PRIVKEY"
            else
                dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the key!\n\nWill now exit!" 9 50
                logger -t superbackup_installer "Could not create keyfile $PRIVKEY"
                clear
                exit
            fi
        fi
    else
        echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating .ssh folder in /root/" 8 50 0
        if mkdir -p /root/.ssh > /dev/null 2>&1
        then
            echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated .ssh folder in /root/" 8 50 0; sleep 1
            logger -t superbackup_installer "Created .ssh folder"
            echo "24" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nGenerating new SSH-key" 8 50 0
            if ssh-keygen -t $keytype -N '' -f /root/.ssh/id_"$keytype"."$keyname" > /dev/null 2>&1
            then
                echo "27" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey successfully generated" 8 50 0
                logger -t superbackup_installer "Generated keyfile $PRIVKEY"
            else
                dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the key!\n\nWill now exit!" 9 50
                logger -t superbackup_installer "Could not create keyfile $PRIVKEY"
                clear
                exit
            fi
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create .ssh folder!\n\nWill now exit!" 9 50
            logger -t superbackup_installer "Could not create .ssh folder"
            clear
            exit
        fi
    fi
    # Download / Add / Reupload key
    echo "30" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nChecking for keyfile on the backupserver" 8 50 0
    if /usr/bin/expect > /dev/null 2> /dev/null << EOF
    spawn sftp -oStrictHostKeyChecking=no -oPort=$defaultsshport ${array[0]}@${array[2]}
    expect "password:"
    send "${array[1]}\r"
    expect "sftp>"
    send "get .ssh/authorized_keys .\r"
    expect "sftp>"
    send "quit\r"
EOF
    then
        if [ -f authorized_keys ]
        then
            echo "40" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile found, adding key to keyfile" 8 50 0
            logger -t superbackup_installer "Keyfile on remote server exists"
            if cat "$PRIVKEY".pub >> authorized_keys
            then
                echo "43" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey added to keyfile" 8 50 0; sleep 1
                logger -t superbackup_installer "Local key added to keyfile"
                echo "47" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nUploading keyfile to backupserver" 8 50 0
                if /usr/bin/expect > /dev/null 2>&1 << EOF
                spawn sftp -oStrictHostKeyChecking=no -oPort=$defaultsshport ${array[0]}@${array[2]}
                expect "password:"
                send "${array[1]}\r"
                expect "sftp>"
                send "put authorized_keys .ssh/authorized_keys\r"
                expect "sftp>"
                send "quit\r"
EOF
                then
                    echo "48" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nUploaded keyfile to backupserver" 8 50 0
                    rm -f authorized_keys > /dev/null 2>&1
                    logger -t superbackup_installer "Uploaded keyfile back to backupserver"
                else
                    dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not upload keyfile back to backupserver\n\nWill now exit" 9 50
                    logger -t superbackup_installer "Could not upload keyfile to backupserver"
                    exit
                fi
            else
                echo "40" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile not found, creating and uploading new keyfile" 8 50 0
                if /usr/bin/expect > /dev/null 2>&1 << EOF
                spawn sftp -oStrictHostKeyChecking=no -oPort=$defaultsshport ${array[0]}@${array[2]}
                expect "password:"
                send "${array[1]}\r"
                expect "sftp>"
                send "mkdir .ssh\r"
                expect "sftp>"
                send "cd .ssh\r"
                expect "sftp>"
                send "put .ssh/id_$keytype.$keyname.pub authorized_keys\r"
                expect "sftp>"
                send "quit\r"
EOF
                then
                    echo "45" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nUploaded keyfile to backupserver" 8 50 0
                    rm -f authorized_keys > /dev/null 2>&1
                    logger -t superbackup_installer "Uploaded keyfile back to backupserver"
                else
                    dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not upload keyfile back to backupserver\n\nWill now exit" 9 50
                    logger -t superbackup_installer "Could not upload keyfile to backupserver"
                    exit
                fi                
            fi
        fi
    fi
    # Download the backupscript
    echo "50" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloading backupscript" 8 50 0
    if curl -s -o /usr/local/bin/superbackup https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh > /dev/null 2>&1
    then
        echo "60" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownload of the backupscript succeeded" 8 50 0
        logger -t superbackup_installer "Succesfully downloaded the backupscript"
    else
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nDownload of the script failed!\nPlease check your network settings" 9 50
        logger -t superbackup_installer "Failed to download the backupscript, please check your network setup"
        $0 --uninstall > /dev/null 2>&1
        clear
        exit
    fi
    # Setting permissions
    echo "70" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting permissions on script" 8 50 0
    if chmod +x /usr/local/bin/superbackup > /dev/null 2>&1
    then
        echo "75" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting permissions on script with success" 8 50 0
        logger -t superbackup_installer "Setting permissions on the backupscript with success"
    else
        echo "75" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCould not set permissions" 8 50 0
        logger -t superbackup_installer "Could not set permissions on backupscript"
    fi
    # Download the exclude list
    echo "77" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloading exclude list" 8 50 0
    if curl -s -o /etc/superbackup/excludes.rsync https://raw.githubusercontent.com/langerak/superbackup/master/excludes.rsync > /dev/null 2>&1
    then
        echo "79" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownload of the exclude list succeeded" 8 50 0
        logger -t superbackup_installer "Succesfully downloaded the exclude list"
    else
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThere was an error downloading the exclude list.\n\nThe installer will now exit!" 10 50
        logger -t superbackup_installer "Failed to download the exclude list, please check your network setup"
        $0 --uninstall > /dev/null 2>&1
        clear
        exit
    fi
    # Setup cronjob
    echo "80" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting up cronjob" 8 50
    if [[ "${array[12]}" == "Y" ]];
    then
        if cat <(crontab -l) <(echo "${array[9]} ${array[8]} * * * /usr/local/bin/superbackup 2>&1 | mail -s '[SUPERBACKUP] Backupreport of `hostname`' ${array[11]}") | crontab -
        then
            echo "90" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSuccessfully set up the cronjob" 8 50
            logger -t superbackup_installer "Installed cronjob at ${array[8]}:${array[9]}"
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThere was an error setting up the cronjob.\n\nThe installer will now exit!" 10 50
            logger -t superbackup_installer "There was an error installing the cronjob, exiting..."
            $0 --uninstall > /dev/null 2>&1
            clear
            exit
        fi
    else
        if cat <(crontab -l) <(echo "${array[9]} ${array[8]} * * * /usr/local/bin/superbackup > /dev/null 2>&1") | crontab -
        then
            echo "90" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSuccessfully set up the cronjob" 8 50
            logger -t superbackup_installer "Installed cronjob at ${array[8]}:${array[9]}"
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThere was an error setting up the cronjob.\n\nThe installer will now exit!" 10 50
            logger -t superbackup_installer "There was an error installing the cronjob, exiting..."
            $0 --uninstall > /dev/null 2>&1
            clear
            exit
        fi
    fi
	echo "100" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nInstallation finished!" 8 50; sleep 1
	logger -t superbackup_installer "Backupscript installation succeeded!"
	dialog --backtitle "$backtitle" --title "$title" --yesno "\nDo you want to have a short installation report emailed to the following address?\n\n${array[11]}?" 10 60
	sendreport=$?
	if [ $sendreport = 0 ];
	then
		backupinstallationreport
		dialog --backtitle "$backtitle" --title "$title" --msgbox "\nInstallation report has been sent to the following address:\n\n${array[11]}." 10 60
		logger -t superbackup_installer "Sent installation report to ${array[11]}"
	fi
	dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCongratulations!\n\nThe backupscript is now installed on this machine!" 10 50
	clear
	exit
;;
esac
logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
2)
	logger -t superbackup_installer "Started the advanced installation procedure"
    if [ -f /etc/superbackup/backup.conf ];
    then
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThe backupscript is already installed.\n\nIf you want to change the configuration, please use the configuration editor." 10 60
        clear
        exit
    fi
    genhour
    genminute
	genday
	mysqldumps
	while [ $genday = 0 ];
	do
		genday
	done
    # Start the dialog render
    dialog --column-separator "|" --backtitle "$backtitle" --title "$title" --form "Advanced backup configurator\n" 0 60 24 \
    "Backup username....:" 1 1 "" 1 22 20 0 \
    "Backup password....:" 2 1 "" 2 22 20 0 \
    "Backup server......:" 3 1 "" 3 22 30 0 \
    "Backup root path...:" 4 1 "/" 4 22 30 0 \
	"Remote backup path.:" 5 1 "/your/remote/path/" 5 22 30 0 \
	"SSH Key Type.......:" 6 1 "ecdsa" 6 22 10 0 \
    "SSH Key Name.......:" 7 1 "superbackup" 7 22 30 0 \
	"SSH Port...........:" 8 1 "22" 8 22 5 0 \
    "Weekly retention...:    $currentsize"GB" extra needed per week" 9 1 "0" 9 22 2 0 \
    "Monthly retention..:    $currentsize"GB" extra needed per month" 10 1 "0" 10 22 2 0 \
    "MySQL dumps........:" 11 1 "$mysqldumps" 11 22 1 0 \
	"MySQL username.....:" 12 1 "$mysqluser" 12 22 20 0 \
	"MySQL password.....:" 13 1 "$mysqlpass" 13 22 20 0 \
    "MySQL dump folder..:" 14 1 "/var/sqlbackups/" 14 22 35 0 \
    "Hour schedule (HH).:" 15 1 "$hour" 15 22 2 0 \
    "Minute sched. (MM).:" 16 1 "$minute" 16 22 2 0 \
	"Notifications......:" 17 1 "Y" 17 22 1 0 \
    "Verbose logging....:" 18 1 "Y" 18 22 1 0 \
	"Xfer speed (in KBs):" 19 1 "7500" 19 22 6 0 \
	"Automatic updates..:" 20 1 "Y" 20 22 1 0 \
    "Backup report email:" 21 1 "" 21 22 30 0 \
	"Send reports.......:" 22 1 "N" 22 22 1 0 \
    "Alerts email.......:" 23 1 "" 23 22 30 0 2> /tmp/$pid-options
    escaper
    choice=$?
    array=( `cat /tmp/$pid-options `)
    if [ -f /tmp/$pid-options ];
    then
        rm -f /tmp/$pid-options > /dev/null 2>&1
    fi	
    while ! [ ${#array[@]} = 23 -o ${#array[@]} = 22 -o ${#array[@]} = 21 ]
    do
        logger -t superbackup_installer "Not all fields are populated, returning to the form"
        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nNot all fields are populated!\n\nPlease make sure you fill in all the fields." 10 50; clear
        dialog  --column-separator "|" --backtitle "$backtitle" --title "$title" --form "Backup configurator\n" 24 60 0 \
        "Backup username....:" 1 1 "${array[0]}" 1 22 20 0 \
        "Backup password....:" 2 1 "${array[1]}" 2 22 20 0 \
        "Backup server......:" 3 1 "${array[2]}" 3 22 30 0 \
        "Backup root path...:" 4 1 "${array[3]}" 4 22 30 0 \
        "Backup remote path.:" 5 1 "${array[4]}" 5 22 30 0 \
        "SSH Key Type.......:" 6 1 "${array[5]}" 6 22 10 0 \
        "SSH Key Name.......:" 7 1 "${array[6]}" 7 22 30 0 \
        "SSH Port...........:" 8 1 "${array[7]}" 8 22 5 0 \
        "Weekly retention...:    $currentsize"GB" extra needed per week" 9 1 "${array[8]}" 9 22 2 0 \
        "Monthly retention..:    $currentsize"GB" extra needed per month" 10 1 "${array[9]}" 10 22 2 0 \
        "MySQL dumps........:" 11 1 "${array[10]}" 11 22 1 0 \
        "MySQL username.....:" 12 1 "${array[11]}" 12 22 20 0 \
        "MySQL password.....:" 13 1 "${array[12]}" 13 22 20 0 \
        "MySQL dump folder..:" 14 1 "${array[13]}" 14 22 35 0 \
        "Hour schedule (HH).:" 15 1 "${array[14]}" 15 22 2 0 \
        "Minute sched. (MM).:" 16 1 "${array[15]}" 16 22 2 0 \
        "Notifications......:" 17 1 "${array[16]}" 17 22 1 0 \
        "Verbose logging....:" 18 1 "${array[17]}" 18 22 1 0 \
        "Xfer speed (in KBs):" 19 1 "${array[18]}" 19 22 5 0 \
        "Automatic updates..:" 20 1 "${array[19]}" 20 22 1 0 \
        "Backup report email:" 21 1 "${array[20]}" 21 22 30 0 \
        "Send reports.......:" 22 1 "${array[21]}" 22 22 1 0 \
        "Alerts email.......:" 23 1 "${array[22]}" 23 22 30 2> /tmp/$pid-options
        escaper
        choice=$?
        array=( `cat /tmp/$pid-options `)
        if [ -f /tmp/$pid-options ];
        then
                rm -f /tmp/$pid-options > /dev/null 2>&1
        fi
    done
    case $choice in
    0)
        # First check if CSF is present, if so add the appropriate rules:
		if [ -d /etc/csf/ ];
		then
    		echo "0" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nAdding backupserver IP to CSF whitelist" 8 50
    		backupip=`dig +short ${array[2]}`
    		# Add IP of the backupserver to the allow list
    		echo -e "$backupip # Backupserver ${array[2]}" >> /etc/csf/csf.allow
    		logger -t superbackup_installer "Added IP address $backupip to the whitelist of CSF"
    		# Restart CSF
    		echo "5" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nRestarting the CSF service" 8 50
    		if csf -r > /dev/null 2>&1
    		then
            	echo "5" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nRestarted the CSF service" 8 50; sleep 1
            	logger -t superbackup_installer "Restarted the CSF service"
    		else
        		dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not restart CSF, installation will not be possible!\n\nPlease check your CSF settings and re-run this installer" 9 60
        		logger -t superbackup_installer "Could not restart CSF service and backup is not possible, exiting..."
    		exit
    		fi
		fi
        # Continue installing the script
        #
        # Create configfile
        echo "10" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating configfile" 8 50 0
        if ! [ -d /etc/superbackup/ ];
        then
            mkdir -p /etc/superbackup/ > /dev/null 2>&1
        fi
        touch /etc/superbackup/backup.conf > /dev/null 2>&1
        echo -e "BUSER=${array[0]}" >> /etc/superbackup/backup.conf
        echo -e "BSERVER=${array[2]}" >> /etc/superbackup/backup.conf
        echo -e "NOTIFICATIONS=${array[16]}" >> /etc/superbackup/backup.conf
        echo -e "WEKEN=${array[8]}" >> /etc/superbackup/backup.conf
        echo -e "MAANDEN=${array[9]}" >> /etc/superbackup/backup.conf
        echo -e "PRIVKEY=/root/.ssh/id_${array[5]}.${array[6]}" >> /etc/superbackup/backup.conf
        echo -e "BACKUPROOT=${array[3]}" >> /etc/superbackup/backup.conf
        echo -e "XFERSPEED=${array[18]}" >> /etc/superbackup/backup.conf
        echo -e "SSHPORT=${array[7]}" >> /etc/superbackup/backup.conf
        echo -e "REMOTEPATH=${array[4]}" >> /etc/superbackup/backup.conf
        echo -e "H=$hostname" >> /etc/superbackup/backup.conf
        if [ ${array[16]} = "Y" ];
        then
            echo -e "LOGGING=Y" >> /etc/superbackup/backup.conf
        else
            echo -e "LOGGING=N" >> /etc/superbackup/backup.conf
        fi
        if [ ${array[10]} = "Y" ] ;
        then
            echo -e "MYSQLBACKUP=Y" >> /etc/superbackup/backup.conf
            echo -e "MYSQLUSER=${array[11]}" >> /etc/superbackup/backup.conf
            echo -e "MYSQLPASS=${array[12]}" >> /etc/superbackup/backup.conf
            echo -e "MYSQLBACKUPDIR=${array[13]}" >> /etc/superbackup/backup.conf
        else
            echo -e "MYSQLBACKUP=N" >> /etc/superbackup/backup.conf
            echo -e "MYSQLUSER=$mysqluser" >> /etc/superbackup/backup.conf
            echo -e "MYSQLPASS=$mysqluser" >> /etc/superbackup/backup.conf
            echo -e "MYSQLBACKUPDIR=${array[13]}" >> /etc/superbackup/backup.conf
        fi
        echo -e "NICE_OPTS=\"$nice_opts\"" >> /etc/superbackup/backup.conf
        echo -e "UPDATECHECK=$day" >> /etc/superbackup/backup.conf
		echo -e "VERSION=\"$newversion\"" >> /etc/superbackup/backup.conf
		echo -e "AUTOUPDATE=${array[19]}" >> /etc/superbackup/backup.conf
		echo -e "PATCHED=Y" >> /etc/superbackup/backup.conf
		echo -e "REPORTS_EMAIL=${array[20]}" >> /etc/superbackup/backup.conf
        # Lock down the config, so it's only readable by root
        chmod 600 /etc/superbackup/backup.conf > /dev/null 2>&1
        # Create the recipients file
		if [ -z "${array[22]}" ];
		then
        	echo -e "${array[21]}" > /etc/superbackup/recipients.mail
		else
        	echo -e "${array[22]}" > /etc/superbackup/recipients.mail
    	fi
        echo "12" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated configfile" 8 50 0; sleep 1
        # Source the configfile for further usage throughout the installation:
        source /etc/superbackup/backup.conf
        # Create the excludes list:
        echo "15" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating excludes list" 8 50 0
        echo -e $excludes > /etc/superbackup/excludes.rsync
        echo "17" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated excludes list" 8 50 0
        # Create SSH key / Reuse key
        if [ -d /root/.ssh/ ]
        then 
            if [ -f "$PRIVKEY" ];
            then
                echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile found, not generating a new one" 8 50 0
                logger -t superbackup_installer "Keyfile exists, reusing"
            else
                echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nGenerating new key" 8 50 0
                if ssh-keygen -t ${array[5]} -N '' -f /root/.ssh/id_"${array[5]}"."${array[6]}" > /dev/null 2>&1
                then
                    echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey successfully generated" 8 50 0
                    logger -t superbackup_installer "Generated keyfile $PRIVKEY"
                else
                    dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the key!\n\nWill now exit!" 9 50
                    logger -t superbackup_installer "Could not create keyfile $PRIVKEY"
                    clear
                    exit
                fi
            fi
        else
            echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating .ssh folder in /root/" 8 50 0
            if mkdir -p /root/.ssh > /dev/null 2>&1
            then
                echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated .ssh folder in /root/" 8 50 0
                logger -t superbackup_installer "Created .ssh folder"
                echo "24" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nGenerating new SSH-key" 8 50 0
                if ssh-keygen -t ${array[5]} -N '' -f /root/.ssh/id_"${array[5]}"."${array[6]}" > /dev/null 2>&1
                then
                    echo "27" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey successfully generated" 8 50 0
                    logger -t superbackup_installer "Generated keyfile $PRIVKEY"
                else
                    dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the key!\n\nWill now exit!" 9 50
                    logger -t superbackup_installer "Could not create keyfile $PRIVKEY"
                    clear
                    exit
                fi
            else
                dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create .ssh folder!\n\nWill now exit!" 9 50
                logger -t superbackup_installer "Could not create .ssh folder"
                clear
                exit
            fi
        fi
        # Download / Add / Reupload key
        echo "30" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nChecking for keyfile on the backupserver" 8 50 0
        if /usr/bin/expect > /dev/null 2> /dev/null << EOF
        spawn sftp -oStrictHostKeyChecking=no -oPort=${array[7]} ${array[0]}@${array[2]}
        expect "password:"
        send "${array[1]}\r"
        expect "sftp>"
        send "get .ssh/authorized_keys .\r"
        expect "sftp>"
        send "quit\r"
EOF
        then
            if [ -f authorized_keys ]
            then
                echo "40" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile found, adding key to keyfile" 8 50 0
                logger -t superbackup_installer "Keyfile on remote server exists"
                if cat "$PRIVKEY".pub >> authorized_keys
                then
                    echo "43" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey added to keyfile" 8 50 0; sleep 1
                    logger -t superbackup_installer "Local key added to keyfile"
                    echo "47" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nUploading keyfile to backupserver" 8 50 0
                    if /usr/bin/expect > /dev/null 2>&1 << EOF
                    spawn sftp -oStrictHostKeyChecking=no -oPort=${array[7]} ${array[0]}@${array[2]}
                    expect "password:"
                    send "${array[1]}\r"
                    expect "sftp>"
                    send "put authorized_keys .ssh/authorized_keys\r"
                    expect "sftp>"
                    send "quit\r"
EOF
                    then
                        echo "48" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nUploaded keyfile to backupserver" 8 50 0
                        rm -f authorized_keys > /dev/null 2>&1
                        logger -t superbackup_installer "Uploaded keyfile back to backupserver"
                    else
                        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not upload keyfile back to backupserver\n\nWill now exit" 9 50
                        logger -t superbackup_installer "Could not upload keyfile to backupserver"
                        exit
                    fi
                else
                    echo "40" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile not found, creating and uploading new keyfile" 8 50 0
                    if /usr/bin/expect > /dev/null 2>&1 << EOF
                    spawn sftp -oStrictHostKeyChecking=no -oPort=${array[7]} ${array[0]}@${array[2]}
                    expect "password:"
                    send "${array[1]}\r"
                    expect "sftp>"
                    send "mkdir .ssh\r"
                    expect "sftp>"
                    send "cd .ssh\r"
                    expect "sftp>"
                    send "put .ssh/id_${array[5]}.${array[6]}.pub authorized_keys\r"
                    expect "sftp>"
                    send "quit\r"
EOF
                    then
                        echo "45" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nUploaded keyfile to backupserver" 8 50 0
                        rm -f authorized_keys > /dev/null 2>&1
                        logger -t superbackup_installer "Uploaded keyfile back to backupserver"
                    else
                        dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not upload keyfile back to backupserver\n\nWill now exit" 9 50
                        logger -t superbackup_installer "Could not upload keyfile to backupserver"
                        exit
                    fi
                fi              
            fi 
        fi
        # Download the backupscript
        echo "50" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloading backupscript" 8 50 0
        if curl -s -o /usr/local/bin/superbackup https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh > /dev/null 2> /dev/null;
        then
            echo "60" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownload of the backupscript succeeded" 8 50 0
            logger -t superbackup_installer "Succesfully downloaded the backupscript"
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nDownload of the script failed!\nPlease check your network settings" 9 50
            logger -t superbackup_installer "Failed to download the backupscript, please check your network setup"
            clear
            exit
        fi
        # Setting permissions
        echo "70" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting permissions on script" 8 50 0
        if chmod +x /usr/local/bin/superbackup > /dev/null 2>&1
        then
            echo "75" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting permissions on script with success" 8 50 0
            logger -t superbackup_installer "Setting permissions on the backupscript with success"
        else
            echo "75" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCould not set permissions" 8 50 0
            logger -t superbackup_installer "Could not set permissions on backupscript"
        fi
        # Download the exclude list
        echo "77" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloading exclude list" 8 50 0
        if curl -s -o /etc/superbackup/excludes.rsync https://raw.githubusercontent.com/langerak/superbackup/master/excludes.rsync > /dev/null 2>&1
        then
            echo "79" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownload of the exclude list succeeded" 8 50 0
            logger -t superbackup_installer "Succesfully downloaded the exclude list"
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThere was an error downloading the exclude list.\n\nThe installer will now exit!" 10 50
            logger -t superbackup_installer "Failed to download the exclude list, please check your network setup"
            $0 --uninstall > /dev/null 2>&1
            clear
            exit
        fi
        # Setup cronjob
        if [[ "${array[21]}" == "Y" ]];
        then
            if cat <(crontab -l) <(echo "${array[15]} ${array[14]} * * * /usr/local/bin/superbackup 2>&1 | mail -s '[BACKUP] Backupreport of `hostname`' ${array[20]}") | crontab -
            then
                echo "90" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSuccessfully set up the cronjob" 8 50
                logger -t superbackup_installer "Installed cronjob at ${array[14]}:${array[15]}"
            else
                dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThere was an error setting up the cronjob.\n\nThe installer will now exit!" 10 50
                logger -t superbackup_installer "There was an error installing the cronjob, exiting..."
                $0 --uninstall > /dev/null 2>&1
                clear
                exit
            fi
        else
            if cat <(crontab -l) <(echo "${array[15]} ${array[14]} * * * /usr/local/bin/superbackup > /dev/null 2>&1") | crontab -
            then
                echo "90" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSuccessfully set up the cronjob" 8 50
                logger -t superbackup_installer "Installed cronjob at ${array[14]}:${array[15]}"
            else
                dialog --backtitle "$backtitle" --title "$title" --msgbox "\nThere was an error setting up the cronjob.\n\nThe installer will now exit!" 10 50
                logger -t superbackup_installer "There was an error installing the cronjob, exiting..."
                $0 --uninstall > /dev/null 2>&1
                clear
                exit
            fi
        fi
        # Ending dialogue
        echo "100" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nInstallation finished!" 8 50; sleep 1
        dialog --backtitle "$backtitle" --title "$title" --yesno "\nDo you want to have a short installation report emailed to the following address:\n\n${array[20]}?" 10 60
        sendreport=$?
        if [ $sendreport = 0 ];
        then
            backupadvancedinstallationreport
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nInstallation report has been sent to the following address:\n\n${array[20]}." 9 60
			logger -t superbackup_installer "Mailed installation report to ${array[20]}"
        fi
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCongratulations!\n\nThe backupscript is now installed on this machine!" 9 50
			logger -t superbackup_installer "Succesfully installed the backupscript!"
        clear
	;;
	1)
		clear
	;;
	esac
logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
3)
	logger -t superbackup_installer "Started the configuration editor"
	if ! [[ -f /etc/superbackup/backup.conf ]];
	then
		dialog --backtitle "$backtitle_config" --title "$title" --msgbox "\nNo configfile found!\n\nPlease install the script first." 9 50
		clear
		exit
	fi
	clear
	# Include configfile:
    source /etc/superbackup/backup.conf
	# Checking for controlpanel and configuring MySQL dump support:
	if [ -d /usr/local/directadmin ];
	then
        if [[ $MYSQLBACKUP == "Y" ]];
        then
            if [ -z $MYSQLUSER ];
            then
                source /usr/local/directadmin/conf/mysql.conf
                MYSQLUSER=$user
                MYSQLPASS=$passwd
            fi
        fi
    	source /usr/local/directadmin/conf/mysql.conf
	elif [ -d /usr/local/cpanel ];
	then
        if [[ $MYSQLBACKUP == "Y" ]];
        then
            if [ -z $MYSQLUSER ];
            then
                MYSQLUSER="root"
                MYSQLPASS=""
            fi
        fi
	elif [ -d /usr/local/psa ];
	then
        if [[ $MYSQLBACKUP == "Y" ]];
        then
            if [ -z $MYSQLUSER ];
            then
                MYSQLUSER="admin"
                MYSQLPASS=$(cat /etc/psa/.psa.shadow)
            fi
        fi
	elif [ -f /usr/local/ispconfig/server/lib/mysql_clientdb.conf ];
	then
		if [[ $MYSQLBACKUP == "Y" ]];
		then
			if [ -z $MYSQLUSER ];
			then
    			MYSQLUSER=$(grep user < /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk '{print $3'} | sed "s/[';]//g")
    			MYSQLPASS=$(grep password < /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk '{print $3'} | sed "s/[';]//g")
			fi
		fi
	elif [ -f /etc/mysql/debian.cnf ];
	then
		if [[ $MYSQLBACKUP == "Y" ]];
		then
			if [ -z $MYSQLUSER ];
			then
	        	MYSQLUSER=$(grep ^user < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')
    			MYSQLPASS=$(grep ^password < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')
			fi
		fi
	fi
    dialog --column-separator "|" --backtitle "$backtitle_config" --title "$title" --colors --form "\nBelow are the current configuration options.\nYou can adjust the settings to your needs and when you're done, select \"OK\"." 26 65 0 \
    "Backup username....:" 1 1 "$BUSER" 1 22 14 0 \
    "Backup server......:" 2 1 "$BSERVER" 2 22 30 0 \
    "Backup root path...:" 3 1 "$BACKUPROOT" 3 22 30 0 \
    "Backup remote path.:" 4 1 "$REMOTEPATH" 4 22 30 0 \
    "SSH Port...........:" 5 1 "$SSHPORT" 5 22 5 0 \
    "Weekly retention...:    $currentsize"GB" extra needed per week" 6 1 "$WEKEN" 6 22 2 0 \
    "Monthly retention..:    $currentsize"GB" extra needed per month" 7 1 "$MAANDEN" 7 22 2 0 \
    "MySQL dumps........:" 8 1 "$MYSQLBACKUP" 8 22 1 0 \
    "MySQL username.....:" 9 1 "$MYSQLUSER" 9 22 20 0 \
    "MySQL password.....:" 10 1 "$MYSQLPASS" 10 22 20 0 \
    "MySQL dump folder..:" 11 1 "$MYSQLBACKUPDIR" 11 22 35 0 \
    "Notifications......:" 12 1 "$NOTIFICATIONS" 12 22 1 0 \
    "Verbose logging....:" 13 1 "$LOGGING" 13 22 1 0 \
    "Xfer speed (in KBs):" 14 1 "$XFERSPEED" 14 22 5 0 \
    "Automatic updates..:" 15 1 "$AUTOUPDATE" 15 22 1 0 \
    "Alert emailaddress.: Can be changed via Mail Recipients" 16 1 "" 16 22 0 1 2> /tmp/$pid-options
    escaper
    choice=$?
    array=( `cat /tmp/$pid-options `)
    if [ -f /tmp/$pid-options ];
    then
        rm -f /tmp/$pid-options > /dev/null 2> /dev/null
    fi
    while ! [ ${#array[@]} = 16 -o ${#array[@]} = 17 -o ${#array[@]} = 15 -o ${#array[@]} = 14 ]
    do
	logger -t superbackup_installer "Not all of the required fields are populated, returning to installation form"
    	dialog --backtitle "$backtitle" --title "$title" --msgbox "\nNot all fields are populated!\n\nPlease make sure you fill in all the fields." 10 50; clear
    	dialog --column-separator "|" --backtitle "$backtitle_config" --title "$title" --colors --form "\nBelow are the current configuration options.\nYou can adjust the settings to your needs and when you're done, select \"OK\"." 25 60 0 \
    	"Backup username....:" 1 1 "${array[0]}" 1 22 14 0 \
    	"Backup server......:" 2 1 "${array[1]}" 2 22 30 0 \
    	"Backup root path...:" 3 1 "${array[2]}" 3 22 30 0 \
    	"Backup remote path.:" 4 1 "${array[3]}" 4 22 30 0 \
    	"SSH Port...........:" 5 1 "${array[4]}" 5 22 5 0 \
    	"Weekly retention...:    $currentsizeused"GB" extra needed per week" 6 1 "${array[5]}" 6 22 2 0 \
    	"Monthly retention..:    $currentsizeused"GB" extra needed per month" 7 1 "${array[6]}" 7 22 2 0 \
    	"MySQL dumps........:" 8 1 "${array[7]}" 8 22 1 0 \
    	"MySQL username.....:" 9 1 "${array[8]}" 9 22 20 0 \
    	"MySQL password.....:" 10 1 "${array[9]}" 10 22 20 0 \
    	"MySQL dump folder..:" 11 1 "${array[10]}" 11 22 35 0 \
    	"Notifications......:" 12 1 "${array[11]}" 12 22 1 0 \
    	"Verbose logging....:" 13 1 "${array[12]}" 13 22 1 0 \
    	"Xfer speed (in KBs):" 14 1 "${array[13]}" 14 22 5 0 \
    	"Automatic updates..:" 15 1 "${array[14]}" 15 22 1 0 \
    	"Alert emailaddress.: Can be changed via Mail Recipients" 16 1 "" 16 22 0 1 2> /tmp/$pid-options
    	escaper
        choice=$?
    	array=( `cat /tmp/$pid-options `)
    	if [ -f /tmp/$pid-options ];
    	then
        	rm -f /tmp/$pid-options > /dev/null 2> /dev/null
    	fi
    done
	case $choice in
	0)
		# Removing lock from file and change config values:
		if [ -f /etc/superbackup/backup.conf ];
		then
			chattr -i /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/BUSER=$BUSER/BUSER=${array[0]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/BSERVER=$BSERVER/BSERVER=${array[1]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/BACKUPROOT=$BACKUPROOT/BACKUPROOT=${array[2]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/REMOTEPATH=$REMOTEPATH/REMOTEPATH=${array[3]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/SSHPORT=$SSHPORT/SSHPORT=${array[4]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/WEKEN=$WEKEN/WEKEN=${array[5]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/MAANDEN=$MAANDEN/MAANDEN=${array[6]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/MYSQLBACKUP=$MYSQLBACKUP/MYSQLBACKUP=${array[7]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/MYSQLUSER=$MYSQLUSER/MYSQLUSER=${array[8]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/MYSQLPASS=$MYSQLPASS/MYSQLPASS=${array[9]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/MYSQLBACKUPDIR=$MYSQLBACKUPDIR/MYSQLBACKUPDIR=${array[10]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/XFERSPEED=$XFERSPEED/XFERSPEED=${array[13]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/LOGGING=$LOGGING/LOGGING=${array[12]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/NOTIFICATIONS=$NOTIFICATIONS/NOTIFICATIONS=${array[11]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
			perl -pi -w -e "s/AUTOUPDATE=$AUTOUPDATE/AUTOUPDATE=${array[14]}/" /etc/superbackup/backup.conf > /dev/null 2>&1
            # Place the lock back on the file
            chattr +i /etc/superbackup/backup.conf
		fi
		dialog --backtitle "$backtitle_config" --title "$title" --msgbox "\nYour configuration settings are now saved." 7 50
		logger -t superbackup_installer "Saved configuration changes"
		clear
		exit
	;;
	esac
;;
4)
	logger -t superbackup_installer "Started the backup uninstaller procedure"
	clear
	dialog --backtitle "$backtitle_uninstall" --title "$title" --yesno "\nThis wil remove the backupscript including all configuration files and cronjob from your server.\n\nDo you agree?" 10 60
	agree=$?
	case $agree in
	0)
		echo "15" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving cronjob" 8 60
		crontab -u root -l > /tmp/cron.txt
    	if grep superbackup /tmp/cron.txt > /dev/null
    	then
        	if sed -i '/superbackup/ d' /tmp/cron.txt; crontab /tmp/cron.txt; rm -f /tmp/cron.txt > /dev/null 2>&1
        	then
    			echo "30" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoved cronjob" 8 60
    			logger -t superbackup_installer "Removed the backup cronjob"
    		else
    			echo "30" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nCould not remove cronjob (remove manually)" 8 60
    			logger -t superbackup_installer "Could not remove cronjob, remove manually via \"crontab -e\""
    		fi
    	fi
		echo "45" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving configfiles: Removing" 8 50
		if chattr -i /etc/superbackup/backup.conf; rm -rf /etc/superbackup/ > /dev/null 2>&1
		then
			echo "60" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving configfiles: Done" 8 50; sleep 1
			logger -t superbackup_installer "Purged configfiles"
		else
			echo "60" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving configfiles: Failed" 8 50; sleep 1
			logger -t superbackup_installer "Could not purge configfiles"
		fi
        echo "75" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving logfiles: Removing" 8 50
        if rm -rf /var/log/superbackup/ > /dev/null 2>&1
        then
            echo "90" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving logfiles: Done" 8 50; sleep 1
        	logger -t superbackup_installer "Purged logfiles"
        else
            echo "90" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving logfiles: Failed" 8 50; sleep 1
        	logger -t superbackup_installer "Could not purge logfiles"
        fi
        echo "95" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving backupscript: Removing" 8 50
        if rm -rf /usr/local/bin/superbackup > /dev/null 2>&1
        then
            echo "100" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving backupscript: Done" 8 50; sleep 1
        	logger -t superbackup_installer "Removed the backupscript"
        else
            echo "100" | dialog --backtitle "$backtitle_uninstall" --title "$title" --gauge "\nRemoving backupscript: Failed" 8 50; sleep 1
        	logger -t superbackup_installer "Could not remove the backupscript"
        fi
		dialog --backtitle "$backtitle_uninstall" --title "$title" --msgbox "\nThe backupscript with it's files is now removed.\n\nPlease do not forget to remove the cronjob with the following command:\n\"crontab -e\"" 11 60
		logger -t superbackup_installer "Backupscript uninstalled, please remove the cronjob manually via \"crontab -e\""
		clear
	;;
	1)
		logger -t superbackup_installer "User aborted the uninstall procedure"
		clear
	;;
	esac
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
5)
	logger -t superbackup_installer "Started the upgrade procedure"
    genday
    while [ $genday = 0 ];
    do
            genday
    done	
	if ! [[ -f /etc/superbackup/backup.conf ]];
	then
		dialog --backtitle "$backtitle_upgrade" --title "$title" --msgbox "\nYou do not have the backupscript installed yet.\n\nPlease start the installer." 10 60
		logger -t superbackup_installer "Upgrade stalled, the script is not installed"
		clear
		exit
	fi
        dialog --backtitle "$backtitle_upgrade" --title "$title" --yesno "\nDo you want to check for updates?" 7 50
        search=$?
	case $search in
	0)
    	# Get current installed version:
        if [ -f /etc/superbackup/backup.conf ];
        then
            version=$(cat /etc/superbackup/backup.conf | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g')
            versionstripped=$(echo $version | sed 's/\.//g')
        fi
    	# Get remote version:
    	newversion=$(curl -s https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh | grep "VERSION=" | cut -d = -f 2 | sed 's/"//g' | head -1)
    	newversionstripped=$(echo $newversion | sed 's/\.//g')
    	if [[ $versionstripped -eq $newversionstripped || $versionstripped -gt $newversionstripped ]];
    	then
    		dialog --backtitle "$backtitle_upgrade" --title "$title" --msgbox "\nThe installed version $version is up-to-date.\n\nWill now exit." 9 60
    		logger -t superbackup_installer "Upgrade not needed, is already up-to-date with version $version"
    		clear
    		exit
    	elif [[ $versionstripped < $newversionstripped ]];
    	then
    		dialog --backtitle "$backtitle_upgrade" --title "$title" --yesno "\nThere is an update available!\n\nYou have version $version installed and available is version $newversion.\n\nDo you want to upgrade?" 12 60
    		agree=$?
    		case $agree in
    		0)
    			logger -t superbackup_installer "Starting upgrade from version $version to version $newversion"
            	echo "20" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloading new backupscript" 8 60
            	if curl -f -s -o /usr/local/bin/superbackup https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-script.sh
            	then
                	echo "40" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloaded new backupscript" 8 60
                	logger -t superbackup_installer "Downloaded new backupscript"
            	else
                	dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not download new backupscript!\n\nPlease check your network settings.\n\nInstallation halted." 11 60
                	logger -t superbackup_installer "Failed downloading new backupscript"
                    clear
                	exit
            	fi
            	echo "60" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting executive permission on backupscript" 8 60
            	if chmod +x /usr/local/bin/superbackup > /dev/null 2>&1
            	then
                	echo "80" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSet executive permission on backupscript" 8 60
                	logger -t superbackup_installer "Set executive permission on new backupscript"
            	else
                	echo "80" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCould not set permissions on backupscript" 8 60
                	logger -t superbackup_installer "Could not set executive permission on new backupscript"
            	fi
                echo "90" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSetting new version in config" 8 60
                if chattr -i /etc/superbackup/backup.conf > /dev/null 2>&1; perl -pi -w -e "s/VERSION=\"$version\"/VERSION=\"$newversion\"/" /etc/superbackup/backup.conf > /dev/null 2>&1; chattr +i /etc/superbackup/backup.conf
                then
                    echo "100" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nSet new version in config" 8 60
                    logger -t superbackup_installer "Set new version in config"
                else
                    echo "100" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCould not set new version in config" 8 60
                    logger -t superbackup_installer "Could not set new version in config"
                fi
                dialog --backtitle "$backtitle_upgrade" --title "$title" --msgbox "\nUpgrade from version $version to version $newversion was successful!" 8 60
				logger -t superbackup_installer "Upgrade from version $version version $newversion was successful"
				clear
				exit
    		;;
    		1)
    			clear
    			logger -t superbackup_installer "Upgrade aborted by user"
    			exit
    		;;
    		esac
    	fi
	;;
	1)
		clear
		logger -t superbackup_installer "Upgrade aborted by user"
		exit
	;;
	esac
;;
6)
	logger -t superbackup_installer "Started the testing suite"
    clear
    dialog --backtitle "$backtitle_test" --title "$title" --yesno "\nDo you want to run the test suite, testing the backup options given?" 8 60
    agree=$?
    case $agree in
    0)
    	source /etc/superbackup/backup.conf
    	if ssh -oStrictHostKeyChecking=no -p $SSHPORT -i $PRIVKEY $BUSER@$BSERVER "df -hT --block-size=G $REMOTEPATH | tail -n1" > /tmp/backup_quota 2>&1
    	then
    		sshcheck="OK"
    		logger -t superbackup_installer "SSH is OK"
    	elif [ $ssh = 127 ];
    	then
    		sshcheck="OK, but no quota available"
    		logger -t superbackup_installer "SSH is OK, but no quota is available"
    	else
    		sshcheck="Not OK"
    		logger -t superbackup_installer "SSH is not OK, please check the network settings"
    	fi
        # Calculate quota
		currentsize=$(df -hT --exclude-type="tmpfs" --exclude-type="devtmpfs" --block-size=G | grep "/" | awk '{print $4}' | tr -d G | head -1)
		accsize=$(cat /tmp/backup_quota | awk '{print $3}' | cut -d G -f 1)
		accinuse=$(cat /tmp/backup_quota | awk '{print $4}' | cut -d G -f 1)
		accinusepercent=$(cat /tmp/backup_quota | awk '{print $6}' | cut -d % -f 1)
		accfree=$(cat /tmp/backup_quota | awk '{print $5}' | cut -d G -f 1)
		# Calculate space needed by retention and see if it fits:
		basespace=$(echo $currentsize*2 | bc)
		extraspace=$(echo $WEKEN*$currentsize+$MAANDEN*$currentsize | bc)
		totalspace=$(echo $basespace+$extraspace | bc)
		if [ $totalspace -gt $accfree ];
		then
			spacecheck="Not OK (Need $totalspace"GB", have $accfree"GB" available)"
			logger -t superbackup_installer "Backupspace is not OK, have $accsize"GB", but need $totalspace"GB""
		else
			spacecheck="OK (Need $totalspace"GB", $accsize"GB" total / $accfree"GB" free)"
			logger -t superbackup_installer "Backupspace is OK, have $accsize"GB" and need $totalspace"GB""
		fi
		if [ $MYSQLBACKUP = "Y" ];
		then
			if [ -d /usr/local/cpanel/ ];
			then
				if echo exit | mysql -u $MYSQLUSER > /dev/null 2>&1
				then
					mysqlcheck="OK"
					logger -t superbackup_installer "MySQL connection was successful"
				else
					mysqlcheck="Not OK"
					logger -t superbackup_installer "MySQL connection was unsuccessful"
				fi
			else
				if echo exit | mysql -u $MYSQLUSER -p$MYSQLPASS > /dev/null 2>&1
                then
                    mysqlcheck="OK"
					logger -t superbackup_installer "MySQL connection was successful"
                else
                    mysqlcheck="Not OK"
					logger -t superbackup_installer "MySQL connection was unsuccessful"
                fi
			fi
		else
			mysqlcheck="Not enabled"
			logger -t superbackup_installer "MySQL dumps are disabled and cannot be tested"
		fi
		# Create report:
		dialog --backtitle "$backtitle_test" --title "$title" --msgbox "\nBelow are the test results:\n\nSSH............: $sshcheck\nQuota fits.....: $spacecheck\nMySQL..........: $mysqlcheck" 12 70
		logger -t superbackup_installer "Used testsuite: SSH = $sshcheck. Spacecheck = $spacecheck. MySQL = $mysqlcheck."
		clear
	;;
	1)
		clear
	;;
	esac
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
7)
	logger -t superbackup_installer "Started the quota calculator"
	clear
	# Get current space and round it:
	currentsize=$(df -hT --exclude-type="tmpfs" --exclude-type="devtmpfs" --block-size=G | grep "/" | awk '{print $4}' | tr -d G | head -1)
	dialog --backtitle "$backtitle_quotacalc" --title "$title" --msgbox "\nWith this tool you can calculate the amount of space needed for your backups based on the given retention.\nIf the configfile already exists, it will use these settings and else you may enter it yourself.\n\nPlease note that the given quota is a recommendation." 12 60
	if [ -f /etc/superbackup/backup.conf ];
	then
		source /etc/superbackup/backup.conf
        dialog --backtitle "$backtitle_quotacalc" --title "$title" --form "\nBelow are the current configuration options:" 11 60 0 \
        "Weeks.......:" 1 1 "$WEKEN" 1 15 2 0 \
    	"Months......:" 2 1 "$MAANDEN" 2 15 2 0 2> /tmp/$pid-options
        escaper
        choice=$?
        array=( `cat /tmp/$pid-options `)
        if [ -f /tmp/$pid-options ];
        then
                rm -f /tmp/$pid-options > /dev/null 2> /dev/null
        fi
        while [ ${#array[@]} -lt 2 ]
        do
            dialog --backtitle "$backtitle_quotacalc" --title "$title" --msgbox "\nNot all fields are populated, please check your input!" 7 60
            dialog --backtitle "$backtitle_quotacalc" --title "$title" --form "\nBelow are the current configuration options." 8 60 0 \
            "Weeks.......:" 1 1 "${array[0]}" 1 15 2 0 \
            "Months......:" 2 1 "${array[1]}" 2 15 2 0 2> /tmp/$pid-options
            escaper
            choice=$?
            array=( `cat /tmp/$pid-options `)
            if [ -f /tmp/$pid-options ];
            then
                    rm -f /tmp/$pid-options > /dev/null 2> /dev/null
            fi
        done
    	case $choice in
    	0)
            if ! [ ${array[0]} = 0 ];
            then
                    weekly=$(echo ${array[0]}*$currentsize | bc)
            else
                    weekly=0
            fi
            if ! [ ${array[1]} = 0 ];
            then
                    monthly=$(echo ${array[1]}*$currentsize | bc)
            else
                    monthly=0
            fi
			totals=$(echo 2*$currentsize+$weekly+$monthly | bc)
		;;
		1)
			clear
		;;
		esac
		echo "$log Quota lookup: ${array[0]} weekly + ${array[1]} monthly backups needs $totals Gb of backupspace" >> /var/log/backups/backup.log
		logger -t superbackup_installer "${array[0]} weekly + ${array[1]} monthly backups needs a total space of $totals GB on the backupserver"
	else
        dialog --backtitle "$backtitle_quotacalc" --title "$title" --form "\nBelow are the current configuration options." 8 60 0 \
        "Weeks.......:" 1 1 "" 1 15 2 0 \
        "Months......:" 2 1 "" 2 15 2 0 2> /tmp/$pid-options
        escaper
        choice=$?
        array=( `cat /tmp/$pid-options `)
        if [ -f /tmp/$pid-options ];
        then
                rm -f /tmp/$pid-options > /dev/null 2> /dev/null
        fi
		while [ ${#array[@]} -lt 2 ]
		do
			dialog --backtitle "$backtitle_quotacalc" --title "$title" --msgbox "\nNot all fields are populated, please check your input!" 7 60
        	dialog --backtitle "$backtitle_quotacalc" --title "$title" --form "\nBelow are the current configuration options." 8 60 0 \
        	"Weeks.......:" 1 1 "${array[0]}" 1 15 2 0 \
        	"Months......:" 2 1 "${array[1]}" 2 15 2 0 2> /tmp/$pid-options
        	escaper
        	choice=$?
        	array=( `cat /tmp/$pid-options `)
        	if [ -f /tmp/$pid-options ];
        	then
            	rm -f /tmp/$pid-options > /dev/null 2> /dev/null
        	fi
		done
        case $choice in
        0)
            if ! [ ${array[0]} = 0 ];
            then
                weekly=$(echo ${array[0]}*$currentsize | bc)
            else
                weekly=0
            fi
            if ! [ ${array[1]} = 0 ];
            then
                monthly=$(echo ${array[1]}*$currentsize | bc)
            else
                monthly=0
            fi
            totals=$(echo 2*$currentsize+$weekly+$monthly | bc)
        ;;
        1)
            clear
        ;;
        esac
		echo "$log Quota lookup: ${array[0]} weekly + ${array[1]} monthly backups needs $totals Gb of backupspace" >> /var/log/backups/backup.log
		logger -t superbackup_installer "${array[0]} weekly + ${array[1]} monthly backups needs a total space of $totals GB on the backupserver"
	fi
	dialog --backtitle "$backtitle_quotacalc" --title "$title" --msgbox "\nBased on the given retention you need a total of $totals GB of backupspace." 8 60
	clear
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
	exit
;;
8)
	logger -t superbackup_installer "Started the log cleaning procedure"
	space=$(du -sch /var/log/backups/ | grep total | awk '{print $1}')
    dialog --backtitle "$backtitle_clearlogs" --title "$title" --yesno "\nThis will clear all backup logfiles. You will save "$space"B of diskspace.\n\nDo you agree?" 10 60
    agree=$?
    case $agree in
    0)
    	echo "50" | dialog --backtitle "$backtitle_clearlogs" --title "$title" --gauge "\nClearing logs: Clearing" 8 50
    	if rm -rf /var/log/backups/rsync/* > /dev/null 2>&1; rm -rf /var/log/backups/error/* > /dev/null 2>&1; rm -rf /var/log/backups/warn/* > /dev/null 2>&1; rm -rf /var/log/backups/temp/* > /dev/null 2>&1
    	then
    		echo "100" | dialog --backtitle "$backtitle_clearlogs" --title "$title" --gauge "\nClearing logs: Done" 8 50;sleep 1
    		dialog --backtitle "$backtitle_clearlogs" --title "$title" --msgbox "\nAll logs are deleted and "$space"B of space is gained." 7 50
    		logger -t superbackup_installer "All logs ($logfiles items with a space of "$space"B is removed"
    		clear
    	else
    		dialog --backtitle "$backtitle_clearlogs" --title "$title" --msgbox "\nCould not clear logs.\n\nWill now exit." 9 50
    		logger -t superbackup_installer "Could not clear logs"
    		clear
    	fi
	;;
	1)
		clear
	;;
	esac
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
9)
	logger -t superbackup_installer "Started the usage procedure"
	if [ -f /etc/superbackup/backup.conf];
	then
		source /etc/superbackup/backup.conf
	fi
    # Connect to the server and retrieve quota information
    if ssh -oStrictHostKeyChecking=no -p $SSHPORT -i $PRIVKEY $BUSER@$BSERVER "df -hT --block-size=G $REMOTEPATH | tail -n1" > /tmp/backup_quota 2>&1
    then
        # Calculate quota
        currentsize=$(df -hT --exclude-type="tmpfs" --exclude-type="devtmpfs" --block-size=G | grep "/" | awk '{print $4}' | tr -d G | head -1)
        accsize=$(cat /tmp/backup_quota | awk '{print $3}' | cut -d G -f 1)
        accinuse=$(cat /tmp/backup_quota | awk '{print $4}' | cut -d G -f 1)
        accinusepercent=$(cat /tmp/backup_quota | awk '{print $6}' | cut -d % -f 1)
        accfree=$(cat /tmp/backup_quota | awk '{print $5}' | cut -d G -f 1)
        dialog --backtitle "$backtitle_quota" --title "$title" --msgbox "\nBelow are the quota details:\n\nServer....: $BSERVER\nUsername..: $BUSER\nSize......: "$accsize"B\nUsage.....: "$accinuse"B ($accinusepercent)\nFree......: "$accfree"B" 13 50
        logger -t superbackup_installer "Quota lookup: $accinuse GB of $accsize GB"
    else
        dialog --backtitle "$backtitle_quota" --title "$title" --msgbox "\nCould not connect to $BSERVER.\n\nWill now exit." 10 60
        logger -t superbackup_installer "Quota lookup: SSH is not OK, please check the network settings"
    fi
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
10)
	logger -t superbackup_installer "Started the recovery procedure"
	dialog --backtitle "$backtitle_restore" --title "$title" --yesno "\nThis will download and run the SuperBackup restore script.\n\nDo you want to continue?" 10 60
	agree=$?
	case $agree in
	0)
    	echo "50" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownloading restore script" 8 50 0
        if curl -f -s -o /root/superbackup-restore.sh https://raw.githubusercontent.com/langerak/superbackup/master/superbackup-restore.sh > /dev/null 2>&1; chmod +x /root/superbackup-restore.sh > /dev/null 2>&1
        then
            echo "100" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nDownload of the restore script succeeded" 8 50 0
    		logger -t superbackup_installer "Succesfully downloaded the restorescript"
        else
            dialog --backtitle "$backtitle" --title "$title" --msgbox "\nDownload of the script failed!\nPlease check your network settings" 9 60
    		logger -t superbackup_installer "Failed to download the restorescript, please check your network setup"
            clear
        fi
		clear
		/root/superbackup-restore.sh
		logger -t superbackup_installer "Finished using the recovery script"
	;;
	1)
		dialog --backtitle "$backtitle_restore" --title "$title" --msgbox "\nYou did not agree, will now exit" 8 50
		logger -t superbackup_installer "User aborted the recovery procedure"
		clear
	;;
	esac
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
11)
	logger -t superbackup_installer "Started the manual backup procedure"
	dialog --backtitle "$backtitle_runbackup" --title "$title" --yesno "\nDo you want to run the backupscript now?\n\nAfter the script is finished, it will exit." 9 60
	agree=$?
	case $agree in
	0)
		clear
		logger -t superbackup_installer "Started manual run of the backupscript"
		/usr/local/bin/superbackup
		logger -t superbackup_installer "Finished manual run of the backupscript"
	;;
	1)
		clear
		exit
	;;
	esac
	logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
;;
12)
    clear
	logger -t superbackup_installer "Started the keyfile exchange procedure"
    if ! [ -f /etc/superbackup/backup.conf ];
    then
        dialog --backtitle "$backtitle_exchangekey" --title "$title" --msgbox "\nNo configfile found, the test suite cannot be started.\n\nPlease install the backupscript first." 9 50
        clear
        exit
    fi
    dialog --backtitle "$backtitle_exchangekey" --title "$title" --msgbox "\nVia this tool it is possible to exchange the SSH key with the backupserver in case this has been lost.\n\nYou will only need the password associated with your backupaccount" 11 60
    dialog --backtitle "$backtitle_exchangekey" --title "$title" --insecure --passwordbox "\nPlease enter your password (masked):" 9 50 2> /tmp/$pid-password
    escaper
    password=$(cat /tmp/$pid-password; rm -f /tmp/$pid-password > /dev/null 2>&1)
    while [ -z $password ];
    do
        dialog --backtitle "$backtitle_exchangekey" --title "$title" --insecure --password "\nPlease enter your password (masked):" 9 50 2> /tmp/$pid-password
		logger -t superbackup_installer "Did not entered a password, showing password dialog again"
        escaper
        password=$(cat /tmp/$pid-password; rm /tmp/$pid-password > /dev/null 2>&1)
    done
    dialog --backtitle "$backtitle_exchangekey" --title "$title" --yesno "\nDo you want to exchange the publickey with the backupserver?" 8 60
    exchange=$?
    case $exchange in
    0)
    	source /etc/superbackup/backup.conf
        getkeyinformation
        if [ -f /etc/redhat-release ]
        then
            centosvers=$(grep -Eo "[0-9]\.[0-9]" /etc/redhat-release | cut -d . -f 1)
            if [[ $centosvers == 5 ]]
            then
                keytype="rsa"
            fi
        fi
        # Create SSH key / Reuse key
        if [ -d /root/.ssh/ ]
        then 
            if [ -f "$PRIVKEY" ];
            then
                echo "30" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKeyfile found, not generating a new one" 8 50 0
                logger -t superbackup_installer "Keyfile exists, reusing"
            else
                echo "30" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nGenerating new key" 8 50 0
                if ssh-keygen -t $keytype -N '' -f /root/.ssh/id_"$keytype"."$keyname" > /dev/null 2>&1
                then
                    echo "30" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey successfully generated" 8 50 0
                    logger -t superbackup_installer "Generated keyfile $PRIVKEY"
                else
                    dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the key!\n\nWill now exit!" 9 50
                    logger -t superbackup_installer "Could not create keyfile $PRIVKEY"
                    clear
                    exit
                fi
            fi
        else
            echo "60" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreating .ssh folder in /root/" 8 50 0
            if mkdir -p /root/.ssh > /dev/null 2>&1
            then
                echo "60" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nCreated .ssh folder in /root/" 8 50 0; sleep 1
                logger -t superbackup_installer "Created .ssh folder"
                echo "70" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nGenerating new SSH-key" 8 50 0
                if ssh-keygen -t $keytype -N '' -f /root/.ssh/id_"$keytype"."$keyname" > /dev/null 2>&1
                then
                    echo "75" | dialog --backtitle "$backtitle" --title "$title" --gauge "\nKey successfully generated" 8 50 0
                    logger -t superbackup_installer "Generated keyfile $PRIVKEY"
                else
                    dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create the key!\n\nWill now exit!" 9 50
                    logger -t superbackup_installer "Could not create keyfile $PRIVKEY"
                    clear
                    exit
                fi
            else
                dialog --backtitle "$backtitle" --title "$title" --msgbox "\nCould not create .ssh folder!\n\nWill now exit!" 9 50
                logger -t superbackup_installer "Could not create .ssh folder"
                clear
                exit
            fi
        fi
        # Download / Add / Reupload key
        echo "80" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nChecking for keyfile on the backupserver" 8 50 0
        if /usr/bin/expect > /dev/null 2> /dev/null << EOF
        spawn sftp -oStrictHostKeyChecking=no -oPort=$SSHPORT $BUSER@$BUSER
        expect "password:"
        send "$password\r"
        expect "sftp>"
        send "get .ssh/authorized_keys .\r"
        expect "sftp>"
        send "quit\r"
EOF
        then
            if [ -f authorized_keys ]
            then
                echo "90" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nKeyfile found, adding key to keyfile" 8 50 0
                logger -t superbackup_installer "Keyfile on remote server exists"
                if cat "$PRIVKEY".pub >> authorized_keys
                then
                    echo "93" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nKey added to keyfile" 8 50 0; sleep 1
                    logger -t superbackup_installer "Local key added to keyfile"
                    echo "97" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nUploading keyfile to backupserver" 8 50 0
                    if /usr/bin/expect > /dev/null 2>&1 << EOF
                    spawn sftp -oStrictHostKeyChecking=no -oPort=$SSHPORT $BUSER@$BSERVER
                    expect "password:"
                    send "$password\r"
                    expect "sftp>"
                    send "put authorized_keys .ssh/authorized_keys\r"
                    expect "sftp>"
                    send "quit\r"
EOF
                    then
                        echo "99" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nUploaded keyfile to backupserver" 8 50 0; sleep 1
                        rm -f authorized_keys > /dev/null 2>&1
                        logger -t superbackup_installer "Uploaded keyfile back to backupserver"
                    else
                        dialog --backtitle "$backtitle_exchangekey" --title "$title" --msgbox "\nCould not exchange keyfile with $BSERVER for account $BUSER.\n\nWill now exit!" 8 60
                        logger -t superbackup_installer "Could not upload keyfile back to backupserver"
                        exit
                    fi
                else
                    echo "95" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nKeyfile not found, creating and uploading new keyfile" 8 50 0
                    if /usr/bin/expect > /dev/null 2>&1 << EOF
                    spawn sftp -oStrictHostKeyChecking=no -oPort=$SSHPORT $BUSER@$BSERVER
                    expect "password:"
                    send "${array[1]}\r"
                    expect "sftp>"
                    send "mkdir .ssh\r"
                    expect "sftp>"
                    send "cd .ssh\r"
                    expect "sftp>"
                    send "put .ssh/id_$keytype.$keyname.pub authorized_keys\r"
                    expect "sftp>"
                    send "quit\r"
EOF
                    then
                        echo "99" | dialog --backtitle "$backtitle_exchangekey" --title "$title" --gauge "\nUploaded keyfile to backupserver" 8 50 0; sleep 1
                        rm -f authorized_keys > /dev/null 2>&1
                        logger -t superbackup_installer "Uploaded keyfile back to backupserver"
                    else
                        dialog --backtitle "$backtitle_exchangekey" --title "$title" --msgbox "\nCould not exchange keyfile with $BSERVER for account $BUSER.\n\nWill now exit!" 8 60
                        logger -t superbackup_installer "Could not upload keyfile back to backupserver"
                        exit
                    fi
                fi
            fi
        fi
    	dialog --backtitle "$backtitle_exchangekey" --title "$title" --msgbox "\nThe SSH public key is now exchanged with $BSERVER for account $BUSER." 8 60
    	logger -t superbackup_installer "Exchanged keyfile for $BUSER on $BSERVER"
    	clear
    ;;
    1)
    	logger -t superbackup_installer "Did not agree to the key exchange, exiting..."
        clear
    ;;
    esac
exit
;;
13)
	if [ ! -f /etc/superbackup/recipients.mail ];
	then
		touch /etc/superbackup/recipients.mail
	fi
	dialog --backtitle "$backtitle_mail" --title "$title" --msgbox "\nVia this tool you can add or remove mail recipients which will receive the notifications that the script sends out in case of updates, warnings and errors." 9 60
	dialog --backtitle "$backtitle_mail" --title "$title" --yes-label " View list " --no-label " Edit list " --yesno "\nWhat action do you wish to take?\n\nView list = Show the current recipient list\nEdit list = Opens the nano editor and you can add or remove recipients\n" 11 60
	if [[ $? == 0 ]];
	then
		dialog --backtitle "$backtitle" --title "$title"  --textbox /etc/superbackup/recipients.mail 10 60
		logger -t superbackup_installer "Viewed mail recipients list" 
		clear
	else
		nano=$(which nano)
		$nano /etc/superbackup/recipients.mail
		logger -t superbackup_installer "Edited mail recipients list"
		clear
	fi
;;
14)
    if [ ! -f /etc/superbackup/excludes.rsync ];
    then
        # Download the excludes list for rsync:
        echo -n "Downloading exclude list: "
        if curl -f -s -o /etc/superbackup/excludes.rsync https://raw.githubusercontent.com/langerak/superbackup/master/excludes.rsync > /dev/null 2>&1
        then
            echo -e "OK"
            logger -t superbackup_installer "CLI: Downloaded exclude list"
        else
            echo -e "FAILED!\n\nPlease check your network connections."
            logger -t superbackup_installer "CLI: Could not download exclude list"
            exit
        fi
    fi
    dialog --backtitle "$backtitle_excludes" --title "$title" --msgbox "\nVia this tool you can add or remove rsync excludes. Excludes that are on the list will be ignored by rsync during the backup process" 9 60
    dialog --backtitle "$backtitle_excludes" --title "$title" --yes-label " View list " --no-label " Edit list " --yesno "\nWhat action do you wish to take?\n\nView list = Show the current rsync exclude list\nEdit list = Opens the nano editor and you can add or remove excludes\n" 11 60
    if [[ $? == 0 ]];
    then
        dialog --backtitle "$backtitle_excludes" --title "$title"  --textbox /etc/superbackup/excludes.rsync 10 60
    	logger -t superbackup_installer "Viewed the rsync excludes list"
        clear
    else
        nano=$(which nano)
        $nano /etc/superbackup/excludes.rsync
    	logger -t superbackup_installer "Edited the rsync excludes list"
        clear
    fi
;;
15)
	dialog --backtitle "$backtitle_explorer" --title "$title" --msgbox "\nVia this tool it is possible to browse, recover and delete the content on the backupserver.\n\nPlease note that all actions are permanent when you execute them!" 11 60
	source /etc/superbackup/backup.conf
	if [ -d /mnt/ ];
	then
		if ! mkdir -p /mnt/backup-"$BUSER"
		then
			echo -e "Could not create mountpoint, cannot continue!"
			logger -t superbackup_installer "Could not create mountpoint"
			exit
		fi
	else
		echo -e "No /mnt/ directory available, cannot continue!"
		logger -t superbackup_installer "No /mnt/ dir available"
		exit
	fi
	if sshfs -o ssh_command="ssh -p $SSHPORT -i $PRIVKEY" "$BUSER"@"$BSERVER":"$REMOTEPATH" /mnt/backup-"$BUSER" > /dev/null 2>&1
	then
		logger -t superbackup_installer "Successfully mounted the backup account to /mnt/backup-$BUSER"
	else
		echo -e "Could not mount the backupaccount to /mnt/backup-$BUSER"
		logger -t superbackup_installer "Could not mount the backup account to folder /mnt/backup-$BUSER"
		exit
	fi
	clear
	mc /mnt/backup-"$BUSER"
	clear
	if ! umount /mnt/backup-"$BUSER" > /dev/null 2>&1
	then
		echo -e "Could not unmount backup share, please do so manually:\numount /mnt/backup-$BUSER"
		logger -t superbackup_installer "Could not unmount backup share"
	fi
	exit
;;
esac
logger -t superbackup_installer "Stopped the SuperBackup Installer"
exit
