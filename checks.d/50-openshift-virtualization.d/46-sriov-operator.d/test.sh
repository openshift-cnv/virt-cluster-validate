#!/usr/bin/bash
#
# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { skip_with "OpenShift Virtualization not installed, skipping"; }

oc get namespace openshift-sriov-network-operator >/dev/null 2>&1 \
  || { skip_with "SR-IOV Network Operator not installed, skipping"; }

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
