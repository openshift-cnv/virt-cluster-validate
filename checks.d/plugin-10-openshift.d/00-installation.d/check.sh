#!/usr/bin/bash

source ../lib.sh

export CHECK_NAME="$BASH_SOURCE"
export CHECK_DISPLAYNAME="Installation"

run() {
  oc get projects | grep openshift-cnv \
  || fail_with Availability "OpenShift Virtualization does not seem to be present. Did you install the OpenShift Virtualization operator?"
}

cleanup() {
  :
}

${@:-main}
