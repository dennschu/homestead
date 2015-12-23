#!/usr/bin/env bash
#===================================================================================
#
# FILE: xdebug-enable.sh
#
# USAGE: xdebug-enable.sh [enable xdebug] [enable xdebug cli] [enable script debug mode]
#
# DESCRIPTION:
#
# OPTIONS:
#   1: "true|false" - enable xdebug for fpm
#   2: "true|false" - enable xdebug for cli
#   3: "true|false" - enable script debug mode
#===================================================================================

#----------------------------------------------------------------------
# Script Arguments
#----------------------------------------------------------------------
FPM_XDEBUG_ENABLED=$1
CLI_XDEBUG_ENABLED=$2
DEBUG_MODE=""
if [[ $3 == "true" ]]; then
  DEBUG_MODE="true"
fi

#----------------------------------------------------------------------
# Script Variables
#----------------------------------------------------------------------
CONFD_CLI_PATH="/etc/php/7.0/cli/conf.d"
CONFD_FPM_PATH="/etc/php/7.0/fpm/conf.d"
MODS_PATH="/etc/php/mods-available"

DEFAULT_CONFIG_FILENAME_PRIO="20"
DEFAULT_CONFIG_FILENAME="xdebug.ini"
CUSTOM_CONFIG_FILENAME_PRIO="21"
CUSTOM_CONFIG_FILENAME="xdebug-custom-config.ini"
CUSTOM_CONFIG=$(cat << EOT
[XDEBUG]
xdebug.remote_connect_back=1
xdebug.default_enable=1
xdebug.remote_autostart=0
xdebug.remote_enable=1
xdebug.remote_port=9000
xdebug.remote_handler=dbgp
EOT
)

#=== FUNCTION ================================================================
# NAME: cleanup
# DESCRIPTION: removes file at given path for optionally prioritized filename
# PARAMETER 1: path
# PARAMETER 2: filename
# PARAMETER 3: priority - that is used with php mods
#===============================================================================
cleanup() {
  local path="${1}"
  local filename="${2}"
  local priority=""

  if [[ $3 != "" ]]; then
    priority="${3}-"
  fi

  cd "${path}"

  if [ -f "${priority}${filename}" ]; then
    rm "${priority}${filename}"

    if [[ $DEBUG_MODE == "true" ]]; then
      echo "!-- rm: $(pwd)/${priority}${filename}"
    fi

  fi
}


#=== FUNCTION ================================================================
# NAME: enable_mod
# DESCRIPTION: symlinks a php mod to path
# PARAMETER 1: path
# PARAMETER 2: filename
# PARAMETER 3: priority - that is used with php mods
# PARAMETER 4: mod_path
#===============================================================================
enable_mod() {
  local path="${1}"
  local filename="${2}"
  local priority=""
  local mods_path="${4}"

  if [[ $3 != "" ]]; then
    priority="${3}-"
  fi

  cd "${path}"
  ln -s "${mods_path}/${filename}" "${priority}${filename}"

  if [[ $DEBUG_MODE == "true" ]]; then
    echo "!!- cd: ${path}"
    echo "!!! ln -s: ${mods_path}/${filename}" "${priority}${filename}"
  fi
}


#----------------------------------------------------------------------
# remove all symlinked xdebug mods for cli & fpm
#----------------------------------------------------------------------
cleanup "${CONFD_CLI_PATH}" "${DEFAULT_CONFIG_FILENAME}" "${DEFAULT_CONFIG_FILENAME_PRIO}"
cleanup "${CONFD_CLI_PATH}" "${CUSTOM_CONFIG_FILENAME}" "${CUSTOM_CONFIG_FILENAME_PRIO}"

cleanup "${CONFD_FPM_PATH}" "${DEFAULT_CONFIG_FILENAME}" "${DEFAULT_CONFIG_FILENAME_PRIO}"
cleanup "${CONFD_FPM_PATH}" "${CUSTOM_CONFIG_FILENAME}" "${CUSTOM_CONFIG_FILENAME_PRIO}"

cleanup "${MODS_PATH}" "${CUSTOM_CONFIG_FILENAME}" ""


#----------------------------------------------------------------------
# Set Custom xdebug configuration
#----------------------------------------------------------------------
echo "${CUSTOM_CONFIG}" > "${MODS_PATH}/${CUSTOM_CONFIG_FILENAME}"


#----------------------------------------------------------------------
# Conditionally enable xdebug for CLI
#----------------------------------------------------------------------
if [[ $CLI_XDEBUG_ENABLED == 'true' ]]; then
  enable_mod "${CONFD_CLI_PATH}" "${DEFAULT_CONFIG_FILENAME}" "${DEFAULT_CONFIG_FILENAME_PRIO}" "${MODS_PATH}"
  enable_mod "${CONFD_CLI_PATH}" "${CUSTOM_CONFIG_FILENAME}" "${CUSTOM_CONFIG_FILENAME_PRIO}" "${MODS_PATH}"
fi


#----------------------------------------------------------------------
# Conditionally enable xdebug for FPM
#----------------------------------------------------------------------
if [[ $FPM_XDEBUG_ENABLED == 'true' ]]; then
  enable_mod "${CONFD_FPM_PATH}" "${DEFAULT_CONFIG_FILENAME}" "${DEFAULT_CONFIG_FILENAME_PRIO}" "${MODS_PATH}"
  enable_mod "${CONFD_FPM_PATH}" "${CUSTOM_CONFIG_FILENAME}" "${CUSTOM_CONFIG_FILENAME_PRIO}" "${MODS_PATH}"
fi


#----------------------------------------------------------------------
# Apply changed FPM Configuration
#----------------------------------------------------------------------
service php7.0-fpm restart
