#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

HCO=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o json 2>/dev/null) \
  || { pass_with info "HyperConverged CR not found"; exit 0; }

OVERCOMMIT=$(echo "$HCO" | jq -r '.spec.resourceRequirements.memoryOvercommitPercentage // 100')

if [ "$OVERCOMMIT" -gt 100 ]; then
  pass_with warn "Memory overcommit is enabled (${OVERCOMMIT}%). VMs may be OOM-killed under pressure."
elif [ "$OVERCOMMIT" -lt 100 ]; then
  pass_with info "Memory undercommit configured (${OVERCOMMIT}%), reserving extra capacity"
else
  pass_with info "Memory overcommit is not enabled (${OVERCOMMIT}%)"
fi
