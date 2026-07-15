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

oc get storageprofiles.cdi.kubevirt.io -o json | tee storageprofiles.json || fail_with Basic "No storageclasses found."

# No claimPropertySets, impact: User has ot specify acces and vol mode
cat storageprofiles.json \
| jq -e '[ .items[] | select(.status | has("claimPropertySets") | not) | .metadata.name] | length == 0' \
|| pass_with info "Profile - Some storage classes are not covered by storage profiles"

# Clone strategy 'copy', impact: Slow clone
cat storageprofiles.json \
| jq -e '[ .items[] | select(.status.cloneStrategy == "copy") | .metadata.name] | length == 0' \
|| pass_with warn "Dump cloning - Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times"

cat storageprofiles.json \
| jq -e '[ .items[] | .status.claimPropertySets[]?.accessModes ] | unique | flatten | index ("ReadWriteMany")' \
|| pass_with warn "RWX - There is no storageclass supporting ReadWriteMany, Live Migraiton will not be possible."

cat storageprofiles.json \
| jq -e '[ .items[] | .status.claimPropertySets[]?.volumeMode ] | unique | flatten | index ("Block")' \
|| pass_with info "Block - There is now storageclass supporting Block mode, this can lead to lower performance."

#jq '[ .items[] | select(.status | has("cloneStrategy") | not) | .metadata.name] | length'
