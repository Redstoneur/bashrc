#!/bin/bash
# File: .bashrc_local_deploy.sh
#
# Description:
#   Local deployment helper script to install, update or uninstall a set of
#   bash configuration files (.bashrc and .shells) from the current working
#   directory into the user's $HOME directory.
#
# Behavior:
#   - creates backups under $HOME/.bashrc_backups (initial or timestamped)
#   - copies ./ .bashrc and .shells from the current working directory into $HOME
#   - writes a version/ref marker to $HOME/.bashrc_version when applicable
#   - sources the newly installed $HOME/.bashrc and execs a login shell to apply changes
#
# Requirements:
#   - no external commands are strictly required for the local helper (unlike the
#     remote deployment helper which requires 'git').
#
# Safety / side effects:
#   - modifies files under $HOME (.bashrc, .shells, .bashrc_backups, .bashrc_version)
#   - may replace the current shell process by calling `exec "$SHELL" -l`
#   - intended for local, offline deployments where repository cloning is not required
#
# Usage examples:
#   ./.bashrc_local_deploy.sh --install
#   ./.bashrc_local_deploy.sh --install v1.0-local
#   ./.bashrc_local_deploy.sh --update v1.0-local
#   ./.bashrc_local_deploy.sh --uninstall
#
# Options:
#   --install [ref]   Perform a fresh install from the current directory. Optionally specify a ref/tag/marker.
#   --update [ref]    Update an existing installation using files from the current directory.
#   --uninstall       Remove deployed files and restore the initial backup (if present).
#   --help, -h        Show this help message and exit.
#
# Exit codes:
#   0 on success, non-zero on failure.

# help: print usage information.
# This function simply prints the script usage and supported options.
# It is informational only and does not modify any files.
function help() {
  echo "Usage: ./.bashrc_local_deploy.sh [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help         Show this help message and exit"
  echo "  --install [ref]    Install the local files to \$HOME (optional ref marker)"
  echo "  --update [ref]     Update an existing local installation (optional ref marker)"
  echo "  --uninstall        Uninstall and attempt to restore the initial backup"
  echo ""
  echo "Examples:"
  echo "  ./.bashrc_local_deploy.sh --install"
  echo "  ./.bashrc_local_deploy.sh --update my-local-ref"
  echo "  ./.bashrc_local_deploy.sh --uninstall"
  return 0
}

# install: perform a fresh installation from the current directory.
#
# Signature: install <ref>
#   ref (optional) - textual marker to write to $HOME/.bashrc_version (for tracking)
#
# Steps:
#   1. refuse if a .bashrc_version file already exists (prevents accidental re-install)
#   2. create an initial backup directory and save existing .bashrc/.shells
#   3. copy new .bashrc and .shells into $HOME
#   4. source the new .bashrc; on failure, restore the backup and abort
#   5. write the deployed version into $HOME/.bashrc_version
#   6. exec a login shell to apply changes
#
# Exit codes:
#   0 on success, non-zero on failure.
function install() {
  local latest_tag="$1"
  local home_bashrc home_shells

  home_bashrc="$HOME/.bashrc"
  home_shells="$HOME/.shells"

  # Check if version file exists
  if [ -f "$HOME/.bashrc_version" ]; then
    echo ".bashrc is already deployed. Use --update to update."
    return 1
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
  cp -r ./.bashrc "$home_bashrc" || { echo "Failed to copy .bashrc. Aborting."; return 1; }
  cp -r ./.shells "$home_shells" || { echo "Failed to copy .shells. Aborting."; return 1; }

  # Source the new .bashrc
  # shellcheck disable=SC1090
  if ! source "$home_bashrc"; then
    echo "Failed to source new .bashrc. Aborting."
    cd || return 1
    # Restore previous files from backup
    rm -rf "$home_bashrc" "$home_shells"
    cp -r "$HOME/.bashrc_backups/initial/.bashrc" "$home_bashrc" || echo "Failed to restore $HOME/.bashrc from backup"
    if [ -d "$HOME/.bashrc_backups/initial/.shells" ];
    then
      cp -r "$HOME/.bashrc_backups/initial/.shells" "$home_shells" || echo "Failed to restore $HOME/.shells from backup"
    fi
    echo "Restored previous $HOME/.bashrc and $HOME/.shells from backup."
    return 1
  fi

  echo "Installation completed. Initial backup created at $HOME/.bashrc_backups/initial"

  # Clean up
  cd || return 1

  # Save the current version
  echo "$latest_tag" > "$HOME/.bashrc_version" 2>/dev/null

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}



# Local update: update an existing deployment using files from the current directory.
#
# Signature: update <ref>
#   ref (optional) - textual marker to write to $HOME/.bashrc_version (for tracking)
#
# Behaviour:
#   - require an existing installation by checking $HOME/.bashrc_version
#   - create a timestamped backup under $HOME/.bashrc_backups/<timestamp>
#   - replace .bashrc and .shells with files from the current directory
#   - on failure restore the timestamped backup
#   - record the ref marker (or "local") into $HOME/.bashrc_version
function update() {
  local ref="$1"
  local home_bashrc home_shells ts

  home_bashrc="$HOME/.bashrc"
  home_shells="$HOME/.shells"
  ts=$(date +"%Y%m%d_%H%M%S")

  if [ ! -f "$HOME/.bashrc_version" ]; then
    echo "No existing installation found. Please install first before updating. Aborting."
    return 1
  fi

  # Create a timestamped backup of current files
  mkdir -p "$HOME/.bashrc_backups/$ts" || { echo "Failed to create backup directory. Aborting."; return 1; }
  if [ -f "$home_bashrc" ]; then
    cp -r "$home_bashrc" "$HOME/.bashrc_backups/$ts/" || { echo "Failed to backup .bashrc. Aborting."; return 1; }
  fi
  if [ -d "$home_shells" ]; then
    cp -r "$home_shells" "$HOME/.bashrc_backups/$ts/" || { echo "Failed to backup .shells. Aborting."; return 1; }
  fi

  # Replace files from current directory
  rm -rf "$home_bashrc" "$home_shells"
  cp -r ./.bashrc "$home_bashrc" || { echo "Failed to copy new .bashrc. Aborting."; return 1; }
  cp -r ./.shells "$home_shells" || { echo "Failed to copy new .shells. Aborting."; return 1; }

  # Source the new .bashrc
  # shellcheck disable=SC1090
  if ! source "$home_bashrc"; then
    echo "Failed to source new .bashrc. Aborting."
    # Restore previous files from backup
    rm -rf "$home_bashrc" "$home_shells"
    cp -r "$HOME/.bashrc_backups/$ts/.bashrc" "$home_bashrc" || echo "Failed to restore $HOME/.bashrc from backup"
    if [ -d "$HOME/.bashrc_backups/$ts/.shells" ]; then
      cp -r "$HOME/.bashrc_backups/$ts/.shells" "$home_shells" || echo "Failed to restore $HOME/.shells from backup"
    fi
    echo "Restored previous $HOME/.bashrc and $HOME/.shells from backup."
    return 1
  fi

  # Record the ref (if any)
  if [ -n "$ref" ]; then
    echo "$ref" > "$HOME/.bashrc_version" 2>/dev/null
  else
    echo "local" > "$HOME/.bashrc_version" 2>/dev/null
  fi

  echo "Update completed. Backup created at $HOME/.bashrc_backups/$ts"

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}


# Local uninstall: remove the deployed files and try to restore the initial backup.
#
# Behaviour:
#   - verify there is an installation by checking $HOME/.bashrc_version
#   - remove deployed files and the version marker
#   - restore initial backup if it exists and remove that backup dir
#   - source restored .bashrc and exec a login shell
function uninstall() {
  local home_bashrc home_shells
  home_bashrc="$HOME/.bashrc"
  home_shells="$HOME/.shells"

  if [ ! -f "$HOME/.bashrc_version" ]; then
    echo "No existing installation found. Aborting."
    return 1
  fi

  # Remove deployed files
  rm -rf "$home_bashrc" || { echo "Failed to remove $home_bashrc. Aborting."; return 1; }
  rm -rf "$home_shells" || { echo "Failed to remove $home_shells. Aborting."; return 1; }

  # Remove version file
  rm -f "$HOME/.bashrc_version" 2>/dev/null

  # Restore initial backup if present
  if [ -d "$HOME/.bashrc_backups/initial" ]; then
    cp -r "$HOME/.bashrc_backups/initial/.bashrc" "$home_bashrc" || echo "Failed to restore $home_bashrc from backup"
    if [ -d "$HOME/.bashrc_backups/initial/.shells" ]; then
      cp -r "$HOME/.bashrc_backups/initial/.shells" "$home_shells" || echo "Failed to restore $home_shells from backup"
    fi
    echo "Restored initial backup from $HOME/.bashrc_backups/initial"
  else
    echo "No initial backup found. Deployment files removed."
    return 1
  fi

  # Remove initial backup after restoration
  rm -rf "$HOME/.bashrc_backups/initial"

  # shellcheck disable=SC1090
  if ! source "$home_bashrc"; then
    echo "Failed to source restored .bashrc. Aborting."
    return 1
  fi

  # Delete the local deploy script if invoked from it
  rm -- "$0" 2>/dev/null || true

  # Restart the shell to apply changes
  exec "$SHELL" -l

  return 0
}


# deployer: parse CLI arguments and call the appropriate action.
#
# Supported flags:
#   --install    : perform a fresh install
#   --update     : update existing installation
#   --uninstall  : uninstall the deployment
#
# Notes:
#   - The local helper accepts simple, mutually exclusive actions: install, update, uninstall.
#   - When a ref is supplied it is used only as a textual marker written into $HOME/.bashrc_version
function deployer() {
  local cmd ref

  cmd="$1"
  ref="$2"

  case "$cmd" in
    --help|-h)
      help
      ;;
    --install)
      install "$ref"
      ;;
    --update)
      update "$ref"
      ;;
    --uninstall)
      uninstall
      ;;
    *)
      echo "Usage: $0 --install [ref]"
      echo "       $0 --update [ref]"
      echo "       $0 --uninstall"
      echo "       $0 --help"
      return 1
      ;;
  esac
}

# Entrypoint: forward all CLI args to deployer

deployer "$@"
