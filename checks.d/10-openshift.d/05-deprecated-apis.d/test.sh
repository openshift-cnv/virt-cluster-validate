#!/usr/bin/bash

oc api-resources --no-headers 2>/dev/null | grep -q apirequestcounts \
  || { pass_with info "APIRequestCount resource not available"; exit 0; }

oc get apirequestcounts -o json > arc.json \
  || fail_with "Unable to get APIRequestCounts"

DEPRECATED=$(cat arc.json | jq -r '
  [.items[]
   | select(.status.removedInRelease != null and .status.removedInRelease != "")
   | select(.status.requestCount > 0)
   | "\(.metadata.name) (removedIn=\(.status.removedInRelease), requests=\(.status.requestCount))"
  ] | .[]
')

if [ -n "$DEPRECATED" ]; then
  pass_with warn "Deprecated APIs still being called: $DEPRECATED"
fi

pass_with info "No deprecated APIs with active requests detected"
