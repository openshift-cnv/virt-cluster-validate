#!/usr/bin/bash

INFRA=$(oc get infrastructure cluster -o json | jq -re '.spec.platformSpec.type')
INFRA_INSTANCE_TYPES=$(oc get nodes -o json | jq -re '.items[] | .metadata.labels["node.kubernetes.io/instance-type"]' | sort -u)

case "$INFRA" in
  BareMetal|None) pass_with info Infrastructure "Platform '$INFRA'" ;;
               *) fail_with Infrastructure "Platform '$INFRA' with instance type '$INFRA_INSTANCE_TYPE'. This does not look like it is bare metal." ;;
esac

node.kubernetes.io/instance-type
