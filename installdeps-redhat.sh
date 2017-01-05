#! /bin/bash
#
# This script contains the installation checks for the RedHat OS and is
# part of the SuperBackup Suite created by Jeffrey Langerak.
#
# Bugs and/or features can be left at the repository below:
# https://github.com/langerak/superbackup
#
# Starting the depency installation for RedHat:
echo -ne "Checking for dialog: Please wait...     \r"
if [ -x /usr/bin/dialog ];
then
    echo -ne "Checking for dialog: Present            \r"; echo
logger -t superbackup_installer "Package dialog already installed"
else
    if yum -qy install dialog > /dev/null 2>&1
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
    if yum -qy install curl > /dev/null 2>&1
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
    if yum -qy install rsync > /dev/null 2>&1
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
if [ -x /usr/bin/sendmail ];
then
    echo -ne "Checking for sendmail: Present               \r"; echo
    logger -t superbackup_installer "Package sendmail already installed"
else
    if yum -qy install sendmail > /dev/null 2>&1
    then
        echo -ne "Checking for sendmail: Installed         \r"; echo
        logger -t superbackup_installer "Package sendmail is now installed"
    else
        echo -ne "Checking for sendmail: Failed            \r"; echo
        echo -e "There was an error installing sendmail! The installer will now abort!"
        logger -t superbackup_installer "Package sendmail not installed due to an error, exiting..."
        exit
    fi
fi
echo -ne "Checking for bc: Please wait...       \r"
if [ -x /usr/bin/bc ];
then
    echo -ne "Checking for bc: Present               \r"; echo
    logger -t superbackup_installer "Package bc already installed"
else
    if yum -qy install bc > /dev/null 2>&1
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
    if yum -qy install expect > /dev/null 2>&1
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
    if yum -qy install perl > /dev/null 2>&1
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
    if yum -qy install mc > /dev/null 2>&1
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
    if yum -qy install sshfs > /dev/null 2>&1
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
    if yum -qy install nano > /dev/null 2>&1
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