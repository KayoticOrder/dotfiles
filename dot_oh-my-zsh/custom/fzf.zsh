# fzf fuzzy finder config

RG_PREFIX="rg --line-number --no-heading --color=always --smart-case --files"
INITIAL_QUERY="${*:-}"

export FZF_DEFAULT_COMMAND="fd --type f"

export FZF_DEFAULT_OPTS="
  --color=fg:#D6D2B6,bg:#1E1F29,hl:#DE6674
  --color=fg+:#D6D2B6,bg+:#2A2A36,hl+:#DE6674
  --color=info:#706F68,prompt:#F85B61,pointer:#F89C65
  --color=marker:#F89C65,spinner:#F89C65,header:#938AA9

  --border
  --preview='tree -C {}'
  --height 75%
  --reverse
"
export FZF_CTRL_R_OPTS="
  --height 50%
  --no-preview
"
