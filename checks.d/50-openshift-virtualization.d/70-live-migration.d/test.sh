#!/usr/bin/bash

cleanup() {
  [ -f migration.yaml ] && oc delete -f migration.yaml --ignore-not-found=true >/dev/null 2>&1 || true
  [ -f vm.yaml ] && oc delete -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

oc auth can-i create virtualmachineinstancemigrations.kubevirt.io || {
  pass_with info "No permission to perform live migration. This is ok since 4.19+"
  exit 0
}

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create -f vm.yaml

VMNAME=$(oc get -o jsonpath='{.metadata.name}' -f vm.yaml)

oc wait --for=condition=Ready=true --timeout=2m -f vm.yaml \
|| {
  oc get -o yaml vm $VMNAME
  fail_with Scheduling "Unable to schedule VMs?"
}

tee migration.yaml <<EOF
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstanceMigration
metadata:
  name: ${VMNAME}-migration
spec:
  vmiName: ${VMNAME}
status: {}
EOF
oc apply -f migration.yaml

oc wait --for=jsonpath='{.status.phase}'=Succeeded --timeout=2m -f migration.yaml \
|| {
  oc get -o yaml -f vm.yaml
  oc get -o yaml -f migration.yaml
  fail_with Migration "VM failed to migrate"
}
