# SuperBackup Backup Suite

# What is SuperBackup?
SuperBackup is a set of simple, yet powerful, bash scripts that allows users to
create backups and MySQL dumps of the environments that the script is installed
on.

# How does SuperBackup create backups?
It uses the rsync tool to create the backups, because of this it is quite
convenient for remote disk usage. The script uses a retention schema that
creates backups as follows:

* On Monday a full backup is created starting from the configured backup root
* The rest of the weekdays a incremental backup (only the changed files) will
be created based on the backup of yesterday (with exception of Monday).

# What are the local system requirements?
The script has been tested on the following systems and is known to work:

* Ubuntu 10.04 up to Ubuntu 16.10
* CentOS 5 up to CentOS 7
* Debian 5 up to Debian 8
* ArchLinux and derivates

For the scripts to work at least Bash 3 is needed. For better code handling I
will start shifting to Bash 4 so the requirements may change later on. For now
with Bash 3 alot of obsolete OS'es will still work.

# What are the remote system requirements?
Basically anything that accepts SSH connections. This may vary from a regular
Linux server with the Bash shell to a custom shell only allowing rsync for
example.

# What hosting control panels are supported?
At this point the following panels are supported:

* DirectAdmin
* cPanel/WHM
* Plesk
* ISPConfig3

The MySQL configuration from the above panels is used to create MySQL dumps.

# Can it handle quotas?
Yes, but you have to implement filesystem quota on the remote server yourself
else this will not be available and all space on the remote end can be used.

# What packages does the SuperBackup use?
For the full suite to funtion the following software will be installed on the
system if not present yet:

* Dialog
* Expect
* BC
* Rsync
* SSHFS
* Midnight Commander
* Nano
* Mailx / Sendmail
* Perl

For as far as I could test it, the scripts should also function on the following
architectures (for the earlier mentioned supported operating systems), but is
not limited to it:

* x86(_64)
* arm
* mips
* powerpc