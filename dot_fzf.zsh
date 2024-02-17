# Setup fzf
# ---------
if [[ ! "$PATH" == */home/kayotic/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/kayotic/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/kayotic/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/kayotic/.fzf/shell/key-bindings.zsh"
