#!/usr/bin/env bash
#===================================================================================
#
# FILE: ubuntu1404_add-nano-code-highlighting.sh
#
# USAGE: ubuntu1404_add-nano-code-highlighting.sh [user name] [debug mode enabled]
#
# DESCRIPTION:  Bash provisioning for ubuntu 14.04 LTS that installs nano code highlighting

# OPTIONS:
#   1: "string" - name of ubuntu user that should reveive nano heighlighting
#   2: "true|false|''" - enable Debug mode
#===================================================================================


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

#----------------------------------------------------------------------
# Variable Declarations
#----------------------------------------------------------------------
DEBUG_MODE="$(defaults "true" "${2}")"
USER_NAME="$(defaults "forge" "${1}")"
USER_HOME_PATH="/home/${USER_NAME}"
EXTENSION_INSTALL_PATH="${USER_HOME_PATH}/.nano"

EXTENSION_LIST_URL="http://wiki.ubuntuusers.de/_attachment?target=Nano/highlighterliste"
EXTENSION_URL_TEMPLATE="http://wiki.ubuntuusers.de/_attachment?target=Nano/::extension_name::.nanorc"
EXTENSION_CONFIG_URL="http://wiki.ubuntuusers.de/_attachment?target=Nano/.nanorc"

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

#=== FUNCTION ================================================================
# NAME: fetch_extension_list
# DESCRIPTION: fetches a list of available nano highlighting extensions
#
# PARAMETER 1: url where to receive the list
#===============================================================================
fetch_extension_list() {
  local url="${1}"
  log "- get nano extension list"
  local extension_list="$(wget "${url}" --quiet -O -)"
  log "- extension list: [${extension_list}]"
  echo "${extension_list}"
}


#=== FUNCTION ================================================================
# NAME: install_extension_from_url
# DESCRIPTION: Installs extension from url to given path
#
# PARAMETER 1: extension name
# PARAMETER 2: install path
# PARAMETER 3: url template where to fetch extension
#===============================================================================
install_extension_from_url() {
  local extension_name="${1}"
  local extension_path="${2}"
  local extension_url_template="${3}"
  local url="$(echo "${extension_url_template}" | sed 's|::extension_name::|'"${extension_name}"'|g')"

  log "- Fetch and install '${extension_name}' extension from '${url}'"
  wget "${url}" --quiet -O "${extension_path}/${extension_name}.nanorc"
}


#=== FUNCTION ================================================================
# NAME: install_extensions_from_list
# DESCRIPTION: Installs from url list
#
# PARAMETER 1: url of extension list
# PARAMETER 2: install path
# PARAMETER 3: url template where to fetch extension
#===============================================================================
install_extensions_from_list() {
  local extension_list_url="${1}"
  local extension_path="${2}"
  local extension_url_template="${3}"

  while read extension_name; do
    install_extension_from_url "${extension_name}" "${extension_path}" "${extension_url_template}"
  done < <(fetch_extension_list "${extension_list_url}")
}


#=== FUNCTION ================================================================
# NAME: register_extensions
# DESCRIPTION: Registers previously installed nano extensions
#
# PARAMETER 1: url of extension configuration
# PARAMETER 2: install path
#===============================================================================
register_extensions() {
  local extension_config_url="${1}"
  local extension_config_path="${2}"
  log "- Register Extensions"
  wget "${extension_config_url}" -O "${extension_config_path}/.nanorc"
}


#=== FUNCTION ================================================================
# NAME: create_nano_history
# DESCRIPTION: Create empty '.nano_history' in user home
#
# PARAMETER 1: user home path
#===============================================================================
create_nano_history() {
  local file_path="${1}/.nano_history"
  if [ ! -f "${file_path}" ]; then
    touch "${file_path}"
  fi
}


#=== FUNCTION ================================================================
# NAME: adjust_permissions_for_user
# DESCRIPTION: adjust nano configuration file permissions
#
# PARAMETER 1: username
# PARAMETER 2: user home path
#===============================================================================
adjust_permissions_for_user() {
  local username="${1}"
  local user_home_path="${2}"

  log "- Change owner: ${username} of '${user_home_path}/.nano'"
  chown "${username}" -R "${user_home_path}/.nano"
  log "- Change owner: ${username} of '${user_home_path}/.nanorc'"
  chown "${username}" "${user_home_path}/.nanorc"
  log "- Change owner: ${username} of '${user_home_path}/.nano_history'"
  chown "${username}" "${user_home_path}/.nano_history"
}


#----------------------------------------------------------------------
# Message
#----------------------------------------------------------------------
log "### Install nano code hightlighting to: '${EXTENSION_INSTALL_PATH}'"


#----------------------------------------------------------------------
# Cleanup, bring system in an idompotent state
#----------------------------------------------------------------------
rm -rf "${EXTENSION_INSTALL_PATH}"
rm -rf "${EXTENSION_INSTALL_PATH}/.nanorc"
rm -rf "${EXTENSION_INSTALL_PATH}/.nano_history"


#----------------------------------------------------------------------
# Create .nano settings directory for user
#----------------------------------------------------------------------
if [ ! -d "${EXTENSION_INSTALL_PATH}" ]; then
  log "- Create ${EXTENSION_INSTALL_PATH}"
  mkdir "${EXTENSION_INSTALL_PATH}"
fi


#----------------------------------------------------------------------
# Run
#----------------------------------------------------------------------
install_extensions_from_list "${EXTENSION_LIST_URL}" "${EXTENSION_INSTALL_PATH}" "${EXTENSION_URL_TEMPLATE}"
register_extensions "${EXTENSION_CONFIG_URL}" "${USER_HOME_PATH}"
create_nano_history "${USER_HOME_PATH}"
adjust_permissions_for_user "${USER_NAME}" "${USER_HOME_PATH}"
