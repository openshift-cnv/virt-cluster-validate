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
  || { skip_with "OpenShift Virtualization not installed, skipping"; }

HCO=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o json 2>/dev/null) \
  || { skip_with "HyperConverged CR not found"; }

OVERCOMMIT=$(echo "$HCO" | jq -r '.spec.resourceRequirements.memoryOvercommitPercentage // 100')

if [ "$OVERCOMMIT" -gt 100 ]; then
  pass_with warn "Memory overcommit is enabled (${OVERCOMMIT}%). VMs may be OOM-killed under pressure."
elif [ "$OVERCOMMIT" -lt 100 ]; then
  pass_with info "Memory undercommit configured (${OVERCOMMIT}%), reserving extra capacity"
else
  pass_with info "Memory overcommit is not enabled (${OVERCOMMIT}%)"
fi
