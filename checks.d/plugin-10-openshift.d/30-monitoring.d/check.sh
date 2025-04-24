#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Monitoring"

run() {
  oc get namespace openshift-monitoring
  || fail_with Basic "OpenSHift Monitoring does not seem to be available. Did you install the nmstate operator?"
}

cleanup() {
  :
}

${@:-main}
