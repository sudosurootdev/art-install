#!/bin/bash

#
# MacPorts, Apache 2, MySQL 5 and PHP 5.3 installation script for Mac OS X
#
# Author: enekochan
# URL: http://tech.enekochan.com
#
# It is mandatory to have installed:
# - Apple Xcode Developer Tools
# - Apple Command Line Developer Tools
# Download them from http://connect.apple.com/ (Apple ID is needed)
# Once installed run this command to accept the EULA:
# 
# $ xcodebuild -license
#
################################################################################
# Important file locations
################################################################################
# httpd.conf:         /opt/local/apache2/conf/httpd.conf
# httpd-vhosts.conf:  /opt/local/apache2/conf/extra/httpd-vhosts.conf
# htdocs folder:      /opt/local/apache2/htdocs
# php.ini:            /opt/local/etc/php5/php.ini
################################################################################
#
# Ref: http://gillesfabio.com/blog/2010/12/17/getting-php-5-3-on-mac-os-x/
#
################################################################################

function readPrompt() {
  while true; do
    read -e -p "$1 (default $2)"": " result
    case $result in
      Y|y ) result="y"; break;;
      N|n ) result="n"; break;;
      "" ) result=`echo $2 | awk '{print substr($0,0,1)}'`; break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

# If you want to completely uninstall MacPorts and all installed ports
# use the "uninstall" parameter
if [ "$1" == "uninstall" ]; then
  echo "Uninstalling MacPorts and all installed ports..."
  sudo port -fp uninstall installed
  sudo rm -rf \
    /opt/local \
    /Applications/DarwinPorts \
    /Applications/MacPorts \
    /Library/LaunchDaemons/org.macports.* \
    /Library/Receipts/DarwinPorts*.pkg \
    /Library/Receipts/MacPorts*.pkg \
    /Library/StartupItems/DarwinPortsStartup \
    /Library/Tcl/darwinports1.0 \
    /Library/Tcl/macports1.0 \
    ~/.macports
  exit
fi

readPrompt "Do you want Apache 2 and MySQL 5 to autorun on boot? " "y"
AUTORUN=$result

readPrompt "Do you want to secure MySQL 5? (MySQL password for root user will be changed in this interactive process) " "y"
SECURE=$result

readPrompt "Do you want to change Apache 2 proccess running user and group to your user and group? " "y"
CHANGE_USER=$result

readPrompt "Do you want to set Apache 2 ServerName to 127.0.0.1:80? " "y"
CHANGE_SERVER_NAME=$result

readPrompt "Do you want to activate virtual hosts in Apache 2? " "y"
ACTIVATE_VIRTUAL_HOSTS=$result

readPrompt "Do you want to create virtual hosts for localhost? " "y"
LOCALHOST_VIRTUAL_HOST=$result

# Download the MacPort software for the currern Mac OS X version
# Manual download in http://www.macports.org/install.php
VERSION=`sw_vers -productVersion`
VERSION=${VERSION:3:1}
if [ "$VERSION" == "6" ]; then
  URL=https://distfiles.macports.org/MacPorts/MacPorts-2.1.2-10.7-Lion.pkg
elif [ "$VERSION" == "7" ]; then
  URL=https://distfiles.macports.org/MacPorts/MacPorts-2.1.2-10.6-SnowLeopard.pkg
elif [ "$VERSION" == "8" ]; then
  URL=https://distfiles.macports.org/MacPorts/MacPorts-2.1.2-10.8-MountainLion.pkg
fi
if [ "$URL" == "" ]; then
  echo "MacPort can only be installed automatically in Mac OS X 10.6, 10.7 o 10.8"
  exit
fi
curl -O $URL
FILE_NAME=`echo $URL | sed -e "s/\https:\/\/distfiles.macports.org\/MacPorts\///g"`
sudo installer -pkg $FILE_NAME -target /

# Update MacPorts package database
sudo port -d selfupdate

# Install Apache 2
sudo port install apache2

if [ $AUTORUN == "y" ]; then
  # Make Apache 2 autorun on boot
  # This creates the file /Library/LaunchDaemons/org.macports.apache2.plist
  sudo port load apache2
else
  # Run the Apache 2 service
  sudo /opt/local/etc/LaunchDaemons/org.macports.apache2/apache2.wrapper start
fi

# Install MySQL 5
sudo port install mysql5-server

# Configure the MySQL 5 database files and folders
sudo -u _mysql mysql_install_db5
sudo chown -R mysql:mysql /opt/local/var/db/mysql5/
sudo chown -R mysql:mysql /opt/local/var/run/mysql5/
sudo chown -R mysql:mysql /opt/local/var/log/mysql5/

if [ $AUTORUN == "y" ]; then
  # Make MySQL 5 autorun on boot
  # This creates the file /Library/LaunchDaemons/org.macports.mysql5.plist
  sudo port load mysql5-server
else
  # Run the MySQL 5 service
  sudo /opt/local/etc/LaunchDaemons/org.macports.mysql5/mysql5.wrapper start
fi

# Secure MySQL 5 configuration
# root password in blank by default
# This is an optional step that changes root password, deletes anonymous users,
# disables remote logins for root user and deletes the test database
# If you only want to change root password run this command:
# $ mysqladmin5 -u root -p password <your-password>
if [ $SECURE == "y" ]; then
  /opt/local/bin/mysql_secure_installation5
fi

# Install PHP 5.3
sudo port install php5 +apache2 +pear
sudo port install php5-mysql php5-sqlite php5-xdebug php5-mbstring php5-iconv php5-posix php5-apc

# Register PHP 5.3 with Apache 2
cd /opt/local/apache2/modules
sudo /opt/local/apache2/bin/apxs -a -e -n "php5" libphp5.so

# Create the php.ini file from the development template
cd /opt/local/etc/php5
sudo cp php.ini-development php.ini

# Configure the timezone and the socket of MySQL in /opt/local/etc/php5/php.ini
TIMEZONE=`systemsetup -gettimezone | awk '{ print $3 }'`
TIMEZONE=$(printf "%s\n" "$TIMEZONE" | sed 's/[][\.*^$/]/\\&/g')
sudo sed \
  -e "s/;date.timezone =/date.timezone = \"$TIMEZONE\"/g" \
  -e "s#pdo_mysql\.default_socket.*#pdo_mysql\.default_socket=`/opt/local/bin/mysql_config5 --socket`#" \
  -e "s#mysql\.default_socket.*#mysql\.default_socket=`/opt/local/bin/mysql_config5 --socket`#" \
  -e "s#mysqli\.default_socket.*#mysqli\.default_socket=`/opt/local/bin/mysql_config5 --socket`#" \
  php.ini > /tmp/php.ini
sudo chown root:admin /tmp/php.ini
sudo mv /tmp/php.ini ./

# Include PHP 5.3 in Apache 2 configuration
sudo echo "" | sudo tee -a /opt/local/apache2/conf/httpd.conf
sudo echo "Include conf/extra/mod_php.conf" | sudo tee -a /opt/local/apache2/conf/httpd.conf

if [ $CHANGE_USER == "y" ]; then
  # Change the user and group of the Apache 2 proccess to current user
  # By default it is www:www
  sudo sed \
    -e 's/User www/User `id -un`/g' \
    -e 's/Group www/Group `id -gn`/g' \
    /opt/local/apache2/conf/httpd.conf > /tmp/httpd.conf
  sudo chown root:admin /tmp/httpd.conf
  sudo mv /tmp/httpd.conf /opt/local/apache2/conf/httpd.conf
fi

if [ $CHANGE_SERVER_NAME == "y" ]; then
  # If you don't want to have the next warning:
  # httpd: Could not reliably determine the server's fully qualified domain name, using enekochans-Mac-mini.local for ServerName
  # Fix it by filling the ServerName option in httpd.conf with 127.0.0.1:80
  sudo sed \
    -e 's/#ServerName www.example.com:80/ServerName 127.0.0.1:80/g' \
    /opt/local/apache2/conf/httpd.conf > /tmp/httpd.conf
  sudo chown root:admin /tmp/httpd.conf
  sudo mv /tmp/httpd.conf /opt/local/apache2/conf/httpd.conf
fi

if [ $ACTIVATE_VIRTUAL_HOSTS == "y" ]; then
  sudo sed \
    -e 's/#Include conf\/extra\/httpd-vhosts.conf/Include conf\/extra\/httpd-vhosts.conf/g' \
    /opt/local/apache2/conf/httpd.conf > /tmp/httpd.conf
  sudo chown root:admin /tmp/httpd.conf
  sudo mv /tmp/httpd.conf /opt/local/apache2/conf/httpd.conf
fi

if [ $LOCALHOST_VIRTUAL_HOST ]; then
  echo "" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "<VirtualHost *:80>" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "    ServerAdmin webmaster@localhost" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "    DocumentRoot \"/opt/local/apache2/htdocs\"" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "    ServerName localhost" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "    ServerAlias localhost" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "    ErrorLog \"logs/localhost-error_log\"" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "    CustomLog \"logs/localhost-access_log\" common" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "</VirtualHost>" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
  echo "" | sudo tee -a /opt/local/apache2/conf/extra/httpd-vhosts.conf
fi

# Restart Apache 2
sudo /opt/local/apache2/bin/apachectl -k restart