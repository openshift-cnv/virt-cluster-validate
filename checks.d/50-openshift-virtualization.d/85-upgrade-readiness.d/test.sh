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

step "CSV Health"
FAILED_CSVS=$(oc get csv -n openshift-cnv -o json 2>/dev/null | jq -r '
  [.items[] | select(.status.phase != "Succeeded")
   | "\(.metadata.name) (phase=\(.status.phase))"
  ] | .[]
')
if [ -n "$FAILED_CSVS" ]; then
  fail_with "CNV CSVs not in Succeeded phase: $FAILED_CSVS"
fi

step "HCO Conditions"
HCO=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o json 2>/dev/null) \
  || fail_with "HyperConverged CR not found"

HCO_DEGRADED=$(echo "$HCO" | jq -r '.status.conditions[]? | select(.type=="Degraded" and .status=="True") | .message')
if [ -n "$HCO_DEGRADED" ]; then
  fail_with "HyperConverged is Degraded: $HCO_DEGRADED"
fi

HCO_AVAILABLE=$(echo "$HCO" | jq -r '.status.conditions[]? | select(.type=="Available") | .status')
if [ "$HCO_AVAILABLE" != "True" ]; then
  pass_with warn "HyperConverged is not Available"
fi

HCO_UPGRADEABLE=$(echo "$HCO" | jq -r '.status.conditions[]? | select(.type=="Upgradeable") | .status')
if [ "$HCO_UPGRADEABLE" == "False" ]; then
  HCO_UPG_MSG=$(echo "$HCO" | jq -r '.status.conditions[]? | select(.type=="Upgradeable") | .message')
  pass_with warn "HyperConverged is not Upgradeable: $HCO_UPG_MSG"
fi

step "ClusterVersion"
CV_PROGRESSING=$(oc get clusterversion version -o json 2>/dev/null | jq -r '
  .status.conditions[]? | select(.type=="Progressing" and .status=="True") | .message
')
if [ -n "$CV_PROGRESSING" ]; then
  pass_with warn "Cluster is currently upgrading: $CV_PROGRESSING"
fi

pass_with info "CNV is ready for upgrade"
