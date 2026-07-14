#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

VM_NAMESPACES=$(oc_cached vms get vm -A -o json 2>/dev/null \
  | jq -r '[.items[].metadata.namespace] | unique | .[]' 2>/dev/null)

[[ -n "$VM_NAMESPACES" ]] \
  || { pass_with info "No VMs found on the cluster"; exit 0; }

UNPROTECTED=""
for NS in $VM_NAMESPACES; do
  QUOTA_COUNT=$(oc get resourcequotas -n "$NS" --no-headers 2>/dev/null | wc -l)
  LR_COUNT=$(oc get limitranges -n "$NS" --no-headers 2>/dev/null | wc -l)
  if [ "$QUOTA_COUNT" -eq 0 ] && [ "$LR_COUNT" -eq 0 ]; then
    UNPROTECTED="$UNPROTECTED $NS"
  fi
done

if [ -n "$UNPROTECTED" ]; then
  pass_with warn "VM namespaces without ResourceQuota or LimitRange:$UNPROTECTED"
fi

NS_COUNT=$(echo "$VM_NAMESPACES" | wc -l)
pass_with info "Checked $NS_COUNT VM namespace(s) for resource governance"
