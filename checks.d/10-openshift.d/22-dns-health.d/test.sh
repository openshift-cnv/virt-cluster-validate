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

oc get dns.operator.openshift.io default -o json > dns.json \
  || fail_with "Unable to get DNS operator config"

DEGRADED=$(cat dns.json | jq -r '[.status.conditions[]? | select(.type=="Degraded" and .status=="True")] | first | .message // empty')
if [ -n "$DEGRADED" ]; then
  fail_with "DNS operator is Degraded: $DEGRADED"
fi

NOT_AVAILABLE=$(cat dns.json | jq -r '[.status.conditions[]? | select(.type=="Available" and .status!="True")] | first | .message // empty')
if [ -n "$NOT_AVAILABLE" ]; then
  pass_with warn "DNS operator not Available: $NOT_AVAILABLE"
fi

pass_with info "DNS operator is healthy"
