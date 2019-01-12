Pu-239 Installer
==============

A simple bash script to install Pu-239, Percona XtraDB, PHP7.2-FPM or PHP7.3-FPM, nginx and all dependancies.  
This script has been tested on Ubuntu 16.04 LTS and Ubuntu 18.84 LTS.

#### Please log in as a non-privileged user, NOT root, to run this script.

To use:

```
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/installer.sh -O installer.sh
chmod a+x installer.sh
nano installer.sh #edit the first few lines. Please pay attention to what you use as you will use these again.
sudo ./installer.sh
```

Also, note that since Pu-239 defaults to using the file system as cache, redis, memcached and apcu are not installed by this script.

If you like this project, please consider supporting me on [Patreon](https://www.patreon.com/user?u=15795177) 
