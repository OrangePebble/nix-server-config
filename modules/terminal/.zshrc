zvm_before_init() {
    # I don't want everything I delete/yank to go to the clipboard.
    # ZVM_SYSTEM_CLIPBOARD_ENABLED=true
    # Set cursors to blink.
    ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
    ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
    ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
    ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
    ZVM_REPLACE_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
    ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
    # Change visual highlighting.
    ZVM_VI_HIGHLIGHT_FOREGROUND=#f2f4f8
    ZVM_VI_HIGHLIGHT_BACKGROUND=#2a2a2a
}

# https://github.com/junegunn/fzf/issues/4042
# Make Ctrl+R work in insert mode.
zvm_after_init_commands+=('source <(fzf --zsh)')

source "$ZSH_VI_MODE_PLUGIN_FILE"
