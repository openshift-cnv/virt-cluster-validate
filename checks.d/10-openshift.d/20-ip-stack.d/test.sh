#!/usr/bin/bash

oc get network.config.openshift.io cluster -o json > net.json \
  || fail_with "Unable to get cluster network config"

NETWORK_TYPE=$(cat net.json | jq -r '.status.networkType // .spec.networkType // "unknown"')

HAS_IPV6=$(cat net.json | jq '
  ([.status.clusterNetwork // .spec.clusterNetwork // [] | .[].cidr | select(contains(":"))] | length > 0)
  or ([.status.serviceNetwork // .spec.serviceNetwork // [] | .[] | select(contains(":"))] | length > 0)
')

if [ "$HAS_IPV6" = "true" ]; then
  if [ "$NETWORK_TYPE" != "OVNKubernetes" ]; then
    pass_with warn "IPv6/dual-stack detected but network type is $NETWORK_TYPE (OVNKubernetes required for IPv6)"
  else
    pass_with info "Dual-stack/IPv6 with OVNKubernetes - supported configuration"
  fi
else
  pass_with info "IPv4-only cluster with $NETWORK_TYPE network type"
fi
