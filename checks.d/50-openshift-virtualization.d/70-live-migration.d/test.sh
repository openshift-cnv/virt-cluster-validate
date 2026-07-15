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
  [ -f migration.yaml ] && oc delete ${NS:+-n "$NS"} -f migration.yaml --ignore-not-found=true >/dev/null 2>&1 || true
  [ -f vm.yaml ] && oc delete ${NS:+-n "$NS"} -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

oc auth can-i create virtualmachineinstancemigrations.kubevirt.io || {
  pass_with info "No permission to perform live migration. This is ok since 4.19+"
  exit 0
}

virtctl create vm --volume-import=type:ds,src:openshift-virtualization-os-images/rhel10 | tee vm.yaml
oc create ${NS:+-n "$NS"} -f vm.yaml

VMNAME=$(oc get ${NS:+-n "$NS"} -o jsonpath='{.metadata.name}' -f vm.yaml)

oc wait ${NS:+-n "$NS"} --for=condition=Ready=true --timeout=2m -f vm.yaml \
|| {
  oc get ${NS:+-n "$NS"} -o yaml vm $VMNAME
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
oc apply ${NS:+-n "$NS"} -f migration.yaml

oc wait ${NS:+-n "$NS"} --for=jsonpath='{.status.phase}'=Succeeded --timeout=2m -f migration.yaml \
|| {
  oc get ${NS:+-n "$NS"} -o yaml -f vm.yaml
  oc get ${NS:+-n "$NS"} -o yaml -f migration.yaml
  fail_with Migration "VM failed to migrate"
}
