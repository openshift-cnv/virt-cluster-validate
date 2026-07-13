#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

step "PVC Health"
PENDING_PVCS=$(oc_cached pvcs get pvc -A -o json 2>/dev/null | jq -r '
  [.items[]
   | select(.metadata.namespace | test("^openshift-must-gather") | not)
   | select(.metadata.labels["app.kubernetes.io/managed-by"]? == "cdi-controller" or
            (.metadata.ownerReferences[]? | select(.kind == "DataVolume")))
   | select(.status.phase != "Bound")
   | "\(.metadata.namespace)/\(.metadata.name) (phase=\(.status.phase))"
  ] | .[]
')
if [ -n "$PENDING_PVCS" ]; then
  pass_with warn "VM-related PVCs not in Bound state: $PENDING_PVCS"
fi

step "DataVolume Health"
if oc get crd datavolumes.cdi.kubevirt.io >/dev/null 2>&1; then
  STUCK_DVS=$(oc_cached dvs get dv -A -o json 2>/dev/null | jq -r '
    [.items[]
     | select(.metadata.namespace | test("^openshift-must-gather") | not)
     | select(.status.phase != "Succeeded" and .status.phase != null and .status.phase != "")
     | select(.status.phase | IN("Pending","ImportScheduled","CloneScheduled",
                                  "UploadScheduled","WaitForFirstConsumer",
                                  "CloneFromSnapshotSourceInProgress",
                                  "ImportInProgress","UploadReady") | not)
     | "\(.metadata.namespace)/\(.metadata.name) (phase=\(.status.phase))"
    ] | .[]
  ')
  if [ -n "$STUCK_DVS" ]; then
    pass_with warn "DataVolumes in unexpected phase: $STUCK_DVS"
  fi
fi

step "VolumeSnapshotClass"
if oc get crd volumesnapshotclasses.snapshot.storage.k8s.io >/dev/null 2>&1; then
  DEFAULT_VSC=$(oc get volumesnapshotclasses -o json 2>/dev/null | jq '
    [.items[] | select(.metadata.annotations["snapshot.storage.kubernetes.io/is-default-class"] == "true")] | length
  ')
  if [ "$DEFAULT_VSC" -eq 0 ]; then
    pass_with warn "No default VolumeSnapshotClass defined. VM snapshots may fail."
  fi
fi

pass_with info "Storage readiness check complete"
