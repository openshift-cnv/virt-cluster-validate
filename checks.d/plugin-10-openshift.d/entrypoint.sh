#!/usr/bin/bash

source lib.sh

main() { run_plugin ; }

run_plugin() {
    plugin "$PLUGIN_NAME"

    # Find all checks, and run call them
    ls -1d ??-* | sort | xargs -n 1 -P 10 -- $0 run_check 
}

run_check() {
  pushd $1
  check "$1"
  ./check.sh
}

ping() { echo pong from $PLUGIN_NAME; }

${@:-main}
