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

step Connectivity
oc whoami
oc whoami --show-server
oc cluster-info || fail_with "Unable to reach the cluster API"

step Availability
oc get namespace openshift-cnv >/dev/null 2>&1 \
|| fail_with "OpenShift Virtualization does not seem to be present. Did you install the OpenShift Virtualization operator?"

step Auth
oc auth can-i list nodes || fail_with "You can not list nodes. Are you bound to the cluster-reader role? This is required by this tool."
