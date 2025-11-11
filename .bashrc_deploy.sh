#!/bin/bash
# File: .bashrc_deploy.sh
#
# Description:
#   Deployment helper script to install, update or uninstall a set of bash
#   configuration files (.bashrc and .shells) from a remote git repository.
#
# Behavior:
#   - clone the remote repository into /tmp/bashrc-upgrade
#   - checkout a specific ref (tag, branch or commit) when provided
#   - backup existing files into $HOME/.bashrc_backups/<timestamp|initial>
#   - copy deployed files to $HOME and write a version marker to
#     $HOME/.bashrc_version
#   - source the new .bashrc and exec a login shell to apply changes
#
# Safety / side effects:
#   - requires 'git' to be available in PATH
#   - creates, overwrites and removes files under $HOME (.bashrc, .shells,
#     .bashrc_backups, .bashrc_version)
#   - will exec "$SHELL" -l at the end of install/update/uninstall which
#     replaces the current process if successful
#
# Usage examples:
#   ./deploy.sh --install --version v1.2.3
#   ./deploy.sh --update --version master
#   ./deploy.sh --uninstall

remote="https://github.com/Redstoneur/bashrc"

# help: print usage information.
#
# This function simply prints the script usage and supported options.
# It is informational only and does not modify any files.
function help() {
  echo "Usage: ./deploy.sh [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help         Show this help message and exit"
  echo "  -i, --install      Install dependencies before deployment"
  echo "  -up, --update      Update existing deployment"
  echo "  -un, --uninstall   Uninstall the deployment"
  echo "  -v, --version VER  [OPTIONAL] Specify the version to deploy (default: master or latest tag)"
  echo ""
  echo "Example:"
  echo "  ./deploy.sh --install --version v1.2.3"
  echo "  ./deploy.sh -up --version master"
  echo "  ./deploy.sh --uninstall"
}

# install: perform a fresh installation from the remote repository.
#
# Signature: install <ref>
#   ref (optional) - git reference to checkout (tag, branch or commit)
#
# Steps performed:
#   1. refuse if a .bashrc_version file already exists (prevents accidental re-install)
#   2. ensure 'git' is available
#   3. clone the remote repo to /tmp/bashrc-upgrade and checkout the chosen ref
#   4. create an initial backup directory and save existing .bashrc/.shells
#   5. copy new .bashrc and .shells into $HOME
#   6. source the new .bashrc; on failure, restore the backup and abort
#   7. write the deployed version into $HOME/.bashrc_version
#   8. exec a login shell to apply changes
#
# Exit codes:
#   0 on success, non-zero on failure.
function install() {
  local ref="$1"
  local home_bashrc home_shells latest_tag

  home_bashrc="$HOME/.bashrc"
  home_shells="$HOME/.shells"

  # Check if version file exists
  if [ -f "$HOME/.bashrc_version" ]; then
    echo ".bashrc is already deployed. Use --update to update."
    return 1
  fi

  # Check git available
  if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed or not in PATH. Aborting."
    return 1
  fi

  git clone "$remote" /tmp/bashrc-upgrade
  if [ $? -ne 0 ]; then
    echo "Failed to clone repository. Aborting."
    return 1
  fi

  cd /tmp/bashrc-upgrade || return 1

  if [ -n "$ref" ]; then
    git checkout "$ref"
    if [ $? -ne 0 ]; then
      echo "Failed to checkout ref '$ref'. Aborting."
      rm -rf /tmp/bashrc-upgrade
      return 1
    fi
    latest_tag="$ref"
  else
    latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null)
    if [ -n "$latest_tag" ]; then
      git checkout "$latest_tag"
    else
      if git show-ref --verify --quiet refs/heads/master; then
        git checkout master
      else
        echo "No tags or master branch found. Aborting."
        rm -rf /tmp/bashrc-upgrade
        return 1
      fi
    fi
  fi

  # Create initial backup for .bashrc and .shells if they exist
  mkdir -p "$HOME/.bashrc_backups/initial" || { echo "Failed to create backup directory. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }
  if [ -f "$home_bashrc" ]; then
    cp -r "$home_bashrc" "$HOME/.bashrc_backups/initial"
  fi
  if [ -d "$home_shells" ]; then
    cp -r "$home_shells" "$HOME/.bashrc_backups/initial"
  fi

  # Copy new files
  cp -r ./.bashrc "$home_bashrc" || { echo "Failed to copy .bashrc. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }
  cp -r ./.shells "$home_shells" || { echo "Failed to copy .shells. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }

  # Source the new .bashrc
  if ! source "$home_bashrc"; then
    echo "Failed to source new .bashrc. Aborting."
    cd || return 1
    rm -rf /tmp/bashrc-upgrade
    # Restore previous files from backup
    rm -rf "$home_bashrc" "$home_shells"
    cp -r "$HOME/.bashrc_backups/initial/.bashrc" "$home_bashrc" || echo "Failed to restore $HOME/.bashrc from backup"
    if [ -d "$HOME/.bashrc_backups/initial/.shells" ];
    then
      cp -r "$HOME/.bashrc_backups/initial/.shells" "$home_shells" || echo "Failed to restore $HOME/.shells from backup"
    fi
    rm -rf /tmp/bashrc-upgrade
    echo "Restored previous $HOME/.bashrc and $HOME/.shells from backup."
    return 1
  fi

  echo "Installation completed. Initial backup created at $HOME/.bashrc_backups/initial"

  # Clean up
  cd || return 1
  rm -rf /tmp/bashrc-upgrade
  # Save the current version
  echo "$latest_tag" > "$HOME/.bashrc_version" 2>/dev/null

  # Delete deploy script after installation
  rm -- "$0" 2>/dev/null

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}

# update: update an existing deployment to a new ref.
#
# Signature: update <ref>
#   ref (optional) - git reference to checkout. If not provided, the script
#   attempts to use the latest tag or master as a fallback.
#
# Steps performed:
#   - require an existing installation (checks $HOME/.bashrc_version)
#   - clone repo, checkout requested ref
#   - create a timestamped backup of current files
#   - replace files with new versions and source the .bashrc
#   - on failure restore the timestamped backup
#   - record the deployed version and exec a login shell
#
# Exit codes: 0 on success, non-zero otherwise.
function update() {
  local ref="$1"
  local home_bashrc home_shells ts latest_tag

  home_bashrc="$HOME/.bashrc"
  home_shells="$HOME/.shells"
  ts=$(date +"%Y%m%d_%H%M%S")

  # if version file does not exist, abort
  if [ ! -f "$HOME/.bashrc_version" ]; then
    echo "No existing installation found. Please install first before updating. Aborting."
    return 1
  fi

  # Check git available
  if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed or not in PATH. Aborting."
    return 1
  fi

  git clone "$remote" /tmp/bashrc-upgrade
  if [ $? -ne 0 ]; then
    echo "Failed to clone repository. Aborting."
    return 1
  fi

  cd /tmp/bashrc-upgrade || return 1

  if [ -n "$ref" ]; then
    git checkout "$ref"
    if [ $? -ne 0 ]; then
      echo "Failed to checkout ref '$ref'. Aborting."
      rm -rf /tmp/bashrc-upgrade
      return 1
    fi
    latest_tag="$ref"
  else
    latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null)
    if [ -n "$latest_tag" ]; then
      git checkout "$latest_tag"
    else
      if git show-ref --verify --quiet refs/heads/master; then
        git checkout master
      else
        echo "No tags or master branch found. Aborting."
        rm -rf /tmp/bashrc-upgrade
        return 1
      fi
    fi
  fi

  # Backup existing files
  mkdir -p "$HOME/.bashrc_backups/$ts" || { echo "Failed to create backup directory. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }
  cp -r "$home_bashrc" "$HOME/.bashrc_backups/$ts/" || { echo "Failed to backup .bashrc. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }
  cp -r "$home_shells" "$HOME/.bashrc_backups/$ts/" || { echo "Failed to backup .shells. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }

  # Replace files
  rm -rf "$home_bashrc"
  rm -rf "$home_shells"
  cp -r ./.bashrc "$home_bashrc" || { echo "Failed to copy new .bashrc. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }
  cp -r ./.shells "$home_shells" || { echo "Failed to copy new .shells. Aborting."; rm -rf /tmp/bashrc-upgrade; return 1; }

  # Source the new .bashrc
  if ! source "$home_bashrc"; then
    echo "Failed to source new .bashrc. Aborting."
    rm -rf /tmp/bashrc-upgrade
    # Restore previous files from backup
    rm -rf "$home_bashrc" "$home_shells"
    cp -r "$HOME/.bashrc_backups/$ts/.bashrc" "$home_bashrc" || echo "Failed to restore $HOME/.bashrc from backup"
    cp -r "$HOME/.bashrc_backups/$ts/.shells" "$home_shells" || echo "Failed to restore $HOME/.shells from backup"
    echo "Restored previous $HOME/.bashrc and $HOME/.shells from backup."
    return 1
  fi

  echo "Update completed. Backup created at $HOME/.bashrc_backups/$ts"

  # Clean up
  cd || return 1
  rm -rf /tmp/bashrc-upgrade

  # Update the file that contains the current bashrc version
  echo "$latest_tag" > "$HOME/.bashrc_version" 2>/dev/null || echo "unknown" > "$HOME/.bashrc_version" 2>/dev/null

  # Delete deploy script after installation
  rm -- "$0" 2>/dev/null

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}

# uninstall: remove the deployed files and try to restore the initial backup.
#
# Steps performed:
#   - verify there is an installation by checking $HOME/.bashrc_version
#   - remove deployed files and the version marker
#   - if an initial backup exists, restore it and remove the backup dir
#   - source the restored .bashrc and exec a login shell
#
# Exit codes: 0 on success, non-zero on failure.
function uninstall() {
  local home_bashrc home_shells
  home_bashrc="$HOME/.bashrc"
  home_shells="$HOME/.shells"

  # Check if version file exists
  if [ ! -f "$HOME/.bashrc_version" ]; then
    echo "No existing installation found. Aborting."
    return 1
  fi

  # Remove deployed files
  rm -rf "$home_bashrc" || { echo "Failed to remove $home_bashrc. Aborting."; return 1; }
  rm -rf "$home_shells" || { echo "Failed to remove $home_shells. Aborting."; return 1; }

  # Remove version file
  rm -f "$HOME/.bashrc_version" 2>/dev/null

  # Get initial backup if exists
  if [ -d "$HOME/.bashrc_backups/initial" ]; then
    cp -r "$HOME/.bashrc_backups/initial/.bashrc" "$home_bashrc" || echo "Failed to restore $home_bashrc from backup"
    if [ -d "$HOME/.bashrc_backups/initial/.shells" ];
    then
      cp -r "$HOME/.bashrc_backups/initial/.shells" "$home_shells" || echo "Failed to restore $home_shells from backup"
    fi
    echo "Restored initial backup from $HOME/.bashrc_backups/initial"
  else
    echo "No initial backup found. Deployment files removed."
    return 1
  fi

  # Remove initial backup after restoration
  rm -rf "$HOME/.bashrc_backups/initial"

  # Source the restored .bashrc
  if ! source "$home_bashrc"; then
    echo "Failed to source restored .bashrc. Aborting."
    return 1
  fi

  # Delete deploy script after installation
  rm -- "$0" 2>/dev/null

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}

# deployer: parse CLI arguments and call the appropriate action.
#
# Supported flags:
#   -i/--install    : perform a fresh install
#   -up/--update    : update an existing installation
#   -un/--uninstall : uninstall the deployment
#   -v/--version    : follow by a git ref for install/update
#
# The options --install, --update and --uninstall are mutually exclusive.
function deployer() {
  local install_flag=0 update_flag=0 uninstall_flag=0 version=""

  if [[ $# -eq 0 ]]; then
    echo "No parameters provided."
    help
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) help; return 0;;
      -i|--install) install_flag=1; shift;;
      -up|--update) update_flag=1; shift;;
      -un|--uninstall) uninstall_flag=1; shift;;
      -v|--version)
        if [[ -n "$2" && "$2" != -* ]]; then
          version="$2"; shift 2
        else
          echo "Error: --version option requires an argument." >&2
          return 1
        fi;;
      *) echo "Option inconnue: $1" >&2; help; return 1;;
    esac
  done

  if [[ $((install_flag + update_flag + uninstall_flag)) -gt 1 ]]; then
    echo "Erreur: Les options --install, --update et --uninstall sont mutuellement exclusives." >&2
    return 1
  fi

  if [[ -n "$version" && $uninstall_flag -eq 1 ]]; then
    echo "Erreur: L'option --version ne peut pas être utilisée avec --uninstall." >&2
    return 1
  fi

  if [[ $install_flag -eq 1 ]]; then
    install "$version" || return $?
  fi
  if [[ $update_flag -eq 1 ]]; then
    update "$version" || return $?
  fi
  if [[ $uninstall_flag -eq 1 ]]; then
    uninstall || return $?
  fi

  if [[ $install_flag -eq 0 && $update_flag -eq 0 && $uninstall_flag -eq 0 ]]; then
    echo "Aucune action spécifiée." >&2
    help
    return 1
  fi

  return 0
}

# Entrypoint: forward all CLI args to deployer

deployer "$@"

