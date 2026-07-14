#!/bin/bash
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
curl -ksSL "https://hyperconverged-cluster-cli-download-openshift-cnv.apps.${CLUSTER_DOMAIN}/amd64/linux/virtctl.tar.gz" | tar -xzf - -C /usr/local/bin/
chmod +x /usr/local/bin/virtctl

echo "Tools downloaded successfully" >&2
