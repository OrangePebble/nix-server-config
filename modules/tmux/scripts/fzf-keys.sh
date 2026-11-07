#!/usr/bin/env bash

comm -23 <(tmux list-keys -Na | sort) <(tmux -L test -f /dev/null list-keys -Na | sort) | cut -c-"$(tput cols)" | fzf -e -i --prompt="tmux hotkeys: " --info=inline --layout=reverse --scroll-off=5 --tiebreak=index --header "prefix=yes-prefix root=no-prefix" >/dev/null
