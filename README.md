Pu-239 Installer
==============

A simple bash script to install Pu-239, Percona XtraDB 8.0 or MariaDB 10.4, PHP7.3-FPM, nginx and all dependencies.  
If chosen, redis, memcached, APCu and GoAccess can be installed.
This script has been tested on Ubuntu 16.04 LTS and Ubuntu 18.84 LTS.

#### Please log in as a non-privileged user, NOT root, to run this script.

To use:

```
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/installer.sh -O installer.sh
chmod a+x installer.sh
nano installer.sh #edit the first few lines. Please pay attention to what you use as you will use these again.
sudo ./installer.sh
```

If you like this project, please consider supporting me on [Patreon](https://www.patreon.com/user?u=15795177) 
