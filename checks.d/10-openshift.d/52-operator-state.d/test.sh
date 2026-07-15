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

oc get clusterversion version -o json > cv.json \
  || fail_with "Unable to get clusterversion"

OVERRIDES=$(cat cv.json | jq -r '
  [.spec.overrides // [] | .[] | select(.unmanaged == true) | "\(.group)/\(.name) in \(.namespace // "cluster")"] | .[]
')

if [ -n "$OVERRIDES" ]; then
  pass_with warn "CVO has unmanaged overrides (unsupported): $OVERRIDES"
fi

pass_with info "No CVO overrides detected"
