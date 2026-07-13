#!/usr/bin/bash

oc get pdb -A -o json > pdb.json \
  || fail_with "Unable to get PodDisruptionBudgets"

BLOCKING=$(cat pdb.json | jq -r '
  [.items[]
   | select(.status.disruptionsAllowed == 0)
   | select(.metadata.name | test("^kubevirt-disruption-budget-") | not)
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | .[]
')

if [ -n "$BLOCKING" ]; then
  pass_with warn "PDBs blocking disruptions (disruptionsAllowed=0): $BLOCKING"
fi

pass_with info "No PDBs are currently blocking disruptions"
