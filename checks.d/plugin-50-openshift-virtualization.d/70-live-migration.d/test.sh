#!/usr/bin/bash

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/fedora | tee vm.yaml
oc create -f vm.yaml

VMNAME=$(oc get -o jsonpath='{.metadata.name}' -f vm.yaml)

oc wait --for=condition=Ready=true --timeout 2m -f vm.yaml \
|| (
  oc get -o yaml vm $VMNAME
  fail_with Scheduling "Unable to schedule VMs?"
)

#virtctl migrate val  # we nede the vmim name
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
|| (
  oc get -o yaml -f vm.yaml
  oc get -o yaml -f migration.yaml
  fail_with Migration "VM failed to migrate"
)
