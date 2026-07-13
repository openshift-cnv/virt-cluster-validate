#!/usr/bin/bash

NS="${VIRT_VALIDATE_NAMESPACE:-}"

cleanup() {
  [ -f vm.yaml ] && oc delete ${NS:+-n "$NS"} -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create ${NS:+-n "$NS"} -f vm.yaml

oc wait ${NS:+-n "$NS"} --for=condition=Ready=true --timeout=2m -f vm.yaml \
|| {
  VMNAME=$(oc get ${NS:+-n "$NS"} -o jsonpath='{.metadata.name}' -f vm.yaml)
  oc get ${NS:+-n "$NS"} -o yaml vm $VMNAME
  fail_with Scheduling "Unable to schedule VMs?"
}
