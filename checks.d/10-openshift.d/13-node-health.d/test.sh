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

NOT_READY=$(cat nodes.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status!="True"))] | .[].metadata.name')
if [ -n "$NOT_READY" ]; then
  fail_with "Nodes not Ready: $NOT_READY"
fi

PRESSURE_TYPES="MemoryPressure DiskPressure PIDPressure"
for PTYPE in $PRESSURE_TYPES; do
  PRESSURED=$(cat nodes.json | jq -r --arg t "$PTYPE" '[.items[] | select(.status.conditions[]? | select(.type==$t and .status=="True"))] | .[].metadata.name')
  if [ -n "$PRESSURED" ]; then
    pass_with warn "$PTYPE on nodes: $PRESSURED"
  fi
done

NODE_COUNT=$(cat nodes.json | jq '.items | length')
pass_with info "All $NODE_COUNT nodes are healthy"
