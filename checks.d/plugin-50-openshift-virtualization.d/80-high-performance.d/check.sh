#!/usr/bin/bash

source ../lib.sh

CHECK_DISPLAYNAME="High Performance VMs"

run() {
  virtctl create vm --instancetype cx1.medium --volume-import=type:ds,src:openshift-virtualization-os-images/fedora | tee vm.yaml
  oc create -f vm.yaml

  oc wait --for=condition=Ready=true -f vm.yaml \
  || ( oc get -o yaml -f vm.yaml; fail_with Scheduling "Unable to schedule high performance VMs. Is the CPU manager enabled?"; )
}

cleanup() {
  oc delete -f vm.yaml
}

${@:-main}
