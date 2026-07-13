#!/usr/bin/bash

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

NOT_READY=$(cat nodes.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status!="True"))] | .[].metadata.name')
if [ -n "$NOT_READY" ]; then
  fail_with "Nodes not Ready: $NOT_READY"
fi

PRESSURE_TYPES="MemoryPressure DiskPressure PIDPressure"
for PTYPE in $PRESSURE_TYPES; do
  PRESSURED=$(cat nodes.json | jq -r --arg t "$PTYPE" '[.items[] | select(.status.conditions[]? | select(.type==$t and .status=="True"))] | .[].metadata.name')
  if [ -n "$PRESSURED" ]; then
    pass_with warn "$PTYPE on nodes: $PRESSURED"
  fi
done

NODE_COUNT=$(cat nodes.json | jq '.items | length')
pass_with info "All $NODE_COUNT nodes are healthy"
