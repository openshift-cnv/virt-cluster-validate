#!/usr/bin/bash

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
