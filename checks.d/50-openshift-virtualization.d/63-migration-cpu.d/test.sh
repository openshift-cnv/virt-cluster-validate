#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

step "CPU Models"
SCHEDULABLE_NODES=$(cat nodes.json | jq '[.items[] | select(.metadata.labels["kubevirt.io/schedulable"] == "true")]')
NODE_COUNT=$(echo "$SCHEDULABLE_NODES" | jq 'length')

[[ "$NODE_COUNT" -gt 1 ]] \
  || { pass_with info "Single schedulable node, CPU model consistency N/A"; exit 0; }

CPU_MODELS=$(echo "$SCHEDULABLE_NODES" | jq -r '
  [.[] | .metadata.labels | to_entries[]
   | select(.key | startswith("cpu-model.node.kubevirt.io/"))
   | .key | ltrimstr("cpu-model.node.kubevirt.io/")
  ] | unique | .[]
')

COMMON_MODELS=$(echo "$SCHEDULABLE_NODES" | jq -r '
  [.[] | [.metadata.labels | to_entries[] | select(.key | startswith("cpu-model.node.kubevirt.io/")) | .key | ltrimstr("cpu-model.node.kubevirt.io/")]]
  | (. as $all | $all[0] | map(select(. as $m | $all | all(. | index($m)))))
  | .[]
')

if [ -z "$COMMON_MODELS" ]; then
  pass_with warn "No common CPU model across all $NODE_COUNT schedulable nodes. VMs with host-model may fail to migrate."
else
  COMMON_COUNT=$(echo "$COMMON_MODELS" | wc -l)
  pass_with info "$COMMON_COUNT common CPU model(s) across $NODE_COUNT schedulable nodes"
fi

step "Host Passthrough VMs"
HP_VMS=$(oc_cached vms get vm -A -o json 2>/dev/null | jq -r '
  [.items[]
   | select(.spec.template.spec.domain.cpu.model == "host-passthrough")
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | .[]
' 2>/dev/null)

if [ -n "$HP_VMS" ]; then
  pass_with warn "VMs using host-passthrough CPU model (reduces migration portability): $HP_VMS"
fi
