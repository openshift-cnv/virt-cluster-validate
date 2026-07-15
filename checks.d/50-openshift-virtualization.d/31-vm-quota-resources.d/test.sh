#!/usr/bin/bash
#
# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { skip_with "OpenShift Virtualization not installed, skipping"; }

VM_NAMESPACES=$(oc_cached vms get vm -A -o json 2>/dev/null \
  | jq -r '[.items[].metadata.namespace] | unique | .[]' 2>/dev/null)

[[ -n "$VM_NAMESPACES" ]] \
  || { skip_with "No VMs found on the cluster"; }

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
