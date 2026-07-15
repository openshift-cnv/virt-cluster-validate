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

step "DataVolume Expansion"
oc get crd datavolumes.cdi.kubevirt.io >/dev/null 2>&1 \
  || { skip_with "CDI not installed, skipping disk expansion check"; }

DV_STUCK=$(oc_cached dvs get dv -A -o json 2>/dev/null | jq -r '
  [.items[]
   | select(.metadata.namespace | test("^openshift-must-gather") | not)
   | select(
       .status.phase == "ExpansionInProgress" or
       (.status.conditions[]? | select(
         (.type == "Running" and .status == "False" and (.message // "" | test("expand|resize|capacity"; "i"))) or
         (.type == "Bound" and .status == "False" and .reason == "ExpansionFailed")
       ))
     )
   | "\(.metadata.namespace)/\(.metadata.name) (phase=\(.status.phase // "unknown"))"
  ] | .[]
' 2>/dev/null)

if [ -n "$DV_STUCK" ]; then
  pass_with warn "DataVolumes with expansion issues: $DV_STUCK"
fi

step "PVC Resize"
PVC_RESIZING=$(oc_cached pvcs get pvc -A -o json 2>/dev/null | jq -r '
  [.items[]
   | select(.metadata.namespace | test("^openshift-must-gather") | not)
   | select(.status.conditions[]? | select(.type == "FileSystemResizePending" or .type == "Resizing"))
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | .[]
' 2>/dev/null)

if [ -n "$PVC_RESIZING" ]; then
  pass_with warn "PVCs with pending resize: $PVC_RESIZING"
fi

pass_with info "No stalled disk expansion operations detected"
