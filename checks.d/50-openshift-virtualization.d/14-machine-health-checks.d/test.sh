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

REMEDIATION_FOUND=false

step "NodeHealthCheck"
if oc get crd nodehealthchecks.remediation.medik8s.io >/dev/null 2>&1; then
  pass_with info "NodeHealthCheck (NHC) CRD is available"
  REMEDIATION_FOUND=true
fi

step "SelfNodeRemediation"
if oc get crd selfnoderemediations.remediation.medik8s.io >/dev/null 2>&1; then
  pass_with info "SelfNodeRemediation (SNR) CRD is available"
  REMEDIATION_FOUND=true
fi

step "FenceAgentsRemediation"
if oc get crd fenceagentsremediations.fence-agents-remediation.medik8s.io >/dev/null 2>&1; then
  pass_with info "FenceAgentsRemediation (FAR) CRD is available"
  REMEDIATION_FOUND=true
fi

step "MachineDeletionRemediation"
if oc get crd machinedeletionremediations.machine-deletion-remediation.medik8s.io >/dev/null 2>&1; then
  pass_with info "MachineDeletionRemediation (MDR) CRD is available"
  REMEDIATION_FOUND=true
fi

if [ "$REMEDIATION_FOUND" = "false" ]; then
  pass_with warn "No node remediation operators found. Consider installing NHC with SNR for production HA."
fi
