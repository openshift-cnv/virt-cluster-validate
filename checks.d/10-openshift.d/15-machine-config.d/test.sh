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

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

DRIFTED=$(cat nodes.json | jq -r '
  [.items[]
   | {
       name: .metadata.name,
       current: .metadata.annotations["machineconfiguration.openshift.io/currentConfig"],
       desired: .metadata.annotations["machineconfiguration.openshift.io/desiredConfig"],
       state: .metadata.annotations["machineconfiguration.openshift.io/state"]
     }
   | select(.current != null and .desired != null)
   | select(.current != .desired)
   | "\(.name) (state=\(.state // "unknown"))"
  ] | .[]
')

if [ -n "$DRIFTED" ]; then
  pass_with warn "Nodes with MachineConfig drift (current != desired): $DRIFTED"
fi

pass_with info "All nodes have matching current and desired MachineConfig"
