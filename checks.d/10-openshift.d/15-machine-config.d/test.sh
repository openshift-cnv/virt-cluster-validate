#!/usr/bin/bash

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

DRIFTED=$(cat nodes.json | jq -r '
  [.items[]
   | {
       name: .metadata.name,
       current: .metadata.annotations["machineconfiguration.openshift.io/currentConfig"],
       desired: .metadata.annotations["machineconfiguration.openshift.io/desiredConfig"],
       state: .metadata.annotations["machineconfiguration.openshift.io/state"]
     }
   | select(.current != null and .desired != null)
   | select(.current != .desired)
   | "\(.name) (state=\(.state // "unknown"))"
  ] | .[]
')

if [ -n "$DRIFTED" ]; then
  pass_with warn "Nodes with MachineConfig drift (current != desired): $DRIFTED"
fi

pass_with info "All nodes have matching current and desired MachineConfig"
