# Monster Linux prompt (bash): a clean two-line prompt.
#   ● monster  ~/Documents  main
#   ❯                       (turns red when the last command failed)
# Your own PS1 in ~/.bashrc still wins, because ~/.bashrc runs after this.
case $- in *i*) ;; *) return 0 2>/dev/null ;; esac
[ -n "${BASH_VERSION:-}" ] || return 0 2>/dev/null
__monster_rc=0
__monster_status() { __monster_rc=$?; }
__monster_git() { local b; b=$(git symbolic-ref --short HEAD 2>/dev/null) && printf '  \001\e[38;2;138;152;120m\002%s\001\e[0m\002' "$b"; }
__monster_arrow() { if [ "$__monster_rc" = 0 ]; then printf '\001\e[38;2;168;224;58m\002❯\001\e[0m\002'; else printf '\001\e[38;2;230;96;84m\002❯\001\e[0m\002'; fi; }
__MONSTER_PS1='\n\[\e[38;2;168;224;58m\]●\[\e[0m\] \[\e[38;2;138;152;120m\]\u\[\e[0m\]  \[\e[1;38;2;232;238;224m\]\w\[\e[0m\]$(__monster_git)\n$(__monster_arrow) '
# Use the Monster prompt unless you've made your own: the stock "user@host" prompts get replaced.
__monster_ps1() {
  case "$PS1" in *'\u@\h'*|'\s-\v\$ '|'') PS1="$__MONSTER_PS1"; PS2='\[\e[38;2;138;152;120m\]…\[\e[0m\] ';; esac
}
PROMPT_COMMAND="__monster_status; __monster_ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
