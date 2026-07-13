#!/usr/bin/bash

step Connectivity
oc whoami
oc whoami --show-server
oc cluster-info || fail_with "Unable to reach the cluster API"

step Availability
oc get namespace openshift-cnv >/dev/null 2>&1 \
|| fail_with "OpenShift Virtualization does not seem to be present. Did you install the OpenShift Virtualization operator?"

step Auth
oc auth can-i list nodes || fail_with "You can not list nodes. Are you bound to the cluster-reader role? This is required by this tool."
