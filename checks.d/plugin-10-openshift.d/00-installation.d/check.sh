#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Installation"

run() {
  oc get projects | grep openshift-cnv \
  || fail_with Availability "OpenShift Virtualization does not seem to be present. Did you install the OpenShift Virtualization operator?"

  oc auth can-i list nodes || fail_with Auth "You can not list nodes. Are you bound to the cluster-reader role? This is required by this tool."
}

cleanup() {
  :
}

${@:-main}
