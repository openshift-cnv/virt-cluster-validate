#!/usr/bin/bash

oc get clusterversion version -o json > cv.json \
  || fail_with "Unable to get clusterversion"

AVAILABLE=$(cat cv.json | jq -r '[.status.conditions[] | select(.type=="Available")] | first | .status')
PROGRESSING=$(cat cv.json | jq -r '[.status.conditions[] | select(.type=="Progressing")] | first | .status')
VERSION=$(cat cv.json | jq -r '.status.desired.version // "unknown"')

[[ "$AVAILABLE" == "True" ]] \
  || fail_with "ClusterVersion is not Available (status=$AVAILABLE)"

[[ "$PROGRESSING" != "True" ]] \
  || pass_with warn "Cluster is currently upgrading to $VERSION"

pass_with info "Cluster version $VERSION is healthy"
