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
# Try both possible route names (downstream openshift-cnv, upstream kubevirt-hyperconverged)
for namespace in openshift-cnv kubevirt-hyperconverged; do
    VIRTCTL_URL="https://hyperconverged-cluster-cli-download-${namespace}.apps.${CLUSTER_DOMAIN}/amd64/linux/virtctl.tar.gz"
    if curl -ksSL "$VIRTCTL_URL" | tar -xzf - -C /usr/local/bin/ 2>/dev/null; then
        chmod +x /usr/local/bin/virtctl
        break
    fi
done

if [ ! -f /usr/local/bin/virtctl ]; then
    echo "ERROR: Failed to download virtctl from any known route" >&2
    exit 1
fi

echo "Tools downloaded successfully" >&2
