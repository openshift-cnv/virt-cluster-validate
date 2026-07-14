#!/usr/bin/bash

oc get clusterversion version -o json > cv.json \
  || fail_with "Unable to get clusterversion"

OVERRIDES=$(cat cv.json | jq -r '
  [.spec.overrides // [] | .[] | select(.unmanaged == true) | "\(.group)/\(.name) in \(.namespace // "cluster")"] | .[]
')

if [ -n "$OVERRIDES" ]; then
  pass_with warn "CVO has unmanaged overrides (unsupported): $OVERRIDES"
fi

pass_with info "No CVO overrides detected"
