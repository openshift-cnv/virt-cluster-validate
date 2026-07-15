#!/usr/bin/bash
#
# Copyright (C) 2024-2026 Red Hat, Inc.
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

oc get storageclasses -o json > storageclasses.json || fail_with Connection "Unable to get storageclasses from cluster"

cat storageclasses.json \
| jq -e '.items | length > 0' \
|| fail_with Availability "There is no storage class available. Persistent strage is not possible."
