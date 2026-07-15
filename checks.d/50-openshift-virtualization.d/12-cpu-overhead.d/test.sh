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

step "CPU Allocation Ratio"
RATIO=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv -o json 2>/dev/null \
  | jq -r '.spec.resourceRequirements.vmiCPUAllocationRatio // 10')
if [ "$RATIO" != "10" ]; then
  pass_with warn "Non-default vmiCPUAllocationRatio: $RATIO (default is 10)"
else
  pass_with info "vmiCPUAllocationRatio is default ($RATIO)"
fi

step "Dedicated CPU VMs"
DEDICATED=$(oc_cached vms get vm -A -o json 2>/dev/null \
  | jq '[.items[] | select(.spec.template.spec.domain.cpu.dedicatedCpuPlacement == true)] | length' 2>/dev/null \
  || echo "0")

if [ "$DEDICATED" -gt 0 ]; then
  pass_with info "Found $DEDICATED VMs with dedicated CPU placement"

  step "Node Tuning Operator"
  oc get crd performanceprofiles.performance.openshift.io >/dev/null 2>&1 \
    || pass_with warn "VMs use dedicated CPUs but PerformanceProfile CRD not found. Consider installing the Node Tuning Operator."

  PP_DEGRADED=$(oc get performanceprofiles -o json 2>/dev/null \
    | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True"))] | .[].metadata.name' 2>/dev/null)
  if [ -n "$PP_DEGRADED" ]; then
    pass_with warn "Degraded PerformanceProfiles: $PP_DEGRADED"
  fi
fi
