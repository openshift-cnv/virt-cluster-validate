#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc_cached vms get vm -A -o json > vms.json 2>/dev/null \
  || { pass_with info "No VirtualMachine resources found"; exit 0; }

CLUSTER_EVICTION=$(oc get kubevirt kubevirt -n openshift-cnv -o json 2>/dev/null \
  | jq -r '.spec.configuration.evictionStrategy // empty' 2>/dev/null)

MIGRATE_VMS=$(cat vms.json | jq --arg default "${CLUSTER_EVICTION:-none}" '
  [.items[] | select(
    ((.spec.template.spec.evictionStrategy // $default) | IN("LiveMigrate","LiveMigrateIfPossible"))
  )]
')
MIGRATE_COUNT=$(echo "$MIGRATE_VMS" | jq 'length')

[[ "$MIGRATE_COUNT" -gt 0 ]] \
  || { pass_with info "No VMs with LiveMigrate eviction strategy"; exit 0; }

step "PVC Access Modes"
oc_cached pvcs get pvc -A -o json > pvc.json 2>/dev/null

PROBLEM_VMS=$(echo "$MIGRATE_VMS" | jq -r --slurpfile pvcs pvc.json '
  [.[]
   | . as $vm
   | .spec.template.spec.volumes[]?
   | select(.persistentVolumeClaim or .dataVolume)
   | {
       vm: "\($vm.metadata.namespace)/\($vm.metadata.name)",
       ns: $vm.metadata.namespace,
       pvc: (.persistentVolumeClaim.claimName // .dataVolume.name)
     }
   | . as $ref
   | ($pvcs[0].items[] | select(.metadata.namespace == $ref.ns and .metadata.name == $ref.pvc)) as $p
   | select([$p.spec.accessModes[]? | select(. == "ReadWriteMany")] | length == 0)
   | "\($ref.vm)(pvc=\($ref.pvc),access=\([$p.spec.accessModes[]?] | join(",")))"
  ] | unique | .[]
')

if [ -n "$PROBLEM_VMS" ]; then
  pass_with warn "LiveMigrate VMs with non-RWX PVCs (cannot migrate): $PROBLEM_VMS"
fi

pass_with info "$MIGRATE_COUNT VMs with LiveMigrate eviction strategy checked for storage compatibility"
