#!/bin/bash
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

set -euo pipefail

# Redirect all output to both stdout and stderr for debugging
exec 2>&1

# Download oc and virtctl from the cluster at runtime
# Cluster domain is inferred from OAuth well-known endpoint (no RBAC required)
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-}"
if [ -z "$CLUSTER_DOMAIN" ]; then
    # Get cluster domain from OAuth issuer (publicly accessible endpoint)
    OAUTH_ISSUER=$(curl -ksS https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/.well-known/oauth-authorization-server \
        | jq -r '.issuer // empty')

    if [ -z "$OAUTH_ISSUER" ]; then
        echo "ERROR: Cannot query OAuth well-known endpoint." >&2
        exit 1
    fi

    # Extract domain from https://oauth-openshift.apps.DOMAIN
    CLUSTER_DOMAIN=$(echo "$OAUTH_ISSUER" | sed 's|https://oauth-openshift.apps.\(.*\)|\1|')

    if [ -z "$CLUSTER_DOMAIN" ]; then
        echo "ERROR: Cannot extract cluster domain from OAuth issuer: $OAUTH_ISSUER" >&2
        exit 1
    fi
fi

echo "Downloading cluster tools from: ${CLUSTER_DOMAIN}" >&2

# Download and install oc
curl -ksSL "https://downloads-openshift-console.apps.${CLUSTER_DOMAIN}/amd64/linux/oc.rhel9.tar" | tar -xf - -C /usr/local/bin/
mv /usr/local/bin/oc.rhel9 /usr/local/bin/oc
chmod +x /usr/local/bin/oc

# Download and install virtctl
echo "Looking for hyperconverged-cluster-cli-download route..." >&2
ROUTE_JSON=$(oc get route --all-namespaces -o json 2>/dev/null || true)
VIRTCTL_NS=$(echo "$ROUTE_JSON" | jq -r '.items[] | select(.metadata.name == "hyperconverged-cluster-cli-download") | .metadata.namespace' 2>/dev/null | head -1)
VIRTCTL_HOST=$(echo "$ROUTE_JSON" | jq -r '.items[] | select(.metadata.name == "hyperconverged-cluster-cli-download") | .spec.host' 2>/dev/null | head -1)

if [ -z "$VIRTCTL_NS" ] || [ -z "$VIRTCTL_HOST" ]; then
    echo "ERROR: hyperconverged-cluster-cli-download route not found in any namespace" >&2
    exit 1
fi
echo "Found route in namespace ${VIRTCTL_NS} (host: ${VIRTCTL_HOST})" >&2

echo "Waiting for hyperconverged-cluster-cli-download endpoint to become ready..." >&2
VIRTCTL_TIMEOUT=120
VIRTCTL_ELAPSED=0
VIRTCTL_READY=""
while [ "$VIRTCTL_ELAPSED" -lt "$VIRTCTL_TIMEOUT" ]; do
    VIRTCTL_READY=$(oc get endpoints hyperconverged-cluster-cli-download -n "$VIRTCTL_NS" \
        -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [ -n "$VIRTCTL_READY" ]; then
        echo "Endpoint ready after ${VIRTCTL_ELAPSED}s" >&2
        break
    fi
    echo "Endpoint not ready yet (${VIRTCTL_ELAPSED}/${VIRTCTL_TIMEOUT}s)..." >&2
    sleep 5
    VIRTCTL_ELAPSED=$((VIRTCTL_ELAPSED + 5))
done

if [ -z "$VIRTCTL_READY" ]; then
    echo "ERROR: hyperconverged-cluster-cli-download endpoint not ready after ${VIRTCTL_TIMEOUT}s" >&2
    echo "Endpoint status:" >&2
    oc get endpoints hyperconverged-cluster-cli-download -n "$VIRTCTL_NS" -o yaml 2>&1 || true
    echo "Pod status:" >&2
    oc get pods -n "$VIRTCTL_NS" -l name=hyperconverged-cluster-cli-download -o wide 2>&1 || true
    exit 1
fi

VIRTCTL_URL="https://${VIRTCTL_HOST}/amd64/linux/virtctl.tar.gz"
echo "Downloading virtctl from ${VIRTCTL_URL}..." >&2
if ! curl -ksSL --fail "$VIRTCTL_URL" | tar -xzf - -C /usr/local/bin/; then
    echo "ERROR: Failed to download virtctl from ${VIRTCTL_URL}" >&2
    exit 1
fi
chmod +x /usr/local/bin/virtctl

echo "Tools downloaded successfully" >&2
