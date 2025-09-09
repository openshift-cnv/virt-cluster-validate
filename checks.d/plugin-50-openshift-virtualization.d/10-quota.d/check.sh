#!/usr/bin/bash

oc get quota | wc -l | test $(cat /dev/stdin) -eq 1 \
|| pass_with warn Basic "There is a quota set on the namespace, this can break this validation. Please remove the quota if any test fails, and retry."
