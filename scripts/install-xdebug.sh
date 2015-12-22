#!/usr/bin/env bash

echo "------------------------------------------------------------"
echo "Try to install xdebug for php 7"
echo "------------------------------------------------------------"

# add php 7.0 back port repository
apt-get install -y language-pack-en-base
LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php-7.0 -y

# install xdebug
apt-get install php-xdebug -y

XDEBUG_CUSTOM_CONFIG_FILENAME="zzzz_xdebug-config.ini"

# configure xdebug
XDEBUG_CUSTOM_CONFIG=$(cat << EOT
[XDEBUG]
xdebug.remote_connect_back=1
xdebug.default_enable=1
xdebug.remote_autostart=0
xdebug.remote_enable=1
;xdebug.profiler_output_dir=/var/www/_logs
xdebug.profiler_enable_trigger=1
xdebug.profiler_enable=0
xdebug.profiler_output_name=callgrind.%R.%t
xdebug.remote_port=9000
xdebug.remote_handler=dbgp
EOT
)

echo "${XDEBUG_CUSTOM_CONFIG}" > /etc/php/mods-available/$XDEBUG_CUSTOM_CONFIG_FILENAME

# enable xdebug
if [ -d /etc/php/7.0/fpm/conf.d ]; then
  cd /etc/php/7.0/fpm/conf.d;

  # remove existing symbolic link to config
  if [ -f $XDEBUG_CUSTOM_CONFIG_FILENAME ]; then
    rm $XDEBUG_CUSTOM_CONFIG_FILENAME;
  fi

  ln -s /etc/php/mods-available/$XDEBUG_CUSTOM_CONFIG_FILENAME $XDEBUG_CUSTOM_CONFIG_FILENAME
else
  echo "Could not link xdebug configuration"
  exit 1
fi

# restart fpm
service php7.0-fpm restart
