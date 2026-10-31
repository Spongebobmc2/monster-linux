# Monster Linux terminal extras (bash): short commands for the three guides, and
# redraw the welcome card in the right places when the window is resized
# (only while nothing else has been typed yet).
case $- in *i*) ;; *) return 0 2>/dev/null ;; esac
alias updatehelp='monster-help update' cheatsheet='monster-help cheat' howto='monster-help howto'
if [ -n "${KONSOLE_VERSION:-}" ] && [ ! -e "$HOME/.config/no-show-user-motd" ] && [ -x /usr/bin/monster-hello ]; then
  __monster_fresh=1
  __monster_seen() { [ "${__monster_n:-0}" -ge 1 ] && __monster_fresh=0; __monster_n=$(( ${__monster_n:-0} + 1 )); }
  PROMPT_COMMAND="__monster_seen${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
  __monster_redraw() {
    [ "$__monster_fresh" = 1 ] || return
    printf '\e[H\e[2J\e[3J'; /usr/bin/monster-hello
    printf '%s' "${PS1@P}"
  }
  trap '__monster_redraw' WINCH
fi
