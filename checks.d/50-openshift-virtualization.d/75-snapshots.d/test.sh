#!/usr/bin/bash
#
# Copyright (C) 2024-2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

NS="${VIRT_VALIDATE_NAMESPACE:-}"

cleanup() {
  [ -f restore.yaml ] && oc delete ${NS:+-n "$NS"} -f restore.yaml --ignore-not-found=true --force --grace-period=0 >/dev/null 2>&1 || true
  [ -f snap.yaml ] && oc delete ${NS:+-n "$NS"} -f snap.yaml --ignore-not-found=true --force --grace-period=0 >/dev/null 2>&1 || true
  [ -f vm.yaml ] && oc delete ${NS:+-n "$NS"} -f vm.yaml --ignore-not-found=true --force --grace-period=0 >/dev/null 2>&1 || true
}
trap cleanup EXIT

VSC_COUNT=$(oc get volumesnapshotclass -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo 0)
if [ "$VSC_COUNT" -eq 0 ]; then
  fail_with VolumeSnapshotClass "No VolumeSnapshotClass found, snapshot operations will not work"
fi

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create ${NS:+-n "$NS"} -f vm.yaml

VMNAME=$(oc get ${NS:+-n "$NS"} -o jsonpath='{.metadata.name}' -f vm.yaml)

oc wait ${NS:+-n "$NS"} --for=condition=Ready=true --timeout=2m -f vm.yaml
virtctl stop ${NS:+-n "$NS"} "$VMNAME"

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
oc apply ${NS:+-n "$NS"} -f snap.yaml

oc wait ${NS:+-n "$NS"} -f snap.yaml --for condition=Ready --timeout=2m \
|| {
  oc get ${NS:+-n "$NS"} -o yaml -f snap.yaml
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
oc apply ${NS:+-n "$NS"} -f restore.yaml
oc wait ${NS:+-n "$NS"} -f restore.yaml --for condition=Ready --timeout=2m \
|| {
  oc get ${NS:+-n "$NS"} -o yaml -f restore.yaml
  fail_with Restore "Failed to restore snapshots"
}
