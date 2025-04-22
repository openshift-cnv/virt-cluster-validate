#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Quota"

run() {
  oc get quota | wc -l | test $(cat /dev/stdin) -eq 1 \
  || pass_with_warn Basic "There is a quota set on the namespace, this can break this validation. Please remove the quota if any test fails, and retry."
}

cleanup() {
  :
}

${@:-main}
