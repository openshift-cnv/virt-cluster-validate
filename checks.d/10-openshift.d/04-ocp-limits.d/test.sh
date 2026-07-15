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

step "Node count"
NODE_COUNT=$(oc get nodes --no-headers 2>/dev/null | wc -l)
[[ "$NODE_COUNT" -le 2000 ]] \
  || pass_with warn "Node count ($NODE_COUNT) exceeds OCP tested limit of 2000"
pass_with info "Nodes: $NODE_COUNT"

step "Namespace count"
NS_COUNT=$(oc get namespaces --no-headers 2>/dev/null | wc -l)
[[ "$NS_COUNT" -le 10000 ]] \
  || pass_with warn "Namespace count ($NS_COUNT) exceeds OCP tested limit of 10000"

step "CRD count"
CRD_COUNT=$(oc get crds --no-headers 2>/dev/null | wc -l)
[[ "$CRD_COUNT" -le 1024 ]] \
  || pass_with warn "CRD count ($CRD_COUNT) exceeds OCP tested limit of 1024"

step "Service count"
SVC_COUNT=$(oc get services -A --no-headers 2>/dev/null | wc -l)
[[ "$SVC_COUNT" -le 10000 ]] \
  || pass_with warn "Service count ($SVC_COUNT) exceeds OCP tested limit of 10000"

pass_with info "Resource counts within limits (nodes=$NODE_COUNT, ns=$NS_COUNT, crds=$CRD_COUNT, svcs=$SVC_COUNT)"
