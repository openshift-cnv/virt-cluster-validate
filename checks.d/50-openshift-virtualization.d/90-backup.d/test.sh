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
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc get namespace openshift-adp >/dev/null 2>&1 \
  || { pass_with info "OADP not installed (no openshift-adp namespace), skipping backup checks"; exit 0; }

step "OADP Operator"
CSV_PHASE=$(oc get csv -n openshift-adp -o json 2>/dev/null \
  | jq -r '[.items[] | select(.metadata.name | test("oadp"))] | first | .status.phase // "NotFound"')
if [ "$CSV_PHASE" != "Succeeded" ]; then
  pass_with warn "OADP operator CSV phase: $CSV_PHASE (expected Succeeded)"
fi

SUB_STATE=$(oc get subscriptions.operators.coreos.com -n openshift-adp -o json 2>/dev/null \
  | jq -r '.items[0].status.state // "NotFound"')
if [ "$SUB_STATE" != "AtLatestKnown" ] && [ "$SUB_STATE" != "UpgradePending" ]; then
  pass_with warn "OADP subscription state: $SUB_STATE"
fi

step "DataProtectionApplication"
DPA=$(oc get dataprotectionapplications -n openshift-adp -o json 2>/dev/null)
DPA_COUNT=$(echo "$DPA" | jq '.items | length')

if [ "$DPA_COUNT" -eq 0 ]; then
  pass_with warn "No DataProtectionApplication CR found in openshift-adp"
else
  DPA_NOT_RECONCILED=$(echo "$DPA" | jq -r '
    [.items[]
     | select(
         ([.status.conditions[]? | select(.type=="Reconciled" and .status=="True")] | length) == 0
       )
     | .metadata.name
    ] | .[]
  ')
  if [ -n "$DPA_NOT_RECONCILED" ]; then
    pass_with warn "DataProtectionApplication not reconciled: $DPA_NOT_RECONCILED"
  fi
fi

step "Backup Health"
FAILED_BACKUPS=$(oc get backups.velero.io -A -o json 2>/dev/null | jq -r '
  [.items[]
   | select(.status.phase == "Failed" or .status.phase == "PartiallyFailed")
   | "\(.metadata.namespace)/\(.metadata.name) (phase=\(.status.phase))"
  ] | .[:10] | .[]
' 2>/dev/null)
if [ -n "$FAILED_BACKUPS" ]; then
  pass_with warn "Failed Velero backups: $FAILED_BACKUPS"
fi

step "Schedule Health"
PAUSED_SCHEDULES=$(oc get schedules.velero.io -A -o json 2>/dev/null | jq -r '
  [.items[]
   | select(.spec.paused == true)
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | .[]
' 2>/dev/null)
if [ -n "$PAUSED_SCHEDULES" ]; then
  pass_with warn "Paused backup schedules: $PAUSED_SCHEDULES"
fi

pass_with info "Backup infrastructure (OADP) check complete"
