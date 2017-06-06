#!/bin/bash
set -e
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root user" 2>&1
  exit 1
fi

ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    OS=Debian  # XXX or Ubuntu??
    VER=$(cat /etc/debian_version)
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

echo "  ___  _                         _"
echo " / _ \| |__  ___  ___ _ ____   _(_)_   _ _ __ ___"
echo "| | | | '_ \/ __|/ _ \ '__\ \ / / | | | | '_ ` _ \"
echo "| |_| | |_) \__ \  __/ |   \ V /| | |_| | | | | | |"
echo " \___/|_.__/|___/\___|_|    \_/ |_|\__,_|_| |_| |_|"
echo " "
echo "Welcome to Observium automatic installscript, please choose which verision of Observium you would like to install"
echo "1. Observium Community Edition"
echo "2. Observium Pro Edition stable (requires account at https://www.observium.org/subs/)"
echo "3. Observium Pro Edition rolling (requires account at https://www.observium.org/subs/)"
echo -n "(1-3):"
read observ_ver
echo "you choose $observ_ver"
echo " "
echo "Choose a MySQL root password"
read -s mysql_root
echo "Choose a MySQL password for Observium"
read -s mysql_observium

echo "mysql-server mysql-server/root_password password $mysql_root" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root" | debconf-set-selections

if [ $OS = "Ubuntu" ] && [ $VER = "16.04" ]; then
   echo "we are on Ubuntu 16.04, installing packages..."
   apt-get -qq install -y libapache2-mod-php7.0 php7.0-cli php7.0-mysql php7.0-mysqli php7.0-gd php7.0-mcrypt php7.0-json php-pear snmp fping mysql-server mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick apache2
   phpenmod mcrypt
   a2dismod mpm_event
   a2enmod mpm_prefork
   a2enmod php7.0
elif [ $OS = "Ubuntu" ] && [ $VER = "14.04" ]; then
   echo "we are on Ubuntu 14.04, installing packages..."
   apt-get -qq install -y libapache2-mod-php5 php5-cli php5-mysql php5-gd php5-mcrypt php5-json php-pear snmp fping mysql-server mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick
   php5enmod mcrypt
elif [ $OS = "Ubuntu" ] && [ $VER = "17.04" ]; then
   echo "we are on Ubuntu 17.04, installing packages..."
   apt-get -qq install -y libapache2-mod-php7.0 php7.0-cli php7.0-mysql php7.0-mysqli php7.0-gd php7.0-mcrypt php7.0-json php-pear snmp fping mysql-server mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick apache2
   phpenmod mcrypt
   a2dismod mpm_event
   a2enmod mpm_prefork
   a2enmod php7.0
elif [ $OS = "Debian" ] && [ $VER = "8.0" ]; then
   echo "we are on Debian 8.0, installing packages..."
   apt-get -qq install -y libapache2-mod-php7.0 php7.0-cli php7.0-mysql php7.0-mysqli php7.0-gd php7.0-mcrypt php7.0-json php-pear snmp fping mysql-server mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick apache2
   phpenmod mcrypt
   a2dismod mpm_event
   a2enmod mpm_prefork
   a2enmod php7.0
elif [ $OS = "Debian" ] && [ $VER = "9.0" ]; then
   echo "we are on Debian 9.0, installing packages..."
   apt-get -qq install -y libapache2-mod-php7.0 php7.0-cli php7.0-mysql php7.0-mysqli php7.0-gd php7.0-mcrypt php7.0-json php-pear snmp fping mariadb-server mariadb-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick apache2
   phpenmod mcrypt
   a2dismod mpm_event
   a2enmod mpm_prefork
   a2enmod php7.0
elif [ $OS = "Debian" ] && [ $VER = "7.0" ]; then
   echo "we are on Debian 7.0, installing packages..."
   apt-get -qq install -y libapache2-mod-php5 php5-cli php5-mysql php5-gd php5-mcrypt php5-json php-pear snmp fping mysql-server mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick
   php5enmod mcrypt
else
   echo "ERROR: This installscript does not support this distro, only Debian or Ubuntu supported. Use the manual guide at http://docs.observium.org/install_rhel7/"
   exit 1
fi

echo "Creating Observium dir"
mkdir -p /opt/observium && cd /opt

if [ $observ_ver = 1 ]; then
   echo "Downloading Observium CE and unpacking..."
   wget -r -nv http://www.observium.org/observium-community-latest.tar.gz
   tar zxf observium-community-latest.tar.gz --checkpoint=.1000
elif [ $observ_ver = 2 ]; then
   echo "Checking out Observium Pro stable from SVN"
   svn co http://svn.observium.org/svn/observium/branches/stable observium
elif [ $observ_ver = 3 ]; then
   echo "Checking out Observium Pro rolling from SVN"
   svn co http://svn.observium.org/svn/observium/trunk observium
else
   echo "ERROR: Invalid option $observ_ver"
   exit 1
fi
cd observium

echo "Creating database user for Observium..."
mysql -uroot -p"$mysql_root" -e "CREATE DATABASE observium DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci"
mysql -uroot -p"$mysql_root" -e "GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'localhost' IDENTIFIED BY '$mysql_observium'"

echo "Creating Observium config-file..."
sed "s/USERNAME/observium/g" config.php.default > /tmp/installscript.tmp
sed "s/PASSWORD/$mysql_observium/g" /tmp/installscript.tmp > config.php

./discovery.php -u

mkdir logs

mkdir rrd
chown www-data:www-data rrd

read -r -d '' APACHE22 <<- EOM
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /opt/observium/html
    <FilesMatch \.php$>
      SetHandler application/x-httpd-php
    </FilesMatch>
    <Directory />
            Options FollowSymLinks
            AllowOverride None
    </Directory>
    <Directory /opt/observium/html/>
            DirectoryIndex index.php
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Order allow,deny
            allow from all
    </Directory>
    ErrorLog  ${APACHE_LOG_DIR}/error.log
    LogLevel warn
    CustomLog  ${APACHE_LOG_DIR}/access.log combined
    ServerSignature On
</VirtualHost>
EOM

read -r -d '' APACHE24 <<- EOM
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /opt/observium/html
    <FilesMatch \.php$>
      SetHandler application/x-httpd-php
    </FilesMatch>
    <Directory />
            Options FollowSymLinks
            AllowOverride None
    </Directory>
    <Directory /opt/observium/html/>
            DirectoryIndex index.php
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Require all granted
    </Directory>
    ErrorLog  ${APACHE_LOG_DIR}/error.log
    LogLevel warn
    CustomLog  ${APACHE_LOG_DIR}/access.log combined
    ServerSignature On
</VirtualHost>
EOM

apachever="$(apache2ctl -v)"
if [[ $apachever == *"Apache/2.4"* ]]; then
  echo "Apache version is 2.4, creating config..."
  echo "$APACHE24" > /etc/apache2/sites-available/000-default.conf
elif [[ $apachever == *"Apache/2.2"* ]]; then
  echo "Apache version is 2.2m creating config..."
  echo "$APACHE22" > /etc/apache2/sites-available/default
else
  echo "ERROR: Could not find right version of Apache"
  exit 1
fi
a2enmod rewrite
apache2ctl restart

echo "Create first time Observium admin user"
echo -n "Username:"
read observ_username
echo -n "Passowrd:"
read -s observ_password
./adduser.php $observ_username $observ_password 10

echo "Creating Observium cronjob..."
read -r -d '' CRONCONFIG <<- EOM
# Run a complete discovery of all devices once every 6 hours
33  */6   * * *   root    /opt/observium/discovery.php -h all >> /dev/null 2>&1

# Run automated discovery of newly added devices every 5 minutes
*/5 *     * * *   root    /opt/observium/discovery.php -h new >> /dev/null 2>&1

# Run multithreaded poller wrapper every 5 minutes
*/5 *     * * *   root    /opt/observium/poller-wrapper.py 4 >> /dev/null 2>&1

# Run housekeeping script daily for syslog, eventlog and alert log
13 5 * * * root /opt/observium/housekeeping.php -ysel >> /dev/null 2>&1

# Run housekeeping script daily for rrds, ports, orphaned entries in the database and performance data
47 4 * * * root /opt/observium/housekeeping.php -yrptb >> /dev/null 2>&1
EOM
echo $CRONCONFIG > /etc/cron.d/observium


echo "Installation finished! Use your webbrowser and login to the web interface with the account you just created and add your first device"

