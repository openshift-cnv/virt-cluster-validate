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
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc get crd hostpathprovisioners.hostpathprovisioner.kubevirt.io >/dev/null 2>&1 \
  || { pass_with info "HostPathProvisioner not installed"; exit 0; }

step "HPP Health"
HPP_STATUS=$(oc get hostpathprovisioners -o json 2>/dev/null \
  | jq -r '.items[0].status.conditions[]? | select(.type=="Available") | .status' 2>/dev/null)
if [ -z "$HPP_STATUS" ]; then
  pass_with warn "HostPathProvisioner conditions not yet reported (CR may be initializing)"
elif [ "$HPP_STATUS" != "True" ]; then
  pass_with warn "HostPathProvisioner is not Available (status=$HPP_STATUS)"
fi

step "VMs on HPP Storage"
HPP_PROVISIONERS=$(oc get storageclasses -o json | jq -r '
  [.items[] | select(.provisioner | test("hostpath")) | .metadata.name] | .[]
')

if [ -n "$HPP_PROVISIONERS" ]; then
  for SC in $HPP_PROVISIONERS; do
    HPP_PVCS=$(oc_cached pvcs get pvc -A -o json 2>/dev/null | jq -r --arg sc "$SC" '
      [.items[]
       | select(.spec.storageClassName == $sc)
       | select(.metadata.labels["app.kubernetes.io/managed-by"]? == "cdi-controller" or
                (.metadata.ownerReferences[]? | select(.kind == "DataVolume")))
       | "\(.metadata.namespace)/\(.metadata.name)"
      ] | .[]
    ')
    if [ -n "$HPP_PVCS" ]; then
      pass_with warn "VM PVCs on HostPathProvisioner storage class '$SC' (blocks live migration): $HPP_PVCS"
    fi
  done
fi

pass_with info "HostPathProvisioner check complete"
