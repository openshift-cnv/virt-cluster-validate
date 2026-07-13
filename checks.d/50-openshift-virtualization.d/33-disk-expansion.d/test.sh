#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

step "DataVolume Expansion"
oc get crd datavolumes.cdi.kubevirt.io >/dev/null 2>&1 \
  || { pass_with info "CDI not installed, skipping disk expansion check"; exit 0; }

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
