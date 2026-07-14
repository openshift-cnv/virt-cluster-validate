#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc get namespace openshift-sriov-network-operator >/dev/null 2>&1 \
  || { pass_with info "SR-IOV Network Operator not installed, skipping"; exit 0; }

step "CSV Health"
CSV_PHASE=$(oc get csv -n openshift-sriov-network-operator -o json 2>/dev/null \
  | jq -r '[.items[] | select(.metadata.name | test("sriov"))] | first | .status.phase // "NotFound"')
if [ "$CSV_PHASE" != "Succeeded" ]; then
  pass_with warn "SR-IOV operator CSV phase: $CSV_PHASE (expected Succeeded)"
fi

step "Subscription"
SUB_STATE=$(oc get subscriptions.operators.coreos.com -n openshift-sriov-network-operator -o json 2>/dev/null \
  | jq -r '.items[0].status.state // "NotFound"')
if [ "$SUB_STATE" != "AtLatestKnown" ] && [ "$SUB_STATE" != "UpgradePending" ]; then
  pass_with warn "SR-IOV subscription state: $SUB_STATE"
fi

step "Operator Config"
SRIOV_CONFIG=$(oc get sriovoperatorconfigs.sriovnetwork.openshift.io -n openshift-sriov-network-operator default -o json 2>/dev/null)
if [ -n "$SRIOV_CONFIG" ]; then
  INJECTOR=$(echo "$SRIOV_CONFIG" | jq -r '.spec.enableInjector // true')
  WEBHOOK=$(echo "$SRIOV_CONFIG" | jq -r '.spec.enableOperatorWebhook // true')
  if [ "$INJECTOR" != "true" ]; then
    pass_with warn "SR-IOV network resource injector is disabled"
  fi
  if [ "$WEBHOOK" != "true" ]; then
    pass_with warn "SR-IOV operator webhook is disabled"
  fi
fi

pass_with info "SR-IOV operator for CNV is healthy (CSV=$CSV_PHASE)"
