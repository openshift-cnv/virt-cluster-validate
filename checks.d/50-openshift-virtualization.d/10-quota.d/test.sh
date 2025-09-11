#!/usr/bin/bash

[[ "$(oc get quota -o name | wc -l)" -eq 0 ]] \
|| pass_with warn "There is a quota set on the namespace, this can break this validation. Please remove the quota if any test fails, and retry."
