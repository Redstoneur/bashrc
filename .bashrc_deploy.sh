#!/bin/bash

remote="https://github.com/Redstoneur/bashrc"

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

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}

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

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}

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

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}

function deployer() {
  local install_flag=0 update_flag=0 uninstall_flag=0 version=""

  if [[ $# -eq 0 ]]; then
    echo "Aucun paramètre fourni."
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
          echo "Erreur: l'option --version requiert un argument." >&2
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

deployer "$@"



