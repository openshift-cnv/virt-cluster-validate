#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc_cached vms get vm -A -o json > vms.json 2>/dev/null \
  || { pass_with info "No VirtualMachine resources found"; exit 0; }

VM_COUNT=$(cat vms.json | jq '.items | length')
[[ "$VM_COUNT" -gt 0 ]] \
  || { pass_with info "No VMs found on the cluster"; exit 0; }

CLUSTER_EVICTION=$(oc get kubevirt kubevirt -n openshift-cnv -o json 2>/dev/null \
  | jq -r '.spec.configuration.evictionStrategy // empty' 2>/dev/null)

step "Run Strategy"
ALWAYS=$(cat vms.json | jq '[.items[] | select(.spec.runStrategy=="Always")] | length')
MANUAL=$(cat vms.json | jq '[.items[] | select(.spec.runStrategy=="Manual" or .spec.runStrategy=="RerunOnFailure")] | length')
HALTED=$(cat vms.json | jq '[.items[] | select(.spec.runStrategy=="Halted" or .spec.running==false)] | length')
pass_with info "VM run strategies: Always=$ALWAYS, Manual/RerunOnFailure=$MANUAL, Halted=$HALTED"

step "Eviction Strategy"
if [ -n "$CLUSTER_EVICTION" ]; then
  pass_with info "Cluster-wide default eviction strategy: $CLUSTER_EVICTION"
  NO_EVICTION=$(cat vms.json | jq -r --arg default "$CLUSTER_EVICTION" '
    [.items[]
     | select(.spec.runStrategy=="Always" or .spec.running==true)
     | select((.spec.template.spec.evictionStrategy // $default) | IN("LiveMigrate","LiveMigrateIfPossible") | not)
     | "\(.metadata.namespace)/\(.metadata.name)"
    ] | .[]
  ')
else
  NO_EVICTION=$(cat vms.json | jq -r '
    [.items[]
     | select(.spec.runStrategy=="Always" or .spec.running==true)
     | select(.spec.template.spec.evictionStrategy != "LiveMigrate" and .spec.template.spec.evictionStrategy != "LiveMigrateIfPossible")
     | "\(.metadata.namespace)/\(.metadata.name)"
    ] | .[]
  ')
fi

if [ -n "$NO_EVICTION" ]; then
  pass_with warn "Running VMs without LiveMigrate eviction strategy (will be shut down on node drain): $NO_EVICTION"
fi

step "Node Maintenance Operator"
LIVEMIGRATE_COUNT=$(cat vms.json | jq --arg default "${CLUSTER_EVICTION:-none}" '
  [.items[] | select(
    (.spec.template.spec.evictionStrategy // $default) | IN("LiveMigrate","LiveMigrateIfPossible")
  )] | length
')
if [ "$LIVEMIGRATE_COUNT" -gt 0 ]; then
  oc get crd nodemaintenances.nodemaintenance.medik8s.io >/dev/null 2>&1 \
    || pass_with warn "VMs use LiveMigrate eviction but Node Maintenance Operator is not installed"
fi
