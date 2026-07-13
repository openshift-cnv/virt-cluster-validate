#!/usr/bin/bash

NS="${VIRT_VALIDATE_NAMESPACE:-}"

cleanup() {
  [ -f vm.yaml ] && oc delete ${NS:+-n "$NS"} -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

virtctl create vm --instancetype cx1.medium --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create ${NS:+-n "$NS"} -f vm.yaml

oc wait ${NS:+-n "$NS"} --for=condition=Ready=true --timeout=45s -f vm.yaml \
|| {
  oc get ${NS:+-n "$NS"} -o yaml -f vm.yaml
  pass_with warn Scheduling "Unable to schedule high performance VMs. Is the CPU manager enabled?"
}
