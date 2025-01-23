# simple.zsh-theme

PROMPT='%B%F{magenta}%n%b %F{yellow}%~ $(git_prompt_info)%(?.%F{green}.%F{red})❯%f '
RPROMPT='%F{#727169}%*'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{blue}\uE0A0(%B%F{red}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY="%b%F{blue})%F{yellow}✗%f  "
ZSH_THEME_GIT_PROMPT_CLEAN="%b%F{blue}) "

ZSH_THEME_RUBY_PROMPT_PREFIX="%F{red}"
ZSH_THEME_RUBY_PROMPT_SUFFIX="%f"
