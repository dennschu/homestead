#!/usr/bin/env bash
#===================================================================================
#
# FILE: xdebug-profiler-enable.sh
#
# USAGE: xdebug-profiler-enable.sh \
#         [enable fpm profiler] \
#         [enable cli profiler] \
#         [output path] \
#         [output format] \
#         [debug mode]
#
# DESCRIPTION:
#
# OPTIONS:
#   1: "true|false" - enable profiler for fpm
#   2: "true|false" - enable profiler for cli
#   3: "output path"
#   4: "output filename format"
#   5: "true|false" - enable script debug mode
#===================================================================================


#----------------------------------------------------------------------
# Script Arguments
#----------------------------------------------------------------------
FPM_PROFILER_ENABLED=$1
CLI_PROFILER_ENABLED=$2
PROFILER_OUTPUT_PATH="/home/vagrant/logs"
if [[ $3 != "" ]]; then
  PROFILER_OUTPUT_PATH="${3}"
fi

PROFILER_OUTPUT_FILE_FORMAT="callgrind.%R.%t"
if [[ $4 != "" ]]; then
  PROFILER_OUTPUT_FILE_FORMAT="${4}"
fi

DEBUG_MODE=""
if [[ $5 == "true" ]]; then
  DEBUG_MODE="true"
fi

#----------------------------------------------------------------------
# Script Variables
#----------------------------------------------------------------------
CONFD_CLI_PATH="/etc/php/7.0/cli/conf.d"
CONFD_FPM_PATH="/etc/php/7.0/fpm/conf.d"
MODS_PATH="/etc/php/mods-available"

PROFILER_CONFIG_FILENAME_PRIO="22"
PROFILER_CONFIG_FILENAME="xdebug-profiler-config.ini"
PROFILER_CONFIG=$(cat << EOT
xdebug.profiler_output_dir="${PROFILER_OUTPUT_PATH}"
xdebug.profiler_output_name="${PROFILER_OUTPUT_FILE_FORMAT}"
xdebug.profiler_enable_trigger=1
xdebug.profiler_enable=1
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
# remove xdebug profiler mods for cli & fpm
#----------------------------------------------------------------------
cleanup "${CONFD_CLI_PATH}" "${PROFILER_CONFIG_FILENAME}" "${PROFILER_CONFIG_FILENAME_PRIO}"
cleanup "${CONFD_FPM_PATH}" "${PROFILER_CONFIG_FILENAME}" "${PROFILER_CONFIG_FILENAME_PRIO}"

cleanup "${MODS_PATH}" "${PROFILER_CONFIG_FILENAME}"


#----------------------------------------------------------------------
# Create directory for logs, if it does not exist
#----------------------------------------------------------------------
if [ ! -d "${PROFILER_OUTPUT_PATH}" ]; then
  mkdir "${PROFILER_OUTPUT_PATH}"
fi


#----------------------------------------------------------------------
# Set Custom xdebug profiler configuration
#----------------------------------------------------------------------
echo "${PROFILER_CONFIG}" > "${MODS_PATH}/${PROFILER_CONFIG_FILENAME}"

#----------------------------------------------------------------------
# Conditionally enable xdebug profiler for CLI
#----------------------------------------------------------------------
if [[ $CLI_PROFILER_ENABLED == 'true' ]]; then
  enable_mod "${CONFD_CLI_PATH}" "${PROFILER_CONFIG_FILENAME}" "${PROFILER_CONFIG_FILENAME_PRIO}" "${MODS_PATH}"
fi

if [[ $FPM_PROFILER_ENABLED == 'true' ]]; then
  enable_mod "${CONFD_FPM_PATH}" "${PROFILER_CONFIG_FILENAME}" "${PROFILER_CONFIG_FILENAME_PRIO}" "${MODS_PATH}"
fi


#----------------------------------------------------------------------
# Apply changed FPM Configuration
#----------------------------------------------------------------------
service php7.0-fpm restart
