#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

LOW_MEM=$(cat nodes.json | jq -r '
  [.items[]
   | select(.metadata.labels["kubevirt.io/schedulable"] == "true")
   | {
       name: .metadata.name,
       mem_bytes: (.status.allocatable.memory | gsub("Ki$";"") | tonumber * 1024)
     }
   | select(.mem_bytes < 8589934592)
   | "\(.name) (\(.mem_bytes / 1073741824 | floor)Gi allocatable)"
  ] | .[]
')

if [ -n "$LOW_MEM" ]; then
  pass_with warn "KubeVirt-schedulable nodes with less than 8Gi allocatable memory: $LOW_MEM"
fi

SCHED_COUNT=$(cat nodes.json | jq '[.items[] | select(.metadata.labels["kubevirt.io/schedulable"] == "true")] | length')
pass_with info "$SCHED_COUNT KubeVirt-schedulable nodes have adequate memory"
