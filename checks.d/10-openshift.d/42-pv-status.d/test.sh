#!/usr/bin/bash

oc get pv -o json > pv.json 2>/dev/null \
  || { pass_with info "Unable to list PersistentVolumes (may lack permissions)"; exit 0; }

PV_COUNT=$(cat pv.json | jq '.items | length')
[[ "$PV_COUNT" -gt 0 ]] \
  || { pass_with info "No PersistentVolumes found"; exit 0; }

UNHEALTHY=$(cat pv.json | jq -r '
  [.items[]
   | select(.status.phase != "Bound" and .status.phase != "Available")
   | "\(.metadata.name) (phase=\(.status.phase))"
  ] | .[]
')

if [ -n "$UNHEALTHY" ]; then
  UNHEALTHY_COUNT=$(cat pv.json | jq '[.items[] | select(.status.phase != "Bound" and .status.phase != "Available")] | length')
  pass_with warn "$UNHEALTHY_COUNT PVs not in healthy state: $UNHEALTHY"
fi

BOUND=$(cat pv.json | jq '[.items[] | select(.status.phase == "Bound")] | length')
AVAIL=$(cat pv.json | jq '[.items[] | select(.status.phase == "Available")] | length')
pass_with info "PV status: $BOUND bound, $AVAIL available out of $PV_COUNT total"
