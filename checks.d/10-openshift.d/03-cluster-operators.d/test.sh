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

oc get clusteroperators -o json > co.json \
  || fail_with "Unable to get clusteroperators"

DEGRADED=$(cat co.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True"))] | .[].metadata.name' 2>/dev/null)
if [ -n "$DEGRADED" ]; then
  fail_with "Degraded ClusterOperators: $DEGRADED"
fi

NOT_AVAILABLE=$(cat co.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Available" and .status!="True"))] | .[].metadata.name' 2>/dev/null)
if [ -n "$NOT_AVAILABLE" ]; then
  fail_with "Unavailable ClusterOperators: $NOT_AVAILABLE"
fi

PROGRESSING=$(cat co.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Progressing" and .status=="True"))] | .[].metadata.name' 2>/dev/null)
if [ -n "$PROGRESSING" ]; then
  pass_with warn "Progressing ClusterOperators: $PROGRESSING"
fi

COUNT=$(cat co.json | jq '.items | length')
pass_with info "All $COUNT ClusterOperators are healthy"
