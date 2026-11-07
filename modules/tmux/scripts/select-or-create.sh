#!/usr/bin/env bash
# Usage: tmux-select-or-create <window-target>
# Example: tmux-select-or-create 3
#          tmux-select-or-create session:2

# Try to create the window; if it already exists, just select it.
# Also refresh the status bar so changing to a remote SSH client immediatly shows.
tmux new-window -c "#{pane_current_path}" -t "$1" || tmux select-window -t "$1"; tmux move-window -r; tmux refresh-client -S
