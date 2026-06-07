# Sourced by `bash -l` (login shells). Define `help` as a function so it shadows bash's
# `help` builtin and shows the quickstart cheatsheet instead. Print a one-line welcome only
# in interactive shells, so non-interactive `bash -lc '...'` (e.g. CI) stays quiet.
help() { /usr/local/bin/quickstart-help; }

case $- in
  *i*) printf '\033[1mquickstart debug box\033[0m — backend CLIs preloaded & wired. Type \033[36mhelp\033[0m for a cheatsheet.\n' ;;
esac
