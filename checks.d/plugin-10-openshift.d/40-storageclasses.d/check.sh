#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Storage classes"

run() {
  oc get storageclasses -o json > storageclasses.json || fail_with Connection "Unable to get storageclasses from cluster"

  cat storageclasses.json \
  | jq -e '.items | length > 0' \
  || fail_with Availability "There is no storage class available. Persistent strage is not possible."
}

cleanup() {
  :
}

${@:-main}
