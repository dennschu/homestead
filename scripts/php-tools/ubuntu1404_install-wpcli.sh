#!/usr/bin/env bash

#=== FUNCTION ================================================================
# NAME: defaults
# DESCRIPTION: return always a valid default
# PARAMETER 1: default value
# PARAMETER 2: optional value
#===============================================================================
defaults() {
  if [[ $2 != "" ]]; then
    echo "${2}"
  else
    echo "${1}"
  fi
}


#=== FUNCTION ================================================================
# NAME: log
# DESCRIPTION: logging function that prints out valuable information based
#              on global 'DEBUG_MODE' variable
# PARAMETER 1: message to log
# PARAMETER 2: "true" is it an error
#===============================================================================
log() {
  if [[ "${2}" == "error" ]]; then
    DEBUG_MODE="true"
  fi

  if [[ "${DEBUG_MODE}" == "true" ]]; then
    echo -e "\e[31m" "${1}" "\e[39m"
  fi
}

#----------------------------------------------------------------------
# Variable Declarations
#----------------------------------------------------------------------
DEBUG_MODE="$(defaults "true" "${1}")"
WPCLI_URL="https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
TARGET_FILE_LOCATION="/usr/local/bin/wp"

log "### Install WPCLI to: '${TARGET_FILE_LOCATION}'"

log "- Install WPCLI from '${WPCLI_URL}' to '${TARGET_FILE_LOCATION}'"
curl -o "${TARGET_FILE_LOCATION}" "${WPCLI_URL}" &>/dev/null

log "- Change execution bit of '${TARGET_FILE_LOCATION}'"
chmod +x "${TARGET_FILE_LOCATION}"
