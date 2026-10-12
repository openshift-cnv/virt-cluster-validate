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

hub_namespace="${HUB_NAMESPACE:-openshift-mtv}"
target_namespace="${TARGET_NAMESPACE:-vcv-validation}"
target_service_account="${TARGET_SERVICE_ACCOUNT:-virt-validation-target}"
validation_name="${VALIDATION_NAME:-target-canary-e2e}"
profile="${PROFILE:-basic-v1}"
data_source="${DATA_SOURCE:-openshift-virtualization-os-images/rhel10}"
suite_timeout="${SUITE_TIMEOUT_SECONDS:-900}"
execution_timeout="${EXECUTION_TIMEOUT_SECONDS:-300}"
initialization_timeout="${INITIALIZATION_TIMEOUT_SECONDS:-90}"
leader_election_id="${LEADER_ELECTION_ID:-virt-validation-controller.validation.kubevirt.io}"
target_oc=(oc)
if [[ -n "${TARGET_KUBECONFIG:-}" ]]; then
  target_oc+=(--kubeconfig="$TARGET_KUBECONFIG")
fi

target_url="${TARGET_URL:-$("${target_oc[@]}" config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}')}"
target_token="${TARGET_TOKEN:-$("${target_oc[@]}" -n "$target_namespace" create token "$target_service_account" --duration=1h)}"
ca_file="${TARGET_CA_FILE:-$(mktemp)}"
remove_ca_file=false
if [[ -z "${TARGET_CA_FILE:-}" ]]; then
  remove_ca_file=true
  ca_data="$("${target_oc[@]}" config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
  if [[ -z "$ca_data" ]]; then
    echo "set TARGET_CA_FILE: the target kubeconfig does not embed certificate-authority-data" >&2
    exit 2
  fi
  printf '%s' "$ca_data" | base64 -d > "$ca_file"
fi
report_validation_artifacts() {
  oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o yaml || true

  job_name="$(oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o jsonpath='{.status.jobName}' 2>/dev/null || true)"
  artifact_name="$(oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o jsonpath='{.status.artifact.name}' 2>/dev/null || true)"
  if [[ -n "$job_name" ]]; then
    oc -n "$hub_namespace" logs "job/$job_name" --all-containers=true || true
  fi
  if [[ -n "$artifact_name" ]]; then
    oc -n "$hub_namespace" get configmap "$artifact_name" -o yaml || true
  fi
}

report_failure_diagnostics() {
  echo "=== VirtualizationValidation artifacts ===" >&2
  report_validation_artifacts
  echo "=== Validation controller leader lease ===" >&2
  oc -n "$hub_namespace" get lease "$leader_election_id" -o yaml || true
  echo "=== Validation controller deployment and pods ===" >&2
  oc -n "$hub_namespace" get deployment virt-validation-controller -o wide || true
  oc -n "$hub_namespace" get pods -l app.kubernetes.io/name=virt-validation-controller -o wide || true
  oc -n "$hub_namespace" logs deployment/virt-validation-controller --all-containers=true --tail=-1 || true
  echo "=== Validation run resources ===" >&2
  oc -n "$hub_namespace" get jobs,configmaps,serviceaccounts,roles,rolebindings,networkpolicies \
    -l "validation.kubevirt.io/validation=$validation_name" -o wide || true
  echo "=== Validation namespace events ===" >&2
  oc -n "$hub_namespace" get events --sort-by=.lastTimestamp || true
}

cleanup() {
  local status=$?
  if (( status != 0 )); then
    set +e
    report_failure_diagnostics
    set -e
  fi
  if "$remove_ca_file"; then rm -f "$ca_file"; fi
  return "$status"
}
trap cleanup EXIT

secret_name="${validation_name}-credentials"
oc -n "$hub_namespace" create secret generic "$secret_name" \
  --from-literal=token="$target_token" --from-file=ca.crt="$ca_file" \
  --dry-run=client -o yaml | oc apply -f -
oc -n "$hub_namespace" apply -f - <<EOF
apiVersion: validation.kubevirt.io/v1alpha1
kind: VirtualizationValidation
metadata:
  name: ${validation_name}
spec:
  target:
    url: ${target_url}
    credentialsSecret:
      name: ${secret_name}
      tokenKey: token
      caKey: ca.crt
  workload:
    namespace: ${target_namespace}
    dataSource:
      apiGroup: cdi.kubevirt.io
      kind: DataSource
      namespace: ${data_source%/*}
      name: ${data_source##*/}
  run:
    id: e2e
    profile: ${profile}
    suiteTimeoutSeconds: ${suite_timeout}
    executionTimeoutSeconds: ${execution_timeout}
EOF

initialization_deadline=$((SECONDS + initialization_timeout))
initialized=false
while (( SECONDS < initialization_deadline )); do
  finalizers="$(oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)"
  observed_input_hash="$(oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o jsonpath='{.status.observedInputHash}' 2>/dev/null || true)"
  if [[ "$finalizers" == *"validation.kubevirt.io/finalizer"* || -n "$observed_input_hash" ]]; then
    initialized=true
    break
  fi
  sleep 2
done

if ! "$initialized"; then
  echo "Validation controller did not begin reconciling $validation_name within ${initialization_timeout}s" >&2
  exit 1
fi

deadline=$((SECONDS + suite_timeout + 120))
phase=""
while (( SECONDS < deadline )); do
  phase="$(oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o jsonpath='{.status.phase}')"
  case "$phase" in
    Completed|Cancelled|Error) break ;;
  esac
  sleep 5
done

if [[ "$phase" != "Completed" && "$phase" != "Cancelled" && "$phase" != "Error" ]]; then
  echo "Validation did not reach a terminal phase within $((suite_timeout + 120))s (last phase: ${phase:-empty})" >&2
  exit 1
fi

report_validation_artifacts

verdict="$(oc -n "$hub_namespace" get virtualizationvalidation "$validation_name" -o jsonpath='{.status.verdict}')"
[[ "$phase" == "Completed" && ( "$verdict" == "Valid" || "$verdict" == "ValidWithWarnings" ) ]]
