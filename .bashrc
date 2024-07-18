# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# @source
# Name: exports
# Description: Source the exports file
source "$HOME/.shells/exports"

# @source
# Name: alias
# Description: Source the alias file
source "$HOME/.shells/alias"

# @source
# Name: functions
# Description: Source the functions file
source "$HOME/.shells/functions"
