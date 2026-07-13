#!/usr/bin/bash

cleanup() {
  [ -f restore.yaml ] && oc delete -f restore.yaml --ignore-not-found=true >/dev/null 2>&1 || true
  [ -f snap.yaml ] && oc delete -f snap.yaml --ignore-not-found=true >/dev/null 2>&1 || true
  [ -f vm.yaml ] && oc delete -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create -f vm.yaml

VMNAME=$(oc get -o jsonpath='{.metadata.name}' -f vm.yaml)

virtctl stop $VMNAME

tee snap.yaml <<EOF
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineSnapshot
metadata:
  name: snap-${VMNAME}
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: ${VMNAME}
EOF
oc apply -f snap.yaml

oc wait -f snap.yaml --for condition=Ready --timeout=2m \
|| {
  oc get -o yaml -f snap.yaml
  fail_with Create "Failed to create snapshot with default storageclass"
}

tee restore.yaml <<EOF
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineRestore
metadata:
  name: restore-${VMNAME}
spec:
  target:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: ${VMNAME}
  virtualMachineSnapshotName: snap-${VMNAME}
EOF
oc apply -f restore.yaml
oc wait -f restore.yaml --for condition=Ready --timeout=2m \
|| {
  oc get -o yaml -f restore.yaml
  fail_with Restore "Failed to restore snapshots"
}
