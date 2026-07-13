#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc get crd migrationpolicies.migrations.kubevirt.io >/dev/null 2>&1 \
  || { pass_with info "MigrationPolicy CRD not available"; exit 0; }

oc get migrationpolicies -A -o json > mp.json 2>/dev/null
MP_COUNT=$(cat mp.json | jq '.items | length')

if [ "$MP_COUNT" -eq 0 ]; then
  pass_with info "No MigrationPolicies defined (cluster defaults apply)"
  exit 0
fi

step "Migration Tuning"
AGGRESSIVE=$(cat mp.json | jq -r '
  [.items[]
   | select(
       (.spec.allowAutoConverge == true) or
       (.spec.allowPostCopy == true) or
       (.spec.completionTimeoutPerGiB != null and .spec.completionTimeoutPerGiB < 150)
     )
   | "\(.metadata.name) (autoConverge=\(.spec.allowAutoConverge // false), postCopy=\(.spec.allowPostCopy // false), timeout=\(.spec.completionTimeoutPerGiB // "default"))"
  ] | .[]
')
if [ -n "$AGGRESSIVE" ]; then
  pass_with warn "MigrationPolicies with aggressive tuning: $AGGRESSIVE"
fi

step "Bandwidth Limits"
BANDWIDTH=$(cat mp.json | jq -r '
  [.items[] | select(.spec.bandwidthPerMigration != null)
   | "\(.metadata.name): \(.spec.bandwidthPerMigration)"] | .[]
')
if [ -n "$BANDWIDTH" ]; then
  pass_with info "Migration bandwidth limits: $BANDWIDTH"
fi

pass_with info "$MP_COUNT MigrationPolicy(ies) reviewed"
