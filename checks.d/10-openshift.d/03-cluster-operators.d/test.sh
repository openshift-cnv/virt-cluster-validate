#!/usr/bin/bash

oc get clusteroperators -o json > co.json \
  || fail_with "Unable to get clusteroperators"

DEGRADED=$(cat co.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True"))] | .[].metadata.name' 2>/dev/null)
if [ -n "$DEGRADED" ]; then
  fail_with "Degraded ClusterOperators: $DEGRADED"
fi

NOT_AVAILABLE=$(cat co.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Available" and .status!="True"))] | .[].metadata.name' 2>/dev/null)
if [ -n "$NOT_AVAILABLE" ]; then
  fail_with "Unavailable ClusterOperators: $NOT_AVAILABLE"
fi

PROGRESSING=$(cat co.json | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Progressing" and .status=="True"))] | .[].metadata.name' 2>/dev/null)
if [ -n "$PROGRESSING" ]; then
  pass_with warn "Progressing ClusterOperators: $PROGRESSING"
fi

COUNT=$(cat co.json | jq '.items | length')
pass_with info "All $COUNT ClusterOperators are healthy"
