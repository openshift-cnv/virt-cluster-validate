#!/usr/bin/bash
#
# Copyright (C) 2025-2026 Red Hat, Inc.
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
MANIFEST="$(mktemp)"
VMNAME=""
DVNAMES=""

cleanup() {
  if [ -n "$VMNAME" ]; then
    oc delete ${NS:+-n "$NS"} vm,vmi "$VMNAME" --ignore-not-found=true --force --grace-period=0 --wait=true --timeout=60s >/dev/null 2>&1 || true
  fi
  for dv in $DVNAMES; do
    oc delete ${NS:+-n "$NS"} datavolume,pvc "$dv" --ignore-not-found=true --force --grace-period=0 --wait=false >/dev/null 2>&1 || true
  done
  rm -f "$MANIFEST"
}
trap cleanup EXIT

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee "$MANIFEST"
oc create ${NS:+-n "$NS"} -f "$MANIFEST" \
  || fail_with Setup "Failed to create test VM"

VMNAME=$(oc get ${NS:+-n "$NS"} -o jsonpath='{.metadata.name}' -f "$MANIFEST")
DVNAMES=$(oc get ${NS:+-n "$NS"} vm "$VMNAME" -o jsonpath='{range .spec.dataVolumeTemplates[*]}{.metadata.name}{" "}{end}')

oc wait ${NS:+-n "$NS"} --for=condition=Ready=true --timeout="${VM_READY_TIMEOUT:-2m}" -f "$MANIFEST" \
|| {
  oc get ${NS:+-n "$NS"} -o yaml vm "$VMNAME"
  fail_with Scheduling "Unable to schedule VMs"
}
