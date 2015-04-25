#!/usr/bin/env bash

# Test if PHP is installed
php -v > /dev/null 2>&1
PHP_IS_INSTALLED=$?

# Test if HHVM is installed
hhvm --version > /dev/null 2>&1
HHVM_IS_INSTALLED=$?

# If HHVM is installed, assume PHP is *not*
[[ $HHVM_IS_INSTALLED -eq 0 ]] && { PHP_IS_INSTALLED=-1; }

echo ">>> Installing Nginx"

[[ -z $1 ]] && { echo "!!! IP address not set. Check the Vagrant file."; exit 1; }

if [[ -z $2 ]]; then
    public_folder="/vagrant"
else
    public_folder="$2"
fi

if [[ -z $3 ]]; then
    hostname=""
else
    # There is a space, because this will be suffixed
    hostname=" $3"
fi

if [[ -z $4 ]]; then
    github_url="https://raw.githubusercontent.com/fideloper/Vaprobash/master"
else
    github_url="$4"
fi

# Add repo for latest stable nginx
sudo add-apt-repository -y ppa:nginx/stable

# Update Again
sudo apt-get update

# Install Nginx
# -qq implies -y --force-yes
sudo apt-get install -qq nginx

# nginx.conf grab from gist
curl --silent -L https://gist.githubusercontent.com/jepezi/55314e4c4465e94530f8/raw/4a636d403e07832ee24e4ebc7d8d2ccc40562882/vn_nginx.conf | sudo tee /etc/nginx/nginx.conf

# Add vagrant user to www-data group
usermod -a -G www-data vagrant

# Nginx enabling and disabling virtual hosts
curl --silent -L $github_url/helpers/ngxen.sh > ngxen
curl --silent -L $github_url/helpers/ngxdis.sh > ngxdis
curl --silent -L $github_url/helpers/ngxcb.sh > ngxcb
sudo chmod guo+x ngxen ngxdis ngxcb
sudo mv ngxen ngxdis ngxcb /usr/local/bin

# Create Nginx Server Block named "vagrant" and enable it
sudo ngxcb -d $public_folder -s "$1.xip.io$hostname" -e

curl --silent -L https://gist.githubusercontent.com/jepezi/c8db7067cd40a2e27ee5/raw/6786e82eeb8ef9a2faf8a6aa63d6d5d2362c1357/vn_vagrant | sudo tee /etc/nginx/sites-available/vagrant

# Disable "default"
sudo ngxdis default

if [[ $HHVM_IS_INSTALLED -ne 0 && $PHP_IS_INSTALLED -eq 0 ]]; then
    # PHP-FPM Config for Nginx
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini

    sudo service php5-fpm restart
fi

sudo service nginx reload
