#! /bin/bash
#
# This script contains the installation checks for the Debian / Ubuntu OS and is
# part of the SuperBackup Suite created by Jeffrey Langerak.
#
# Bugs and/or features can be left at the repository below:
# https://github.com/langerak/superbackup
#
# Starting the depency installation for Debian / Ubuntu:
#
# Setting current Epoch:
cur_epoch=`date +%s`
# Setting epoch in file, this will make sure that we don't update APT everytime we start the script
# We only update APT once there are 2 days passed or after a reboot where /tmp is cleared:
echo -ne "Update APT packagelist: Please wait...     \r"
if ! [ -f /tmp/epoch.apt ];
then
    echo $cur_epoch > /tmp/epoch.apt
    if apt-get update > /dev/null 2>&1
    then
        echo -ne "Update APT packagelist: OK               \r"; echo
        logger -t superbackup_installer "Refreshed APT source tree"
    else
        echo -ne "Update APT packagelist: Failed           \r"; echo
        echo -e "Please check the APT sources manually (apt-get update).\n\nPossible causes are unused and/or dead repositories."
        logger -t superbackup_installer "Failed to refresh APT sources, exiting..."
        exit
    fi
elif [ -f /tmp/epoch.apt ];
then
    old_epoch=$(cat /tmp/epoch.apt)
    epoch=$(echo $cur_epoch - $old_epoch | bc)
    if [[ $epoch -lt 172800 ]];
    then
        echo -ne "Update APT packagelist: Not needed       \r"; echo
        logger -t superbackup_installer "APT update not needed, needs 2 days to have passed"
    else
        echo $cur_epoch > /tmp/epoch.apt
        if apt-get update > /dev/null 2>&1
        then
            echo -ne "Update APT packagelist: OK               \r"; echo
            logger -t superbackup_installer "Refreshed APT source tree"
        else
            echo -ne "Update APT packagelist: Failed           \r"; echo
            echo -e "Please check the APT sources manually (apt-get update).\n\nPossible causes are unused and/or dead repositories."
            logger -t superbackup_installer "Failed to refresh APT sources, exiting..."
            exit
        fi
    fi
fi
echo -ne "Checking for dialog: Please wait...     \r"
if [ -x /usr/bin/dialog ];
then
        echo -ne "Checking for dialog: Present            \r"; echo
logger -t superbackup_installer "Package dialog already installed"
else
    if apt-get -y install dialog > /dev/null 2>&1
    then
        echo -ne "Checking for dialog: Installed       \r"; echo
        logger -t superbackup_installer "Package dialog is now installed"
    else
        echo -ne "Checking for dialog: Failed          \r"; echo
        echo -e "There was an error installing dialog! Installer will now abort!"
        logger -t superbackup_installer "Package dialog not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for curl: Please wait...       \r"
if [ -x /usr/bin/curl ];
then
    echo -ne "Checking for curl: Present               \r"; echo
    logger -t superbackup_installer "Package curl already installed"
else
    if apt-get -y install curl > /dev/null 2>&1
    then
        echo -ne "Checking for curl: Installed         \r"; echo
        logger -t superbackup_installer "Package curl is now installed"
    else
        echo -ne "Checking for curl: Failed            \r"; echo
        echo -e "There was an error installing curl! The installer will now abort!"
        logger -t superbackup_installer "Package curl not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for rsync: Please wait...       \r"
if [ -x /usr/bin/rsync ];
then
    echo -ne "Checking for rsync: Present               \r"; echo
    logger -t superbackup_installer "Package rsync already installed"
else
    if apt-get -y install rsync > /dev/null 2>&1
    then
        echo -ne "Checking for rsync: Installed         \r"; echo
        logger -t superbackup_installer "Package rsync is now installed"
    else
        echo -ne "Checking for rsync: Failed            \r"; echo
        echo -e "There was an error installing rsync! The installer will now abort!"
        logger -t superbackup_installer "Package rsync not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for sendmail: Please wait...       \r"
if ! [ -d /etc/postfix/ ];
then
    if [ -x /usr/sbin/sendmail ];
    then
        echo -ne "Checking for sendmail: Present               \r"; echo
        logger -t superbackup_installer "Package sendmail already installed"
    else
        if apt-get -y install sendmail > /dev/null 2>&1
        then
            echo -ne "Checking for sendmail: Present               \r"; echo
            logger -t superbackup_installer "Package sendmail is now installed"
        else
            clear; echo -ne "Checking for sendmail: Failed         \r"; echo
            echo -ne "There was an error installing sendmail! Installer will not start!"
            logger -t superbackup_installer "Package sendmail not installed due to an error, exiting..."
            exit
        fi
    fi
else
    echo -ne "Checking for sendmail: Failed            \r"; echo
    echo -e "Postfix is currently installed and untested with the backup tools, but will continue..."
fi
echo -ne "Checking for mailx: Please wait...       \r"
if [ -x /usr/bin/mail ];
then
    echo -ne "Checking for mailx: Present               \r"; echo
    logger -t superbackup_installer "Package mailx already installed"
else
    apt-get -y install mailx > /dev/null 2>&1
    retval=$?
    if [ $retval = 0 ];
    then
        echo -ne "Checking for mailx: Installed         \r"; echo
        logger -t superbackup_installer "Package mailx is now installed"
    elif [ $retval = 100 ];
    then
        echo -ne "Checking for mailx: Not available, trying heirloom-mailx \r"; echo
        logger -t superbackup_installer "Package mailx not available, trying heirloom-mailx"
        echo -ne "Checking for heirloom-mailx: Please wait...       \r"
        if apt-get -y install heirloom-mailx > /dev/null 2>&1
        then
            echo -ne "Checking for heirloom-mailx: Installed         \r"; echo
            logger -t superbackup_installer "Package heirloom-mailx is now installed"
        else
            echo -ne "Checking for heirloom-mailx: Failed         \r"; echo
            logger -t superbackup_installer "Package heirloom-mailx not installed due to errors, exiting..."
        fi
    else
        echo -ne "Checking for mailx: Failed         \r"; echo
        echo -e "There was an error installing mailx! Installer will not start!"
        logger -t superbackup_installer "Package mailx not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for bc: Please wait...       \r"
if [ -x /usr/bin/bc ];
then
    echo -ne "Checking for bc: Present               \r"; echo
    logger -t superbackup_installer "Package bc already installed"
else
    if apt-get -y install bc > /dev/null 2>&1
    then
        echo -ne "Checking for bc: Installed         \r"; echo
        logger -t superbackup_installer "Package bc is now installed"
    else
        echo -ne "Checking for bc: Failed            \r"; echo
        echo -e "There was an error installing bc! The installer will now abort!"
        logger -t superbackup_installer "Package bc not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for expect: Please wait...       \r"
if [ -x /usr/bin/expect ];
then
    echo -ne "Checking for expect: Present               \r"; echo
    logger -t superbackup_installer "Package expect already installed"
else
    if apt-get -y install expect > /dev/null 2>&1
    then
        echo -ne "Checking for expect: Installed         \r"; echo
        logger -t superbackup_installer "Package expect is now installed"
    else
        echo -ne "Checking for expect: Failed            \r"; echo
        echo -e "There was an error installing expect! The installer will now abort!"
        logger -t superbackup_installer "Package expect not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for Perl: Please wait...       \r"
if [ -x /usr/bin/perl ];
then
    echo -ne "Checking for Perl: Present               \r"; echo
    logger -t superbackup_installer "Package perl already installed"
else
    if apt-get -y install perl > /dev/null 2>&1
    then
        echo -ne "Checking for Perl: Installed         \r"; echo
        logger -t superbackup_installer "Package perl is now installed"
    else
        echo -ne "Checking for Perl: Failed            \r"; echo
        echo -e "There was an error installing Perl! The installer will now abort!"
        logger -t superbackup_installer "Package perl not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for mc: Please wait...       \r"
if [ -x /usr/bin/mc ];
then
    echo -ne "Checking for mc: Present               \r"; echo
    logger -t superbackup_installer "Package mc already installed"
else
    if apt-get -y install mc > /dev/null 2>&1
    then
        echo -ne "Checking for mc: Installed         \r"; echo
        logger -t superbackup_installer "Package mc is now installed"
    else
        echo -ne "Checking for mc: Failed            \r"; echo
        echo -e "There was an error installing mc! The installer will now abort!"
        logger -t superbackup_installer "Package mc not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for sshfs: Please wait...       \r"
if [ -x /usr/bin/sshfs ];
then
    echo -ne "Checking for sshfs: Present               \r"; echo
    logger -t superbackup_installer "Package sshfs already installed"
else
    if apt-get -y install sshfs > /dev/null 2>&1
    then
        echo -ne "Checking for sshfs: Installed         \r"; echo
        logger -t superbackup_installer "Package sshfs is now installed"
    else
        echo -ne "Checking for sshfs: Failed            \r"; echo
        echo -e "There was an error installing sshfs! The Backup Explorer will not be available!"
        logger -t superbackup_installer "Package sshfs not installed due to an error, but continueing..."
    fi
fi
echo -ne "Checking for nano: Please wait...       \r"
if [ -x /usr/bin/nano ];
then
    echo -ne "Checking for nano: Present               \r"; echo
    logger -t superbackup_installer "Package nano already installed"
else
    if apt-get -y install nano > /dev/null 2>&1
    then
        echo -ne "Checking for nano: Installed         \r"; echo
        logger -t superbackup_installer "Package nano is now installed"
    else
        echo -ne "Checking for nano: Failed            \r"; echo
        echo -e "There was an error installing nano! The installer will now abort!"
        logger -t superbackup_installer "Package nano not installed due to an error, exiting..."
        exit
    fi
fi