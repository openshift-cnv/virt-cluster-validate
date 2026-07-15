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

oc get storageclasses -o json > sc.json \
  || fail_with "Unable to get StorageClasses"

SUPPORTED_PATTERN="kubernetes.io/|csi.ovirt.org|openshift-storage|ebs.csi.aws.com|disk.csi.azure.com|pd.csi.storage.gke.io|cinder.csi.openstack.org|vpc.block.csi.ibm.io|lvms.topolvm.io|manila.csi.openstack.org|hostpath.csi.kubevirt.io"

THIRD_PARTY=$(cat sc.json | jq -r --arg p "$SUPPORTED_PATTERN" '
  [.items[]
   | select(.provisioner | test($p) | not)
   | "\(.metadata.name) (provisioner=\(.provisioner))"
  ] | .[]
')

if [ -n "$THIRD_PARTY" ]; then
  pass_with warn "StorageClasses with third-party provisioners (not Red Hat supported): $THIRD_PARTY"
fi

TOTAL=$(cat sc.json | jq '.items | length')
pass_with info "All $TOTAL StorageClass provisioners reviewed"
