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

oc get namespace openshift-monitoring >/dev/null 2>&1 \
  || { skip_with "openshift-monitoring namespace not found"; }

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
