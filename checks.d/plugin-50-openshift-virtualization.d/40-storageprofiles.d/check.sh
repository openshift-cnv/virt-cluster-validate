#!/usr/bin/bash

oc get storageprofiles -o json > storageprofiles.json || fail_with Basic "No storageclasses found."

# No claimPropertySets, impact: User has ot specify acces and vol mode
cat storageprofiles.json \
| jq -e '[ .items[] | select(.status | has("claimPropertySets") | not) | .metadata.name] | length == 0' \
|| pass_with info Known "Some storage classes are not covered by storage profiles"

# Clone strategy 'copy', impact: Slow clone
cat storageprofiles.json \
| jq -e '[ .items[] | select(.status.cloneStrategy == "copy") | .metadata.name] | length == 0' \
|| pass_with info Clone "Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times"

cat storageprofiles.json \
| jq -e '[ .items[] | .status.claimPropertySets[]?.accessModes ] | unique | flatten | index ("ReadWriteMany")' \
|| pass_with_warn ReadWriteMany "There is no storageclass supporting ReadWriteMany, Live Migraiton will not be possible."

cat storageprofiles.json \
| jq -e '[ .items[] | .status.claimPropertySets[]?.volumeMode ] | unique | flatten | index ("Block")' \
|| pass_with info ReadWriteMany "There is now storageclass supporting Block mode, this can lead to lower performance."

#jq '[ .items[] | select(.status | has("cloneStrategy") | not) | .metadata.name] | length'
