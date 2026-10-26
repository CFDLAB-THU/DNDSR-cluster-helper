# If not running interactively, do nothing.
case $- in
    *i*) ;;
    *) return ;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend
shopt -s checkwinsize

# Match the reviewed m8 prompt without depending on a site's /etc/bashrc.
if [[ -z ${debian_chroot:-} && -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi
dndsr_color_prompt=no
case ${TERM:-dumb} in
    xterm*|rxvt*|screen*|tmux*|linux|*-256color) dndsr_color_prompt=yes ;;
    dumb|'') ;;
    *)
        if command -v tput >/dev/null 2>&1 &&
            [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
            dndsr_color_prompt=yes
        fi
        ;;
esac
if [[ $dndsr_color_prompt == yes ]]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
case ${TERM:-dumb} in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
esac
unset dndsr_color_prompt

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

if [[ -x /usr/bin/dircolors ]]; then
    [[ -r ~/.dircolors ]] && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi
