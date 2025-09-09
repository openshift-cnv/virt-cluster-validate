#!/usr/bin/bash

oc get namespace openshift-monitoring \
|| fail_with Basic "OpenShift Monitoring does not seem to be available. Did you install the nmstate operator?"
