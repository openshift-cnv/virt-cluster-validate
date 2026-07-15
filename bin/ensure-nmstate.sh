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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/host-network"
NS=openshift-nmstate
TIMEOUT=300s

command -v oc >/dev/null 2>&1 || {
    echo "missing required command: oc" >&2
    exit 1
}

if oc get crd nodenetworkconfigurationpolicies.nmstate.io >/dev/null 2>&1; then
    echo "virt-cluster-validate: nmstate CRD already present"
    exit 0
fi

echo "virt-cluster-validate: installing nmstate for host network checks"

oc apply -f "${MANIFESTS_DIR}/01-nmstate-operator.yaml"

# CSV is created asynchronously after the Subscription; wait for it to appear.
csv=""
start="$(date +%s)"
while true; do
    csv="$(oc get csv -n "${NS}" -o name 2>/dev/null | head -1 || true)"
    if [ -n "${csv}" ]; then
        break
    fi
    if (( "$(date +%s)" - start >= 300 )); then
        echo "timed out waiting for a CSV in ${NS}" >&2
        exit 1
    fi
    sleep 5
done

oc wait -n "${NS}" "${csv}" --for=jsonpath='{.status.phase}'=Succeeded --timeout="${TIMEOUT}"

oc apply -f "${MANIFESTS_DIR}/02-nmstate-cr.yaml"
oc wait --for=condition=Available nmstate/nmstate --timeout="${TIMEOUT}"

echo "virt-cluster-validate: nmstate is ready"
