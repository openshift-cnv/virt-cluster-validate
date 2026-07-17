#!/usr/bin/bash
#
# Copyright (C) 2025-2026 Red Hat, Inc.
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

INFRA=$(oc get infrastructure cluster -o json | jq -re '.spec.platformSpec.type')
INFRA_INSTANCE_TYPES=$(oc_cached nodes get nodes -o json | jq -re '.items[] | .metadata.labels["node.kubernetes.io/instance-type"]' | sort -u)

case "$INFRA" in
  BareMetal|None) pass_with info Infrastructure "Platform '$INFRA'" ;;
  AWS)            pass_with warn Infrastructure "Platform '$INFRA' with '$INFRA_INSTANCE_TYPES' could be metal, might not." ;;
               *) fail_with Infrastructure "Platform '$INFRA' with instance types '$INFRA_INSTANCE_TYPES'. This does not look like it is bare metal." ;;
esac
