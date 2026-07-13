#!/usr/bin/bash

oc get namespace openshift-monitoring >/dev/null 2>&1 \
  || { pass_with info "openshift-monitoring namespace not found"; exit 0; }

oc get pods -n openshift-monitoring -o json > pods.json \
  || fail_with "Unable to get monitoring pods"

EXPECTED_PODS="prometheus-k8s alertmanager-main thanos-querier kube-state-metrics node-exporter"

for COMPONENT in $EXPECTED_PODS; do
  step "$COMPONENT"
  NOT_RUNNING=$(cat pods.json | jq -r --arg c "$COMPONENT" '
    [.items[]
     | select(.metadata.name | startswith($c))
     | select(.status.phase != "Running" or (.status.containerStatuses[]? | select(.ready != true)))
     | "\(.metadata.name) (phase=\(.status.phase))"
    ] | .[]
  ')
  if [ -n "$NOT_RUNNING" ]; then
    pass_with warn "$COMPONENT pods not healthy: $NOT_RUNNING"
  fi

  POD_COUNT=$(cat pods.json | jq --arg c "$COMPONENT" '[.items[] | select(.metadata.name | startswith($c))] | length')
  if [ "$POD_COUNT" -eq 0 ]; then
    pass_with warn "$COMPONENT pods not found in openshift-monitoring"
  fi
done

pass_with info "All monitoring components are running"
