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

oc get machinesets -n openshift-machine-api -o json > ms.json 2>/dev/null \
  || { pass_with info "MachineSet API not available (hosted control plane or SNO?)"; exit 0; }

MS_COUNT=$(cat ms.json | jq '.items | length')
[[ "$MS_COUNT" -gt 0 ]] \
  || { pass_with info "No MachineSets found"; exit 0; }

MISMATCHED=$(cat ms.json | jq -r '
  [.items[]
   | select(
       (.spec.replicas // 0) != (.status.availableReplicas // 0)
       or (.spec.replicas // 0) != (.status.readyReplicas // 0)
     )
   | "\(.metadata.name) (desired=\(.spec.replicas // 0), available=\(.status.availableReplicas // 0), ready=\(.status.readyReplicas // 0))"
  ] | .[]
')

if [ -n "$MISMATCHED" ]; then
  pass_with warn "MachineSets with replica mismatch: $MISMATCHED"
fi

pass_with info "All $MS_COUNT MachineSets have matching replica counts"
