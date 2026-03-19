#!/usr/bin/bash

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create -f vm.yaml

oc wait --for=condition=Ready=true --timeout 2s -f vm.yaml \
|| {
  VMNAME=$(oc get -o jsonpath='{.metadata.name}' -f vm.yaml)
  oc get -o yaml vm $VMNAME
  fail_with Scheduling "Unable to schedule VMs?"
}

oc delete -f vm.yaml
