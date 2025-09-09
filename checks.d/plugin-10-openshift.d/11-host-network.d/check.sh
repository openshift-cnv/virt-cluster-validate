#!/usr/bin/bash

oc get crd nodenetworkconfigurationpolicies.nmstate.io \
|| fail_with Configuration "nmstate the tool for host network configuration does not seem to be installed. Did you install the nmstate operator?"
