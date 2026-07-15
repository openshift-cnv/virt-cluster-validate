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

cleanup() {
  [ -f vm.yaml ] && oc delete ${NS:+-n "$NS"} -f vm.yaml --ignore-not-found=true --force --grace-period=0 >/dev/null 2>&1 || true
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
