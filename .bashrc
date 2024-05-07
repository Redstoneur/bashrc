# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# @source
# Name: exports
# Description: Source the exports file
source ./.shells/exports

# @source
# Name: alias
# Description: Source the alias file
source ./.shells/alias

# @source
# Name: functions
# Description: Source the functions file
source ./.shells/functions
