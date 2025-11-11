# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# Portable additions: guarded and portable across distributions
# Only run for interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# History: avoid duplicates and append new entries
: ${HISTCONTROL:="ignoreboth"}
shopt -s histappend 2>/dev/null || true
: ${HISTSIZE:=1000}
: ${HISTFILESIZE:=2000}

# Update terminal size after each command
shopt -s checkwinsize 2>/dev/null || true

# Use lesspipe if available to preprocess files for less
if [ -x /usr/bin/lesspipe ]; then
    eval "$(SHELL=/bin/sh lesspipe)" 2>/dev/null || true
fi

# Enable color support for ls/grep if dircolors is available
if command -v dircolors >/dev/null 2>&1; then
    if [ -r "$HOME/.dircolors" ]; then
        eval "$(dircolors -b \"$HOME/.dircolors\")"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Enable bash-completion if available (portable check)
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
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
