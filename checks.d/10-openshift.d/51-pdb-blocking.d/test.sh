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

oc get pdb -A -o json > pdb.json \
  || fail_with "Unable to get PodDisruptionBudgets"

BLOCKING=$(cat pdb.json | jq -r '
  [.items[]
   | select(.status.disruptionsAllowed == 0)
   | select(.metadata.name | test("^kubevirt-disruption-budget-") | not)
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | .[]
')

if [ -n "$BLOCKING" ]; then
  pass_with warn "PDBs blocking disruptions (disruptionsAllowed=0): $BLOCKING"
fi

pass_with info "No PDBs are currently blocking disruptions"
