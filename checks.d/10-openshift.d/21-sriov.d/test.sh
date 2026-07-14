#!/usr/bin/bash

oc get namespace openshift-sriov-network-operator >/dev/null 2>&1 \
  || { pass_with info "SR-IOV Network Operator not installed, skipping"; exit 0; }

step "CSV Health"
CSV_PHASE=$(oc get csv -n openshift-sriov-network-operator -o json 2>/dev/null \
  | jq -r '[.items[] | select(.metadata.name | test("sriov"))] | first | .status.phase // "NotFound"')
[[ "$CSV_PHASE" == "Succeeded" ]] \
  || pass_with warn "SR-IOV operator CSV phase: $CSV_PHASE"

step "Network Node Policies"
oc get sriovnetworknodepolicies.sriovnetwork.openshift.io -n openshift-sriov-network-operator -o json > policies.json 2>/dev/null \
  || { pass_with info "No SriovNetworkNodePolicy resources found"; exit 0; }

INVALID_VFS=$(cat policies.json | jq -r '
  [.items[]
   | select(.metadata.name != "default")
   | select(.spec.numVfs < 1 or .spec.numVfs > 128)
   | "\(.metadata.name) (numVfs=\(.spec.numVfs))"
  ] | .[]
')
if [ -n "$INVALID_VFS" ]; then
  pass_with warn "SR-IOV policies with invalid numVfs (must be 1-128): $INVALID_VFS"
fi

step "SR-IOV Networks"
SRIOV_NET_COUNT=$(oc get sriovnetworks.sriovnetwork.openshift.io -A --no-headers 2>/dev/null | wc -l)
pass_with info "SR-IOV operator healthy: CSV=$CSV_PHASE, networks=$SRIOV_NET_COUNT"
