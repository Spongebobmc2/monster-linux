# Monster Linux: system card at the top right of new terminal windows (Konsole and Dolphin's F4 panel).
# Turn it off with:  touch ~/.config/monster-hello-off
if [ -n "${PS1:-}" ] && [ -n "${KONSOLE_VERSION:-}" ] && [ -z "${MONSTER_HELLO_SHOWN:-}" ] \
   && [ ! -e "$HOME/.config/monster-hello-off" ] && [ -x /usr/bin/monster-hello ]; then
  export MONSTER_HELLO_SHOWN=1
  /usr/bin/monster-hello
fi
