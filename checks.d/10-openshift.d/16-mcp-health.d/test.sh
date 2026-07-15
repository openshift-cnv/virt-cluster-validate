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

oc get mcp -o json > mcp.json 2>/dev/null \
  || { pass_with info "MachineConfigPool API not available"; exit 0; }

DEGRADED=$(cat mcp.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True"))] | .[].metadata.name')
if [ -n "$DEGRADED" ]; then
  fail_with "Degraded MachineConfigPools: $DEGRADED"
fi

MISMATCHED=$(cat mcp.json | jq -r '[.items[] | select(.status.machineCount != .status.readyMachineCount)] | .[] | "\(.metadata.name) (ready=\(.status.readyMachineCount)/\(.status.machineCount))"')
if [ -n "$MISMATCHED" ]; then
  pass_with warn "MachineConfigPools with unready machines: $MISMATCHED"
fi

PAUSED=$(cat mcp.json | jq -r '[.items[] | select(.spec.paused==true)] | .[].metadata.name')
if [ -n "$PAUSED" ]; then
  pass_with warn "Paused MachineConfigPools (upgrades blocked): $PAUSED"
fi

COUNT=$(cat mcp.json | jq '.items | length')
pass_with info "All $COUNT MachineConfigPools are healthy"
