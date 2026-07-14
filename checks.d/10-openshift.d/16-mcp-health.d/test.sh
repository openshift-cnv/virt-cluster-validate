#!/usr/bin/bash

oc get mcp -o json > mcp.json 2>/dev/null \
  || { pass_with info "MachineConfigPool API not available"; exit 0; }

DEGRADED=$(cat mcp.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True"))] | .[].metadata.name')
if [ -n "$DEGRADED" ]; then
  fail_with "Degraded MachineConfigPools: $DEGRADED"
fi

MISMATCHED=$(cat mcp.json | jq -r '[.items[] | select(.status.machineCount != .status.readyMachineCount)] | .[] | "\(.metadata.name) (ready=\(.status.readyMachineCount)/\(.status.machineCount))"')
if [ -n "$MISMATCHED" ]; then
  pass_with warn "MachineConfigPools with unready machines: $MISMATCHED"
fi

PAUSED=$(cat mcp.json | jq -r '[.items[] | select(.spec.paused==true)] | .[].metadata.name')
if [ -n "$PAUSED" ]; then
  pass_with warn "Paused MachineConfigPools (upgrades blocked): $PAUSED"
fi

COUNT=$(cat mcp.json | jq '.items | length')
pass_with info "All $COUNT MachineConfigPools are healthy"
