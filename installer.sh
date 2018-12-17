#!/usr/bin/env bash

#CONFIG - these must be set
USERNAME=""         #username for mysql
PASS=""             #password for mysql user
DBNAME=""           #database name
ROOTPASSWORD=""     # mysql root user password, this is needed to fix login by root user
IPADDY=""           #fully qualified domain name or routable ip

YELLOW="\033[1;33m"
RED="\033[1;31m"
GREEN="\033[1;32m"
CLEAR="\033[00m"

if [[ $EUID -ne 0 && whoami != $SUDO_USER && whoami != 'root' ]]; then
	export script=`basename $0`
	echo
	echo -e "${RED}You must run this script as a user using
	sudo ./${script}\033[0m" 1>&2
	echo
	exit
fi

export USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
usermod -a -G www-data $SUDO_USER
usermod -a -G $SUDO_USER www-data

if [[ $USERNAME == "" ]]; then
    echo -e "${RED}You must fill in the username"
    exit
fi

if [[ $PASS == "" ]]; then
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

if [[ $IPADDY == "" ]]; then
    echo -e "${RED}You must fill in the ip address or FQDN"
    exit
fi

echo -e "${YELLOW}Installing PPA's...\n\n$CLEAR"
apt-get install -yqq software-properties-common git curl net-tools
add-apt-repository -y ppa:nginx/stable
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:pi-rho/dev
wget -q https://repo.percona.com/apt/percona-release_0.1-6.$(lsb_release -sc)_all.deb
dpkg -i percona-release_0.1-6.$(lsb_release -sc)_all.deb
rm -f percona-release_0.1-6.$(lsb_release -sc)_all.deb
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Updating your system before we begin...\n\n$CLEAR"
apt-get -yqq update
apt-get -yqq upgrade

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing Percona XtraDB Server...\n\n$CLEAR"
rm -f $USER_HOME/.my.cnf
export DEBIAN_FRONTEND=noninteractive
apt-get install -yqq percona-server-common-5.7 percona-server-client-5.7 percona-server-server-5.7 percona-toolkit
unset DEBIAN_FRONTEND
mysql -uroot -e "CREATE USER \"$USERNAME\"@'localhost' IDENTIFIED BY \"$PASS\";CREATE DATABASE $DBNAME;GRANT ALL PRIVILEGES ON $DBNAME . * TO $USERNAME@localhost;FLUSH PRIVILEGES;"

clear
echo -e "${RED}Set the root password to the same as you set in the config.$CLEAR"
mysql_secure_installation
mysql -uroot "-e ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOTPASSWORD';"
echo -e "${YELLOW}Creating .my.cnf$CLEAR"
echo "[client]
user=$USERNAME
password=$PASS

[mysql]
user=$USERNAME
password=$PASS
" > $USER_HOME/.my.cnf
chmod 600 $USER_HOME/.my.cnf
chown $SUDO_USER:$SUDO_USER $USER_HOME/.my.cnf

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing Nginx...\n\n$CLEAR"
apt-get install -yqq nginx-extras
mkdir -p /var/log/nginx
chmod 755 /var/log/nginx
chown -R www-data:www-data /var/log/nginx
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/tracker -O /etc/nginx/sites-available/tracker
sed -i "s/root.*$/root \/var\/www\/$IPADDY\/public\/;/" /etc/nginx/sites-available/tracker
ln -s /etc/nginx/sites-available/tracker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
sed -i "s/localhost/$IPADDY/" /etc/nginx/sites-available/tracker
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/nginx.conf -O /etc/nginx/nginx.conf
CORES=`cat /proc/cpuinfo | grep processor | wc -l`
sed -i "s/^worker_processes.*$/worker_processes $CORES;/" /etc/nginx/nginx.conf
if getent group www-data | grep &>/dev/null "\b${SUDO_USER}\b"; then
    echo -e "${GREEN}$SUDO_USER is a member the www-data group.$CLEAR"
else
    echo -e "${RED}Adding $SUDO_USER to the www-data group.$CLEAR"
    usermod -a -G www-data $SUDO_USER
    usermod -a -G $SUDO_USER www-data
    echo -e "${GREEN}Adding $SUDO_USER to the www-data group.$CLEAR"
    echo -e "${RED}Please logout/login and restart this script.$CLEAR"
    exit
fi

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing PHP, PHP-FPM...\n\n$CLEAR"
apt-get -yqq install -yqq php7.2 php7.2-fpm php7.2-dev php7.2-curl php7.2-json php7.2-mysql php-imagick php7.2-bz2 php7.2-common php7.2-xml php7.2-gd php7.2-mbstring php7.2-zip
sed -i 's/;listen =.*$/listen = \/run\/php\/php7.2-fpm.sock/' /etc/php/7.2/fpm/pool.d/www.conf

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing other, mostly needed, apps...\n\n$CLEAR"
apt-get -yqq install unzip htop tmux rar unrar jpegoptim optipng pngquant gifsicle imagemagick
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/my.cnf -O $USER_HOME/temp.conf
cat $USER_HOME/temp.conf >> /etc/mysql/percona-server.conf.d/mysqld.cnf
rm $USER_HOME/temp.conf
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/tmux.conf -O $USER_HOME/.tmux.conf
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/bashrc -O $USER_HOME/.bashrc
cp /etc/nanorc $USER_HOME/.nanorc
sed -i -e 's/^# include/include/' $USER_HOME/.nanorc
sed -i -e 's/^# set tabsize 8/set tabsize 4/' $USER_HOME/.nanorc
sed -i -e 's/^# set historylog/set historylog/' $USER_HOME/.nanorc
sed -i -e 's/^# set tabstospaces/set tabstospaces/' $USER_HOME/.nanorc
chown $SUDO_USER:$SUDO_USER $USER_HOME/.tmux.conf
chown $SUDO_USER:$SUDO_USER $USER_HOME/.bashrc
chown $SUDO_USER:$SUDO_USER $USER_HOME/.nanorc
ln -sf $USER_HOME/.nanorc /root/

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing composer...\n\n$CLEAR"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '93b54496392c062774670ac18b134c3b3a95e5a5e5c8f1a9f115f203b75bf9a129d5daa8ba6a13e2cc8a1da0806388a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mkdir $USER_HOME/bin/
mv $USER_HOME/composer.phar $USER_HOME/bin/composer
chown $SUDO_USER:$SUDO_USER $USER_HOME/.composer
chown $SUDO_USER:$SUDO_USER $USER_HOME/bin
clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing Node.js...\n\n$CLEAR"
sudo apt-get install -yqq nodejs

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Now we download the Pu-239 Source Code into /var/www/$IPADDY...\n\n$CLEAR"
cd /var/www/
git clone https://github.com/darkalchemy/Pu-239.git $IPADDY
service mysql restart
service php7.2-fpm restart
service nginx restart
cd /var/www/$IPADDY
chown -R $SUDO_USER:www-data /var/www/$IPADDY
sudo -u $SUDO_USER $USER_HOME/bin/composer install
sudo -u $SUDO_USER npm install
chown -R www-data:www-data /var/www/$IPADDY

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$IPADDY.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Now you need to point your browser to http://${IPADDY}/install/"
echo -e "and complete the site installation process."
echo -e "Please stop when you get here -> http://${IPADDY}/signup.php.$CLEAR"
read -p "
Once you have completed the above steps, press any key to continue:
" -n 1 -r

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$IPADDY.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Importing trivia, tvmaze and images databases.$CLEAR"
mysql $DBNAME < /var/www/$IPADDY/database/trivia.php.sql
mysql $DBNAME < /var/www/$IPADDY/database/tvmaze.php.sql
mysql $DBNAME < /var/www/$IPADDY/database/images.php.sql

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$IPADDY.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Imported trivia, tvmaze and images databases.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Creating, merging, minifying and gzipping css and js files.$CLEAR"
cd /var/www/$IPADDY
php bin/uglify.php

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$IPADDY.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Imported trivia, tvmaze and images databases.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css and js files.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Setting correct permissions and ownership.$CLEAR"
chown -R $SUDO_USER:www-data /var/www/$IPADDY
php bin/set_perms.php

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$IPADDY.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Imported trivia, tvmaze and images databases.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css and js files.$CLEAR"
echo -e "${GREEN}Set correct permissions and ownership.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Removing /var/www/$IPADDY/public/install.$CLEAR"
rm -r /var/www/$IPADDY/public/install

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system before we began.$CLEAR"
echo -e "${GREEN}Installed Percona XtraDB Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into /var/www/$IPADDY.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Imported trivia, tvmaze and images databases.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css and js files.$CLEAR"
echo -e "${GREEN}Set correct permissions and ownership.$CLEAR"
echo -e "${GREEN}Removed /var/www/$IPADDY/public/install.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"

clear
echo -e "${GREEN}The installation of Pu-239 completed successfully.$CLEAR"
echo -e "${YELLOW}Now, add yourself to the site by going to http://${IPADDY}/signup.php to create a new user.$CLEAR"
echo -e "${YELLOW}Then, Follow the rest of the steps in the README:

${RED}# add cron job to root cron for running cleanup
${GREEN}sudo crontab -e

${RED}### Use this if you DO NOT need any logging for these scripts
${GREEN}# runs cron_controller.php every minute, if not already running, as user www-data
* * * * * su www-data -s /bin/bash -c "/usr/bin/php /var/www/${IPADDY}/include/cron_controller.php" >/dev/null 2>&1

# this can take several minutes to run, especially the first time, so we run it separate
# runs images_update.php every 30 minutes, if not already running, as user www-data
*/30 * * * * su www-data -s /bin/bash -c "/usr/bin/php /var/www/${IPADDY}/include/images_update.php" >/dev/null 2>&1

${RED}### Use this if you DO need any logging for these scripts
${GREEN}# runs cron_controller.php every minute, if not already running, as user www-data
* * * * * su www-data -s /bin/bash -c "/usr/bin/php /var/www/${IPADDY}/include/cron_controller.php" >> /var/log/nginx/cron_`date +\%Y\%m\%d`.log 2>&1

# this can take several minutes to run, especially the first time, so we run it separate
# runs images_update.php every 30 minutes, if not already running, as user www-data
*/30 * * * * su www-data -s /bin/bash -c "/usr/bin/php /var/www/${IPADDY}/include/images_update.php" >> /var/log/nginx/images_`date +\%Y\%m\%d`.log 2>&1
$CLEAR"

