#!/usr/bin/env bash
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

set -euo pipefail

namespace="${NAMESPACE:-openshift-mtv}"
leader_election_id="${LEADER_ELECTION_ID:-virt-validation-controller.validation.kubevirt.io}"
leader_election_timeout_seconds="${LEADER_ELECTION_TIMEOUT_SECONDS:-90}"
: "${CONTROLLER_IMAGE:?set CONTROLLER_IMAGE to a pullable controller image}"
: "${VALIDATOR_IMAGE:?set VALIDATOR_IMAGE to a pullable validator image}"

if [[ "$namespace" != "openshift-mtv" ]]; then
  echo "config/manager/manager.yaml is packaged for openshift-mtv; got NAMESPACE=$namespace" >&2
  exit 2
fi

oc get namespace "$namespace" >/dev/null
oc apply -f config/crd/bases
oc apply -f config/rbac/role.yaml
oc apply -f config/manager/manager.yaml

patch="$(jq -cn --arg controller "$CONTROLLER_IMAGE" --arg validator "$VALIDATOR_IMAGE" '
  {spec: {template: {spec: {containers: [{
    name: "manager",
    image: $controller,
    args: [
      "--validator-image=" + $validator,
      "--leader-elect=true",
      "--leader-election-namespace=openshift-mtv"
    ]
  }]}}}}')"
oc -n "$namespace" patch deployment virt-validation-controller --type=strategic -p "$patch"
oc -n "$namespace" rollout status deployment/virt-validation-controller --timeout="${ROLLOUT_TIMEOUT:-5m}"

leader_deadline=$((SECONDS + leader_election_timeout_seconds))
while (( SECONDS < leader_deadline )); do
  holder_identity="$(oc -n "$namespace" get lease "$leader_election_id" -o jsonpath='{.spec.holderIdentity}' 2>/dev/null || true)"
  if [[ -n "$holder_identity" ]]; then
    echo "Validation controller leader elected: $holder_identity"
    exit 0
  fi
  sleep 2
done

echo "Validation controller did not acquire leader lease $leader_election_id within ${leader_election_timeout_seconds}s" >&2
oc -n "$namespace" get deployment,pods -l app.kubernetes.io/name=virt-validation-controller -o wide || true
oc -n "$namespace" get lease "$leader_election_id" -o yaml || true
oc -n "$namespace" logs deployment/virt-validation-controller --all-containers=true --tail=-1 || true
oc -n "$namespace" get events --sort-by=.lastTimestamp || true
exit 1
