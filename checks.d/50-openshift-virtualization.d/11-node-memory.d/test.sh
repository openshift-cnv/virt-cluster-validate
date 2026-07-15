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

LOW_MEM=$(cat nodes.json | jq -r '
  [.items[]
   | select(.metadata.labels["kubevirt.io/schedulable"] == "true")
   | {
       name: .metadata.name,
       mem_bytes: (.status.allocatable.memory | gsub("Ki$";"") | tonumber * 1024)
     }
   | select(.mem_bytes < 8589934592)
   | "\(.name) (\(.mem_bytes / 1073741824 | floor)Gi allocatable)"
  ] | .[]
')

if [ -n "$LOW_MEM" ]; then
  pass_with warn "KubeVirt-schedulable nodes with less than 8Gi allocatable memory: $LOW_MEM"
fi

SCHED_COUNT=$(cat nodes.json | jq '[.items[] | select(.metadata.labels["kubevirt.io/schedulable"] == "true")] | length')
pass_with info "$SCHED_COUNT KubeVirt-schedulable nodes have adequate memory"
