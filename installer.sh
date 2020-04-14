#!/usr/bin/env bash

## VERSION=1.23
set -e
#CONFIG - these must be set
SITENAME=''                     # the name that will be displayed throughout your site as the site name
SITEHTTP=''                     # fully qualified domain name, do not include http://
SITESSL=''                      # fully qualified domain name, do not include https://
USERNAME=''                     # username for mysql
DBPASS=''                       # password for mysql user
DBNAME=''                       # database name
ROOTPASSWORD=''                 # mysql root user password, this is needed to fix login by root user
BOTNAME=''                      # username for your site bot
SITEEMAIL=''                    # email that will be used by your site to send emails
ADMINUSERNAME=''                # your first users username
ADMINPASS=''                    # your first users password
ADMINEMAIL=''                   # your first users email
PATHTOINSTALL='/var/www/master' # the path to install Pu-239 into, this path with be removed, if it already exists
PHPVER='7.4'                    # only 7.4
MEMCACHED=false                 # install memcached true/false
REDIS=false                     # install redis-server true/false
APCU=false                      # install APCu true/false
DBFLAVOR='Percona'              # install either Percona or MariaDB
GOACCESS=false                  # install goaccess access log analyzer

YELLOW="\033[1;33m"
RED="\033[1;31m"
GREEN="\033[1;32m"
CLEAR="\033[00m"

if [[ $EUID -ne 0 ]]; then
  export script
  script=$(basename "$0")
  echo
  echo -e "${RED}You must run this script as a non-privileged user with sudo like:
    sudo ./${script}\033[0m" 1>&2
  echo
  exit
fi

if [[ $(logname) == 'root' ]]; then
  export script
  script=$(basename "$0")
  echo
  echo -e "${RED}This script does not allow you to be logged in as the root user."
  echo -e "${RED}You must run this script as a non-privileged user with sudo like:
    sudo ./${script}\033[0m" 1>&2
  echo
  exit
fi

[[ ${SUDO_USER} ]] && user=${SUDO_USER} || user=$(whoami)
export USER_HOME
USER_HOME=$(getent passwd "${user}" | cut -d: -f6)

if [[ "${SITENAME}" == "" ]]; then
  echo -e "${RED}You must fill in the site name"
  exit
fi

if [[ ${SITEHTTP} == "" ]]; then
  echo -e "${RED}You must fill in the FQDN non ssl"
  exit
fi

if [[ ${SITESSL} == "" ]]; then
  echo -e "${RED}You must fill in the FQDN ssl"
  exit
fi

if [[ "${USERNAME}" == "" ]]; then
  echo -e "${RED}You must fill in the username"
  exit
fi

if [[ "${DBPASS}" == "" ]]; then
  echo -e "${RED}You must fill in the password"
  exit
fi

if [[ "${DBNAME}" == "" ]]; then
  echo -e "${RED}You must fill in the database name"
  exit
fi

if [[ "${ROOTPASSWORD}" == "" ]]; then
  echo -e "${RED}You must fill in the root users mysql password"
  exit
fi

if [[ ${BOTNAME} == "" ]]; then
  echo -e "${RED}You must fill in the sites bot username"
  exit
fi

if [[ ${SITEEMAIL} == "" ]]; then
  echo -e "${RED}You must fill in the sites email"
  exit
fi

if [[ "${ADMINUSERNAME}" == "" ]]; then
  echo -e "${RED}You must fill in the admins username"
  exit
fi

if [[ "${ADMINPASS}" == "" ]]; then
  echo -e "${RED}You must fill in the admins password"
  exit
fi

if [[ ${ADMINEMAIL} == "" ]]; then
  echo -e "${RED}You must fill in the admins email"
  exit
fi

if [[ "${PATHTOINSTALL}" == "" ]]; then
  PATHTOINSTALL='/var/www/master'
fi

if [[ ${PHPVER} == "" ]]; then
  PHPVER='7.4'
fi

if [[ ${MEMCACHED} != true ]]; then
  MEMCACHED=false
fi

if [[ ${REDIS} != true ]]; then
  REDIS=false
fi

if [[ ${APCU} != true"" ]]; then
  APCU=false
fi

if [[ ${DBFLAVOR} == "" ]]; then
  DBFLAVOR='Percona'
fi

if [[ ${GOACCESS} != true ]]; then
  GOACCESS=false
fi

clear
echo -e "${YELLOW}Installing PPA's...\n\n$CLEAR"
apt-get install -yqq software-properties-common curl
add-apt-repository -y ppa:nginx/stable
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:pi-rho/dev
add-apt-repository -y ppa:git-core/ppa
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
if [[ ${DBFLAVOR} == 'Percona' ]]; then
  wget -q "https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb" -O percona-release_latest.deb
  dpkg -i percona-release_latest.deb
  rm -f percona-release_latest.deb
  percona-release setup ps80
elif [[ ${DBFLAVOR} == 'MariaDB' ]]; then
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  add-apt-repository -y "deb [arch=amd64,arm64,ppc64el] http://ftp.osuosl.org/pub/mariadb/repo/10.4/ubuntu $(lsb_release -sc) main"
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
apt-get install -yqq git net-tools gettext

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing ${DBFLAVOR} Server...\n\n$CLEAR"
rm -f "${USER_HOME}/.my.cnf"
rm -f "${USER_HOME}/.mytop"
export DEBIAN_FRONTEND=noninteractive
if [[ ${DBFLAVOR} == 'Percona' ]]; then
  apt-get install -yqq percona-server-server percona-toolkit
  wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/mysql.cnf -O "${USER_HOME}/temp.conf"
  cat "${USER_HOME}/temp.conf" >>/etc/mysql/percona-server.conf.d/mysqld.cnf
  rm "${USER_HOME}/temp.conf"
  clear
  unset DEBIAN_FRONTEND
  sudo mysql -uroot -e "CREATE USER \"$USERNAME\"@'localhost' IDENTIFIED WITH mysql_native_password BY \"$DBPASS\";CREATE DATABASE $DBNAME;GRANT ALL PRIVILEGES ON $DBNAME . * TO \"$USERNAME\"@localhost;FLUSH PRIVILEGES;"
  mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOTPASSWORD';"
elif [[ ${DBFLAVOR} == 'MariaDB' ]]; then
  apt-get install -yqq mariadb-server
  wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/mysql.cnf -O "${USER_HOME}/temp.conf"
  if [ -d "/etc/mysql/percona-server.conf.d/" ]; then
    cat "${USER_HOME}/temp.conf" > /etc/mysql/percona-server.conf.d/mysqld.cnf
  elif [ 'd "/etc/mysql/mysql.conf.d/" ]; then
    cat "${USER_HOME}/temp.conf" > /etc/mysql/mysql.conf.d/mysqld.cnf
  else
    cat "${USER_HOME}/temp.conf" > /etc/mysql/mysqld.cnf
  fi
  rm "${USER_HOME}/temp.conf"
  unset DEBIAN_FRONTEND
  clear
  sudo mysql -e "SET old_passwords=0; ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOTPASSWORD';"
  sudo mysql -uroot -p"$ROOTPASSWORD" -e "SET old_passwords=0; CREATE USER \"$USERNAME\"@'localhost' IDENTIFIED BY \"$DBPASS\";CREATE DATABASE $DBNAME;GRANT ALL PRIVILEGES ON $DBNAME . * TO \"$USERNAME\"@localhost;FLUSH PRIVILEGES;"
fi
echo -e "${YELLOW}Creating .my.cnf$CLEAR"
echo "[client]
user=${USERNAME}
password=${DBPASS}

[mysql]
user=${USERNAME}
password=${DBPASS}
" >"${USER_HOME}/.my.cnf"
chmod 600 "${USER_HOME}/.my.cnf"
chown "${user}":"${user}" "${USER_HOME}/.my.cnf"

echo -e "${YELLOW}Creating .mytop$CLEAR"
echo "user=${USERNAME}
password=${DBPASS}
database=${DBNAME}
delay=1
slow=10
header=1
color=1
idle=1
long=120" >"${USER_HOME}/.mytop"
chmod 600 "${USER_HOME}/.mytop"
chown "${user}":"${user}" "${USER_HOME}/.mytop"

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
REPLACE="\/"
TOREPLACE="/"
PINSTALL="${PATHTOINSTALL//$TOREPLACE/$REPLACE}"
sed -i "s/root.*$/root ${PINSTALL}\/public\/;/" /etc/nginx/sites-available/tracker
sed -i "s/PHPVERSION/${PHPVER}/" /etc/nginx/sites-available/tracker
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tracker /etc/nginx/sites-enabled/
sed -i "s/localhost/${SITEHTTP}/" /etc/nginx/sites-available/tracker
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/nginx.conf -O /etc/nginx/nginx.conf
CORES=$(cat /proc/cpuinfo | grep -c processor)
CORES=$((2 * $CORES))
sed -i "s/^worker_processes.*$/worker_processes $CORES;/" /etc/nginx/nginx.conf
echo -e "${RED}Adding ${user} to the www-data group.$CLEAR"
usermod -a -G www-data "${user}"
usermod -a -G "${user}" www-data
if getent group www-data | grep &>/dev/null "\b${user}\b"; then
  echo -e "${GREEN}${user} is a member the www-data group.$CLEAR"
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
apt-get -yqq install php${PHPVER} php${PHPVER}-{fpm,dev,curl,json,bz2,common,xml,gd,mbstring,zip,intl,mysql} php-imagick
sed -i 's/;listen =.*$/listen = \/var\/run\/php\/php${PHPVER}-fpm.sock/' /etc/php/${PHPVER}/fpm/pool.d/www.conf
sed -i 's/;listen.backlog =.*$/listen.backlog = 65535/' /etc/php/${PHPVER}/fpm/pool.d/www.conf
sed -i 's/pm = dynamic/pm = static/' /etc/php/${PHPVER}/fpm/pool.d/www.conf
sed -i 's/pm.max_children = 5/pm.max_children = 50/' /etc/php/${PHPVER}/fpm/pool.d/www.conf

usermod -a -G www-data "${user}"
usermod -a -G "${user}" www-data

if [[ "$MEMCACHED" == true ]]; then
  apt-get -yqq install php-memcached memcached
  usermod -a -G memcache www-data
  usermod -a -G www-data memcache
  usermod -a -G memcache "${user}"
  usermod -a -G "${user}" memcache
fi

if [[ "$REDIS" == true ]]; then
  apt-get -yqq install php-redis redis-server
  usermod -a -G redis www-data
  usermod -a -G www-data redis
  usermod -a -G redis "${user}"
  usermod -a -G "${user}" redis
fi

if [[ "$APCU" == true ]]; then
  apt-get -yqq install php-apcu
fi

if [[ "$GOACCESS" == true ]]; then
  echo "deb http://deb.goaccess.io/ $(lsb_release -cs) main" | tee -a /etc/apt/sources.list.d/goaccess.list
  wget -O - https://deb.goaccess.io/gnugpg.key | apt-key add -
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
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/tmux.conf -O "${USER_HOME}/.tmux.conf"
wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/bashrc -O "${USER_HOME}/.bashrc"
sed -i -e "s/PHPVERSION/${PHPVER}/" "${USER_HOME}/.bashrc"
cp /etc/nanorc "${USER_HOME}/.nanorc"
sed -i -e 's/^# include/include/' "${USER_HOME}/.nanorc"
sed -i -e 's/^# set tabsize 8/set tabsize 4/' "${USER_HOME}/.nanorc"
sed -i -e 's/^# set historylog/set historylog/' "${USER_HOME}/.nanorc"
sed -i -e 's/^# set tabstospaces/set tabstospaces/' "${USER_HOME}/.nanorc"
chown -R "${user}":"${user}" "${USER_HOME}/"
ln -sf "${USER_HOME}/.nanorc" /root/
ln -sf "${USER_HOME}/.bashrc" /root/

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing composer...\n\n$CLEAR"
wget https://raw.githubusercontent.com/composer/getcomposer.org/3c21a2c1affd88dd3fec6251e91a53e440bc2198/web/installer -O - -q | sudo php -- --install-dir=/usr/bin --filename=composer --quiet
source /root/.bashrc

clear
if [ ! -f /etc/systemd/system/mysql.service.d/override.conf ]; then
  wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/override.conf -O "${USER_HOME}/temp.conf"
  mkdir -p /etc/systemd/system/mysql.service.d/
  cat "${USER_HOME}/temp.conf" >>/etc/systemd/system/mysql.service.d/override.conf
  rm "${USER_HOME}/temp.conf"
fi
if grep -q 'Maximum Socket Receive Buffer' /etc/sysctl.conf; then
  echo -e "${GREEN}/etc/sysctl.conf does not need editing.$CLEAR"
else
  wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/sysctl.conf -O "${USER_HOME}/temp.conf"
  cat "${USER_HOME}/temp.conf" >>/etc/sysctl.conf
  rm "${USER_HOME}/temp.conf"
fi
if grep -q 'root soft     nproc          200000' /etc/security/limits.conf; then
  echo -e "${GREEN}/etc/security/limits.conf does not need editing.$CLEAR"
else
  wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/limits.conf -O "${USER_HOME}/temp.conf"
  cat "${USER_HOME}/temp.conf" >>/etc/security/limits.conf
  rm "${USER_HOME}/temp.conf"
fi

if grep -q 'session required pam_limits.so' /etc/pam.d/common-session; then
  echo -e "${GREEN}/etc/pam.d/common-session does not need editing.$CLEAR"
else
  wget --no-check-certificate https://raw.githubusercontent.com/darkalchemy/Pu-239-Installer/master/config/session.conf -O "${USER_HOME}/temp.conf"
  cat "${USER_HOME}/temp.conf" >>/etc/pam.d/common-session
  rm "${USER_HOME}/temp.conf"
fi

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
apt-get -yqq install nodejs

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
echo -e "${YELLOW}Now we download the Pu-239 Source Code into $PATHTOINSTALL...\n\n$CLEAR"
rm -fr "${PATHTOINSTALL}"
git clone https://github.com/darkalchemy/Pu-239.git "${PATHTOINSTALL}"
service mysql restart
service php${PHPVER}-fpm restart
service nginx restart
cd "${PATHTOINSTALL}"
chown -R "${user}":www-data "${PATHTOINSTALL}"
sudo -u "${user}" /usr/bin/composer install --no-scripts --no-progress --no-suggest --optimize-autoloader
sudo -u "${user}" /usr/bin/npm install
chown -R www-data:www-data "${PATHTOINSTALL}"

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into $PATHTOINSTALL.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Installing your site.$CLEAR"
php bin/install.php install "${SITENAME}" "${SITEHTTP}" "${SITESSL}" "${DBNAME}" "${USERNAME}" "${DBPASS}" "${BOTNAME}" "${SITEEMAIL}" "${ADMINUSERNAME}" "${ADMINPASS}" "${ADMINEMAIL}"

clear
echo -e "${GREEN}Installed PPA's.$CLEAR"
echo -e "${GREEN}Updated your system.$CLEAR"
echo -e "${GREEN}Installed ${DBFLAVOR} Server.$CLEAR"
echo -e "${GREEN}Installed Nginx.$CLEAR"
echo -e "${GREEN}Installed PHP, PHP-FPM.$CLEAR"
echo -e "${GREEN}Installed other, mostly needed, apps.$CLEAR"
echo -e "${GREEN}Installed composer.$CLEAR"
echo -e "${GREEN}Installed Node.js.$CLEAR"
echo -e "${GREEN}Downloaded the Pu-239 Source Code into $PATHTOINSTALL.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Creating, merging, minifying and gzipping css/js files.$CLEAR"
cd "${PATHTOINSTALL}"
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
echo -e "${GREEN}Downloaded the Pu-239 Source Code into $PATHTOINSTALL.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css/js files.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"
echo -e "${YELLOW}Setting correct permissions and ownership.$CLEAR"
chown -R "${user}":www-data "${PATHTOINSTALL}"
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
echo -e "${GREEN}Downloaded the Pu-239 Source Code into $PATHTOINSTALL.$CLEAR"
echo -e "${GREEN}Site installation completed.$CLEAR"
echo -e "${GREEN}Imported trivia, tvmaze and images databases.$CLEAR"
echo -e "${GREEN}Created, merged, minified and gzipped css/js files.$CLEAR"
echo -e "${GREEN}Set correct permissions and ownership.$CLEAR"
echo -e "${GREEN}Done.$CLEAR"

## Delete site cache, probably owned by root
if [ -d "/dev/shm/${DBNAME}" ]; then
  rm -r "/dev/shm/${DBNAME}"
fi

clear
echo -e "${GREEN}The installation of Pu-239 completed successfully.$CLEAR"
echo -e "${GREEN}You should reboot this server to enable the system settings that have been changed.$CLEAR"
echo -e "${GREEN}The cleanup scripts require an addition to root crontab as listed below:$CLEAR"

echo -e "${RED}# add cron job to root cron for running cleanup
${GREEN}sudo crontab -e
${GREEN}# runs jobby.php every minute, if not already running
* * * * * cd \"${PATHTOINSTALL}\" && /usr/bin/php jobby.php 1>> /dev/null 2>&1
$CLEAR"

echo -e "${GREEN}After rebooting the server, open your browser to http://${SITEHTTP}/login.php and sign in using the admin email/password.$CLEAR"
