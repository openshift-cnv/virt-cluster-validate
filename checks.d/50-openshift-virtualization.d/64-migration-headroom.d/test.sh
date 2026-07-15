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
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

SCHED_NODES=$(cat nodes.json | jq '[.items[] | select(.metadata.labels["kubevirt.io/schedulable"] == "true")]')
NODE_COUNT=$(echo "$SCHED_NODES" | jq 'length')

[[ "$NODE_COUNT" -gt 1 ]] \
  || { pass_with info "Single schedulable node, migration headroom N/A"; exit 0; }

CLUSTER_EVICTION=$(oc get kubevirt kubevirt -n openshift-cnv -o json 2>/dev/null \
  | jq -r '.spec.configuration.evictionStrategy // empty' 2>/dev/null)

# jq helper: convert k8s memory string to bytes
MEM_TO_BYTES='def mem_to_bytes:
  if test("Ei$") then rtrimstr("Ei") | tonumber * 1152921504606846976
  elif test("Pi$") then rtrimstr("Pi") | tonumber * 1125899906842624
  elif test("Ti$") then rtrimstr("Ti") | tonumber * 1099511627776
  elif test("Gi$") then rtrimstr("Gi") | tonumber * 1073741824
  elif test("Mi$") then rtrimstr("Mi") | tonumber * 1048576
  elif test("Ki$") then rtrimstr("Ki") | tonumber * 1024
  elif test("E$") then rtrimstr("E") | tonumber * 1000000000000000000
  elif test("P$") then rtrimstr("P") | tonumber * 1000000000000000
  elif test("T$") then rtrimstr("T") | tonumber * 1000000000000
  elif test("G$") then rtrimstr("G") | tonumber * 1000000000
  elif test("M$") then rtrimstr("M") | tonumber * 1000000
  elif test("k$") then rtrimstr("k") | tonumber * 1000
  else tonumber
  end;'

step "Node Allocatable Memory"
MAX_NODE_MEM=$(echo "$SCHED_NODES" | jq "$MEM_TO_BYTES"'
  [.[] | .status.allocatable.memory | mem_to_bytes] | max
')

step "Largest VM Memory Request"
LARGEST_VM_MEM=$(oc_cached vms get vm -A -o json 2>/dev/null | jq --arg default "${CLUSTER_EVICTION:-none}" "$MEM_TO_BYTES"'
  [.items[]
   | select((.spec.template.spec.evictionStrategy // $default) | IN("LiveMigrate","LiveMigrateIfPossible"))
   | (.spec.template.spec.domain.resources.requests.memory // .spec.template.spec.domain.memory.guest // "0")
   | mem_to_bytes
  ] | max // 0
' 2>/dev/null)

LARGEST_VM_MEM="${LARGEST_VM_MEM:-0}"

if [ "$LARGEST_VM_MEM" -gt 0 ] && [ "$LARGEST_VM_MEM" -gt "$MAX_NODE_MEM" ]; then
  LARGEST_GB=$((LARGEST_VM_MEM / 1073741824))
  MAX_GB=$((MAX_NODE_MEM / 1073741824))
  pass_with warn "Largest LiveMigrate VM (${LARGEST_GB}Gi) exceeds max node allocatable memory (${MAX_GB}Gi)"
else
  pass_with info "Migration memory headroom is adequate"
fi
