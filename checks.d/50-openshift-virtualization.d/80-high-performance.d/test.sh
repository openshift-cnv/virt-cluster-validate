#!/usr/bin/bash

cleanup() {
  [ -f vm.yaml ] && oc delete -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

virtctl create vm --instancetype cx1.medium --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create -f vm.yaml

oc wait --for=condition=Ready=true --timeout=2m -f vm.yaml \
|| {
  oc get -o yaml -f vm.yaml
  pass_with warn Scheduling "Unable to schedule high performance VMs. Is the CPU manager enabled?"
}
