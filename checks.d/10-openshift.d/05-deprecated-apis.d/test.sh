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

oc api-resources --no-headers 2>/dev/null | grep -q apirequestcounts \
  || { skip_with "APIRequestCount resource not available"; }

oc get apirequestcounts -o json > arc.json \
  || fail_with "Unable to get APIRequestCounts"

DEPRECATED=$(cat arc.json | jq -r '
  [.items[]
   | select(.status.removedInRelease != null and .status.removedInRelease != "")
   | select(.status.requestCount > 0)
   | "\(.metadata.name) (removedIn=\(.status.removedInRelease), requests=\(.status.requestCount))"
  ] | .[]
')

if [ -n "$DEPRECATED" ]; then
  pass_with warn "Deprecated APIs still being called: $DEPRECATED"
fi

pass_with info "No deprecated APIs with active requests detected"
