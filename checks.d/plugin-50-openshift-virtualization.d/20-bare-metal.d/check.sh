#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Bare Metal"

run() {
  local INFRA=$(oc get infrastructure cluster -o json | jq -re '.spec.platformSpec.type')

  case "$INFRA" in
    BareMetal|None) pass_with_info Infrastructure "Platform '$INFRA'" ;;
                 *) fail_with Infrastructure "Platform '$INFRA'. This does not look like it is bare metal." ;;
  esac
}

cleanup() {
  :
}

${@:-main}
