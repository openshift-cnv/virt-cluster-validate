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

step "NNCE Health"
if oc get crd nodenetworkconfigurationenactments.nmstate.io >/dev/null 2>&1; then
  FAILED_NNCE=$(oc get nnce -A -o json 2>/dev/null | jq -r '
    [.items[]
     | select(.status.conditions[]? | select(.type=="Available" and .status!="True"))
     | "\(.metadata.name)"
    ] | .[:10] | .[]
  ')
  if [ -n "$FAILED_NNCE" ]; then
    pass_with warn "Failed NodeNetworkConfigurationEnactments: $FAILED_NNCE"
  fi
fi

step "NNCP Health"
if oc get crd nodenetworkconfigurationpolicies.nmstate.io >/dev/null 2>&1; then
  DEGRADED_NNCP=$(oc get nncp -o json 2>/dev/null | jq -r '
    [.items[]
     | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True"))
     | "\(.metadata.name)"
    ] | .[]
  ')
  if [ -n "$DEGRADED_NNCP" ]; then
    pass_with warn "Degraded NodeNetworkConfigurationPolicies: $DEGRADED_NNCP"
  fi
fi

step "Dedicated Migration Network"
HCO=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o json 2>/dev/null)
MIGRATION_NET=$(echo "$HCO" | jq -r '.spec.liveMigrationConfig.network // empty' 2>/dev/null)

if [ -n "$MIGRATION_NET" ]; then
  pass_with info "Dedicated migration network configured: $MIGRATION_NET"
  NAD_EXISTS=$(oc get net-attach-def -A -o json 2>/dev/null | jq --arg net "$MIGRATION_NET" '
    [.items[] | select("\(.metadata.namespace)/\(.metadata.name)" == $net)] | length
  ')
  if [ "$NAD_EXISTS" -eq 0 ]; then
    pass_with warn "Dedicated migration network '$MIGRATION_NET' references a NetworkAttachmentDefinition that was not found"
  fi
else
  pass_with info "No dedicated migration network configured (using pod network)"
fi
