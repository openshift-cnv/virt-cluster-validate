#!/usr/bin/bash

INFRA=$(oc get infrastructure cluster -o json | jq -re '.spec.platformSpec.type')

case "$INFRA" in
  BareMetal|None) pass_with info Infrastructure "Platform '$INFRA'" ;;
               *) fail_with Infrastructure "Platform '$INFRA'. This does not look like it is bare metal." ;;
esac
