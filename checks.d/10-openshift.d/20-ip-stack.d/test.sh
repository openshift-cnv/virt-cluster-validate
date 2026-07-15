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

oc get network.config.openshift.io cluster -o json > net.json \
  || fail_with "Unable to get cluster network config"

NETWORK_TYPE=$(cat net.json | jq -r '.status.networkType // .spec.networkType // "unknown"')

HAS_IPV6=$(cat net.json | jq '
  ([.status.clusterNetwork // .spec.clusterNetwork // [] | .[].cidr | select(contains(":"))] | length > 0)
  or ([.status.serviceNetwork // .spec.serviceNetwork // [] | .[] | select(contains(":"))] | length > 0)
')

if [ "$HAS_IPV6" = "true" ]; then
  if [ "$NETWORK_TYPE" != "OVNKubernetes" ]; then
    pass_with warn "IPv6/dual-stack detected but network type is $NETWORK_TYPE (OVNKubernetes required for IPv6)"
  else
    pass_with info "Dual-stack/IPv6 with OVNKubernetes - supported configuration"
  fi
else
  pass_with info "IPv4-only cluster with $NETWORK_TYPE network type"
fi
