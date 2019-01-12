#!/usr/bin/env bash

set -e
#CONFIG - these must be set
SITENAME=''         # the name that will be displayed throughout your site as the site name
SITEHTTP=''         # fully qualified domain name, do not include http://
SITESSL=''          # fully qualified domain name, do not include https://
USERNAME=''         # username for mysql
DBPASS=''             # password for mysql user
DBNAME=''           # database name
ROOTPASSWORD=''     # mysql root user password, this is needed to fix login by root user
BOTNAME=''          # username for your site bot
SITEEMAIL=''        # email that will be used by your site to send emails
ADMINUSERNAME=''    # your first users username
ADMINPASS=''        # your first users password
ADMINEMAIL=''       # your first users email
PHPVER='7.2'        # can be 7.2 or 7.3
MEMCACHED=false     # install memcached true/false
REDIS=false         # install redis-server true/false
APCU=false          # install APCu true/false
DBFLAVOR='Percona'  # install either Percona or MariaDB
GOACCESS=false      # install goaccess access log analyzer

YELLOW="\033[1;33m"
RED="\033[1;31m"
GREEN="\033[1;32m"
CLEAR="\033[00m"

if [[ $EUID -ne 0 && whoami != $SUDO_USER && whoami != 'root' ]]; then
	export script=`basename $0`
	echo
	echo -e "${RED}You must run this script as a non-privileged user with sudo like:
	sudo ./${script}\033[0m" 1>&2
	echo
	exit
fi

export USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
usermod -a -G www-data $SUDO_USER
usermod -a -G $SUDO_USER www-data

if [[ $SITENAME == "" ]]; then
    echo -e "${RED}You must fill in the site name"
    exit
fi

if [[ $SITEHTTP == "" ]]; then
    echo -e "${RED}You must fill in the FQDN non ssl"
    exit
fi

if [[ $SITESSL == "" ]]; then
    echo -e "${RED}You must fill in the FQDN ssl"
    exit
fi

if [[ $USERNAME == "" ]]; then
    echo -e "${RED}You must fill in the username"
    exit
fi

if [[ $DBPASS == "" ]]; then
    echo -e "${RED}You must fill in the password"
    exit
fi

if [[ $DBNAME == "" ]]; then
    echo -e "${RED}You must fill in the database name"
    exit
fi

if [[ $ROOTPASSWORD == "" ]]; then
    echo -e "${RED}You must fill in the root users mysql password"
    exit
fi

if [[ $BOTNAME == "" ]]; then
    echo -e "${RED}You must fill in the sites bot username"
    exit
fi

if [[ $SITEEMAIL == "" ]]; then
    echo -e "${RED}You must fill in the sites email"
    exit
fi

if [[ $ADMINUSERNAME == "" ]]; then
    echo -e "${RED}You must fill in the admins username"
    exit
fi

if [[ $ADMINPASS == "" ]]; then
    echo -e "${RED}You must fill in the admins password"
    exit
fi

if [[ $ADMINEMAIL == "" ]]; then
    echo -e "${RED}You must fill in the admins email"
    exit
fi

clear
echo -e "${YELLOW}Installing PPA's...\n\n$CLEAR"
apt-get install -yqq software-properties-common git curl net-tools
add-apt-repository -y ppa:nginx/stable
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:pi-rho/dev
if [[ $DBFLAVOR == 'Percona' ]]; then
    wget -q https://repo.percona.com/apt/percona-release_0.1-6.$(lsb_release -sc)_all.deb
    dpkg -i percona-release_0.1-6.$(lsb_release -sc)_all.deb
    rm -f percona-release_0.1-6.$(lsb_release -sc)_all.deb
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
elif [[ $DBFLAVOR == 'MariaDB' ]]; then
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
    add-apt-repository -y 'deb [arch=amd64,arm64,ppc64el] http://ftp.osuosl.org/pub/mariadb/repo/10.3/ubuntu bionic main'
else
    echo -e "${RED}You must set the DB Flavor to either Percona or MariaDB"
    exit
fi


clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Updating your system before we begin...\n\n$CLEAR"
apt-get -yqq update
apt-get -yqq upgrade

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing ${DBFLAVOR} Server...\n\n$CLEAR"
rm -f $USER_HOME/.my.cnf
rm -f $USER_HOME/.mytop
export DEBIAN_FRONTEND=noninteractive
if [[ $DBFLAVOR == 'Percona' ]]; then
    apt-get install -yqq percona-server-common-5.7 percona-server-client-5.7 percona-server-server-5.7 percona-toolkit
    wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/percona.cnf -O $USER_HOME/temp.conf
    cat $USER_HOME/temp.conf >> /etc/mysql/percona-server.conf.d/mysqld.cnf
    rm $USER_HOME/temp.conf
elif [[ $DBFLAVOR == 'MariaDB' ]]; then
    apt-get install -yqq mariadb-server
    wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/mariadb.cnf -O $USER_HOME/temp.conf
    cat $USER_HOME/temp.conf >> /etc/mysql/mariadb.cnf
    rm $USER_HOME/temp.conf
fi
unset DEBIAN_FRONTEND
mysql -uroot -e "CREATE USER \"$USERNAME\"@'localhost' IDENTIFIED BY \"$DBPASS\";CREATE DATABASE $DBNAME;GRANT ALL PRIVILEGES ON $DBNAME . * TO $USERNAME@localhost;FLUSH PRIVILEGES;"

clear
echo -e "${RED}Set the root password to the same as you set in the config.\n\n$CLEAR"
mysql_secure_installation
if [[ $DBFLAVOR == 'Percona' ]]; then
    mysql -uroot "-e ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOTPASSWORD';"
fi
echo -e "${YELLOW}Creating .my.cnf$CLEAR"
echo "[client]
user=$USERNAME
password=$DBPASS

[mysql]
user=$USERNAME
password=$DBPASS
" > $USER_HOME/.my.cnf
chmod 600 $USER_HOME/.my.cnf
chown $SUDO_USER:$SUDO_USER $USER_HOME/.my.cnf

echo -e "${YELLOW}Creating .mytop$CLEAR"
echo "user=$USERNAME
password=$DBPASS
database=$DBNAME
delay=1
slow=10
header=1
color=1
idle=1
long=120" > $USER_HOME/.mytop
chmod 600 $USER_HOME/.mytop
chown $SUDO_USER:$SUDO_USER $USER_HOME/.mytop

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing Nginx...\n\n$CLEAR"
apt-get install -yqq nginx-extras
mkdir -p /var/log/nginx
chmod 755 /var/log/nginx
chown -R www-data:www-data /var/log/nginx
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/tracker -O /etc/nginx/sites-available/tracker
sed -i "s/root.*$/root \/var\/www\/$SITEHTTP\/public\/;/" /etc/nginx/sites-available/tracker
sed -i "s/PHPVERSION/${PHPVER}/" /etc/nginx/sites-available/tracker
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tracker /etc/nginx/sites-enabled/
sed -i "s/localhost/$SITEHTTP/" /etc/nginx/sites-available/tracker
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/nginx.conf -O /etc/nginx/nginx.conf
CORES=`cat /proc/cpuinfo | grep processor | wc -l`
CORES=`expr 2 \* $CORES`
sed -i "s/^worker_processes.*$/worker_processes $CORES;/" /etc/nginx/nginx.conf
echo -e "${RED}Adding $SUDO_USER to the www-data group.$CLEAR"
usermod -a -G www-data $SUDO_USER
usermod -a -G $SUDO_USER www-data
if getent group www-data | grep &>/dev/null "\b${SUDO_USER}\b"; then
    echo -e "${GREEN}$SUDO_USER is a member the www-data group.$CLEAR"
else
    echo -e "${RED}Please logout/login and restart this script.$CLEAR"
    exit
fi

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing PHP, PHP-FPM...\n\n$CLEAR"
apt-get -yqq install php${PHPVER} php${PHPVER}-fpm php${PHPVER}-dev php${PHPVER}-curl php${PHPVER}-json php${PHPVER}-mysql php-imagick php${PHPVER}-bz2 php${PHPVER}-common php${PHPVER}-xml php${PHPVER}-gd php${PHPVER}-mbstring php${PHPVER}-zip
sed -i 's/;listen =.*$/listen = \/var\/run\/php\/php${PHPVER}-fpm.sock/' /etc/php/${PHPVER}/fpm/pool.d/www.conf

if [[ "$MEMCACHED" = true ]]; then
    apt-get -yqq install php-memcached memcached
    usermod -a -G memcache www-data
    usermod -a -G www-data memcache
    usermod -a -G memcache $USER
    usermod -a -G $USER memcache
fi

if [[ "$REDIS" = true ]]; then
    apt-get -yqq install php-redis redis-server
    usermod -a -G redis www-data
    usermod -a -G www-data redis
    usermod -a -G redis $USER
    usermod -a -G $USER redis
fi

if [[ "$APCU" = true ]]; then
    apt-get -yqq install php-apcu
fi

if [[ "$GOACCESS" = true ]]; then
    echo "deb http://deb.goaccess.io/ $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/goaccess.list
    wget -O - https://deb.goaccess.io/gnugpg.key | sudo apt-key add -
    apt-get -yqq update
    apt-get -yqq install goaccess
fi

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing other, mostly needed, apps...\n\n$CLEAR"
apt-get -yqq install unzip htop tmux rar unrar jpegoptim optipng pngquant gifsicle imagemagick
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/tmux.conf -O $USER_HOME/.tmux.conf
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/bashrc -O $USER_HOME/.bashrc
sed -i -e "s/PHPVERSION/${PHPVER}/" $USER_HOME/.bashrc
source $USER_HOME/.bashrc
cp /etc/nanorc $USER_HOME/.nanorc
sed -i -e 's/^# include/include/' $USER_HOME/.nanorc
sed -i -e 's/^# set tabsize 8/set tabsize 4/' $USER_HOME/.nanorc
sed -i -e 's/^# set historylog/set historylog/' $USER_HOME/.nanorc
sed -i -e 's/^# set tabstospaces/set tabstospaces/' $USER_HOME/.nanorc
chown $SUDO_USER:$SUDO_USER $USER_HOME/.tmux.conf
chown $SUDO_USER:$SUDO_USER $USER_HOME/.bashrc
chown $SUDO_USER:$SUDO_USER $USER_HOME/.nanorc
ln -sf $USER_HOME/.nanorc /root/
ln -sf $USER_HOME/.bashrc /root/

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing composer...\n\n$CLEAR"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '93b54496392c062774670ac18b134c3b3a95e5a5e5c8f1a9f115f203b75bf9a129d5daa8ba6a13e2cc8a1da0806388a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mkdir -p $USER_HOME/bin/
mv $USER_HOME/composer.phar $USER_HOME/bin/composer
chown $SUDO_USER:$SUDO_USER $USER_HOME/.composer
chown $SUDO_USER:$SUDO_USER $USER_HOME/bin
clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing Node.js...\n\n$CLEAR"
sudo apt-get -yqq install nodejs

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Now we download the Pu-239 Source Code into /var/www/$SITEHTTP...\n\n$CLEAR"
cd /var/www/
rm -fr /var/www/$SITEHTTP
git clone https://github.com/darkalchemy/Pu-239.git $SITEHTTP
service mysql restart
service php${PHPVER}-fpm restart
service nginx restart
cd /var/www/$SITEHTTP
chown -R $SUDO_USER:www-data /var/www/$SITEHTTP
$USER_HOME/bin/composer install
sudo -u $SUDO_USER npm install
chown -R www-data:www-data /var/www/$SITEHTTP

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$SITEHTTP.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing your site.$CLEAR"
php bin/install.php install "$SITENAME" "$SITEHTTP" "$SITESSL" "$DBNAME" "$USERNAME" "$DBPASS" "$BOTNAME" "$SITEEMAIL" "$ADMINUSERNAME" "$ADMINPASS" "$ADMINEMAIL"

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$SITEHTTP.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Creating, merging, minifying and gzipping css and js files.$CLEAR"
cd /var/www/$SITEHTTP
php bin/uglify.php

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$SITEHTTP.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css and js files.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Setting correct permissions and ownership.$CLEAR"
chown -R $SUDO_USER:www-data /var/www/$SITEHTTP
php bin/set_perms.php

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$SITEHTTP.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Imported trivia, tvmaze and images databases.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css and js files.$CLEAR"
echo -e "${GREEN}Set correct permissions and ownership.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"

## Delete site cache, probably owned by root
rm -r /dev/shm/$DBNAME

clear
echo -e "${GREEN}The installation of Pu-239 completed successfully.$CLEAR"
echo -e "${GREEN}The cleanup scripts require an addition to crontab as listed below:$CLEAR"

echo -e "${RED}# add cron job to root cron for running cleanup
${GREEN}sudo crontab -e

${RED}### Use this if you DO NOT need any logging for these scripts
${GREEN}# runs cron_controller.php every minute, if not already running, as user www-data
* * * * * su www-data -s /bin/bash -c \"/usr/bin/php /var/www/${SITEHTTP}/include/cron_controller.php\" >/dev/null 2>&1

# this can take several minutes to run, especially the first time, so we run it separate
# runs images_update.php every 30 minutes, if not already running, as user www-data
*/30 * * * * su www-data -s /bin/bash -c \"/usr/bin/php /var/www/${SITEHTTP}/include/images_update.php\" >/dev/null 2>&1

${RED}### Use this if you DO need any logging for these scripts
${GREEN}# runs cron_controller.php every minute, if not already running, as user www-data
* * * * * su www-data -s /bin/bash -c \"/usr/bin/php /var/www/${SITEHTTP}/include/cron_controller.php\" >> /var/log/nginx/cron_`date +\%Y\%m\%d`.log 2>&1

# this can take several minutes to run, especially the first time, so we run it separate
# runs images_update.php every 30 minutes, if not already running, as user www-data
*/30 * * * * su www-data -s /bin/bash -c \"/usr/bin/php /var/www/${SITEHTTP}/include/images_update.php\" >> /var/log/nginx/images_`date +\%Y\%m\%d`.log 2>&1
$CLEAR"

