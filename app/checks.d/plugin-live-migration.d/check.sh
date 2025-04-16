#!/usr/bin/bash

source lib.sh

export DISPLAYNAME="Live Migration"

run() {
  virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel9 | tee vm.yaml
  oc create -f vm.yaml

  oc wait --for=condition=Ready=true -f vm.yaml \
  || fail_with Scheduling "Unable to schedule VMs?"

  #virtctl migrate val  # we nede the vmim name
  VMNAME=$(oc get -o jsonpath='{.metadata.name}' -f vm.yaml)
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

  oc wait --for=jsonpath='{.status.phase}'=Succeeded -f migration.yaml \
  || fail_with Migration "VM failed to migrate"
}

cleanup() {
  oc delete -f vm.yaml
  oc delete -f migration.yaml
}

${@:-main}
