#!/usr/bin/bash

oc get dns.operator.openshift.io default -o json > dns.json \
  || fail_with "Unable to get DNS operator config"

DEGRADED=$(cat dns.json | jq -r '[.status.conditions[]? | select(.type=="Degraded" and .status=="True")] | first | .message // empty')
if [ -n "$DEGRADED" ]; then
  fail_with "DNS operator is Degraded: $DEGRADED"
fi

NOT_AVAILABLE=$(cat dns.json | jq -r '[.status.conditions[]? | select(.type=="Available" and .status!="True")] | first | .message // empty')
if [ -n "$NOT_AVAILABLE" ]; then
  pass_with warn "DNS operator not Available: $NOT_AVAILABLE"
fi

pass_with info "DNS operator is healthy"
