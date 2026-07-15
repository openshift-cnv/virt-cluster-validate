#!/usr/bin/bash
#
# Copyright (C) 2026 Red Hat, Inc.
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

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { skip_with "OpenShift Virtualization not installed, skipping"; }

oc_cached vms get vm -A -o json > vms.json 2>/dev/null \
  || { skip_with "No VirtualMachine resources found"; }

CLUSTER_EVICTION=$(oc get kubevirt kubevirt -n openshift-cnv -o json 2>/dev/null \
  | jq -r '.spec.configuration.evictionStrategy // empty' 2>/dev/null)

MIGRATE_VMS=$(cat vms.json | jq --arg default "${CLUSTER_EVICTION:-none}" '
  [.items[] | select(
    ((.spec.template.spec.evictionStrategy // $default) | IN("LiveMigrate","LiveMigrateIfPossible"))
  )]
')
MIGRATE_COUNT=$(echo "$MIGRATE_VMS" | jq 'length')

[[ "$MIGRATE_COUNT" -gt 0 ]] \
  || { skip_with "No VMs with LiveMigrate eviction strategy"; }

step "PVC Access Modes"
oc_cached pvcs get pvc -A -o json > pvc.json 2>/dev/null

PROBLEM_VMS=$(echo "$MIGRATE_VMS" | jq -r --slurpfile pvcs pvc.json '
  [.[]
   | . as $vm
   | .spec.template.spec.volumes[]?
   | select(.persistentVolumeClaim or .dataVolume)
   | {
       vm: "\($vm.metadata.namespace)/\($vm.metadata.name)",
       ns: $vm.metadata.namespace,
       pvc: (.persistentVolumeClaim.claimName // .dataVolume.name)
     }
   | . as $ref
   | ($pvcs[0].items[] | select(.metadata.namespace == $ref.ns and .metadata.name == $ref.pvc)) as $p
   | select([$p.spec.accessModes[]? | select(. == "ReadWriteMany")] | length == 0)
   | "\($ref.vm)(pvc=\($ref.pvc),access=\([$p.spec.accessModes[]?] | join(",")))"
  ] | unique | .[]
')

if [ -n "$PROBLEM_VMS" ]; then
  pass_with warn "LiveMigrate VMs with non-RWX PVCs (cannot migrate): $PROBLEM_VMS"
fi

pass_with info "$MIGRATE_COUNT VMs with LiveMigrate eviction strategy checked for storage compatibility"
