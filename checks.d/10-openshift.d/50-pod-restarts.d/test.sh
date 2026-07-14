#!/usr/bin/bash

oc get pods -A -o json > pods.json \
  || fail_with "Unable to get pods"

NOW=$(date +%s)

RESTARTS=$(cat pods.json | jq -r --argjson now "$NOW" '
  [.items[]
   | select(.metadata.namespace | test("^(openshift-|kube-)"))
   | {
       ns: .metadata.namespace,
       name: .metadata.name,
       restarts: ([.status.containerStatuses[]?.restartCount] | add // 0),
       age_days: ((($now - (.metadata.creationTimestamp | fromdateiso8601)) / 86400) | floor | if . < 1 then 1 else . end)
     }
   | select(.restarts > 10)
   | . + {per_day: ((.restarts / .age_days * 10 | round) / 10)}
   | select(.per_day > 1)
  ] | sort_by(-.per_day)
  | .[:20][]
  | "\(.ns)/\(.name) restarts=\(.restarts) (~\(.per_day)/day)"
')

if [ -n "$RESTARTS" ]; then
  pass_with warn "Pods with high restart rate (>1/day): $RESTARTS"
else
  pass_with info "No platform pods with excessive restarts"
fi
