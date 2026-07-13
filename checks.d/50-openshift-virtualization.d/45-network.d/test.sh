#!/usr/bin/bash

oc get namespace openshift-multus >/dev/null 2>&1 \
|| fail_with Availability "Multus does not seem to be available."
