#!/usr/bin/env bash
#===================================================================================
#
# FILE: xdebug-install.sh
#
# USAGE: xdebug-install.sh
#
# DESCRIPTION: provisions an ubuntu 14.04 with PHP 7.0 with xdebug#
#===================================================================================

#----------------------------------------------------------------------
# Add ppa for backported xdebug that is compatible with php 7.0
#----------------------------------------------------------------------
apt-get install -y language-pack-en-base &>/dev/null
LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php-7.0 -y &>/dev/null

#----------------------------------------------------------------------
# Install xdebug
#----------------------------------------------------------------------
apt-get install php-xdebug -y

#----------------------------------------------------------------------
# Apply changed FPM Configuration
#----------------------------------------------------------------------
service php7.0-fpm restart
