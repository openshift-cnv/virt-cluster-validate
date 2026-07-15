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

oc get pods -A -o json > pods.json \
  || fail_with "Unable to get pods"

NOW=$(date +%s)

RESTARTS=$(cat pods.json | jq -r --argjson now "$NOW" '
  [.items[]
   | select(.metadata.namespace | test("^(openshift-|kube-)"))
   | {
       ns: .metadata.namespace,
       name: .metadata.name,
       restarts: ([.status.containerStatuses[]?.restartCount] | add // 0),
       age_days: ((($now - (.metadata.creationTimestamp | fromdateiso8601)) / 86400) | floor | if . < 1 then 1 else . end)
     }
   | select(.restarts > 10)
   | . + {per_day: ((.restarts / .age_days * 10 | round) / 10)}
   | select(.per_day > 1)
  ] | sort_by(-.per_day)
  | .[:20][]
  | "\(.ns)/\(.name) restarts=\(.restarts) (~\(.per_day)/day)"
')

if [ -n "$RESTARTS" ]; then
  pass_with warn "Pods with high restart rate (>1/day): $RESTARTS"
else
  pass_with info "No platform pods with excessive restarts"
fi
