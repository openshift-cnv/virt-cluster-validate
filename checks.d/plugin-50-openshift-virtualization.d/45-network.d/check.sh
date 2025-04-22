#!/usr/bin/bash

source ../lib.sh

export DISPLAYNAME="Secondary networks"

run() {
  oc get projects | grep openshift-multus \
  || fail_with Availability "Multus does not seem to be available."
}

cleanup() {
  :
}

${@:-main}
