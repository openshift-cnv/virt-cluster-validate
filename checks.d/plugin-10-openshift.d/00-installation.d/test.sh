#!/usr/bin/bash

step Connectivity
oc get project || fail_with "Unable to retrieve projects from cluster"

step Availability
oc get projects | grep openshift-cnv \
|| fail_with "OpenShift Virtualization does not seem to be present. Did you install the OpenShift Virtualization operator?"

step Auth
oc auth can-i list nodes || fail_with "You can not list nodes. Are you bound to the cluster-reader role? This is required by this tool."
