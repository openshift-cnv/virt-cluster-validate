#!/usr/bin/bash

oc get namespace openshift-cnv >/dev/null 2>&1 \
  || { pass_with info "OpenShift Virtualization not installed, skipping"; exit 0; }

oc_cached vms get vm -A -o json > vms.json 2>/dev/null \
  || { pass_with info "No VirtualMachine resources found"; exit 0; }

WIN_VMS=$(cat vms.json | jq '[.items[] | select(
  ((.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win"))) or
  ((.spec.template.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win")))
)] | length')

[[ "$WIN_VMS" -gt 0 ]] \
  || { pass_with info "No Windows VMs found on the cluster"; exit 0; }

pass_with info "Found $WIN_VMS Windows VM(s)"

step "Hyper-V Enlightenments"
NO_HYPERV=$(cat vms.json | jq -r '
  [.items[]
   | select(
       ((.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win"))) or
       ((.spec.template.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win")))
     )
   | select(.spec.template.spec.domain.features.hyperv == null)
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | .[]
')
if [ -n "$NO_HYPERV" ]; then
  pass_with warn "Windows VMs without Hyper-V enlightenments (poor performance): $NO_HYPERV"
fi

step "Disk Bus"
SATA_VMS=$(cat vms.json | jq -r '
  [.items[]
   | select(
       ((.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win"))) or
       ((.spec.template.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win")))
     )
   | select(.spec.template.spec.domain.devices.disks[]? | select(.disk.bus == "sata" or .cdrom.bus == "sata"))
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | unique | .[]
')
if [ -n "$SATA_VMS" ]; then
  pass_with warn "Windows VMs using SATA disk bus instead of virtio (lower performance): $SATA_VMS"
fi

step "Disk Cache"
UNSAFE_CACHE=$(cat vms.json | jq -r '
  [.items[]
   | select(
       ((.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win"))) or
       ((.spec.template.metadata.labels // {}) | to_entries[]? | select(.key | test("os.template.kubevirt.io/win")))
     )
   | select(.spec.template.spec.domain.devices.disks[]? | select(.cache == "unsafe"))
   | "\(.metadata.namespace)/\(.metadata.name)"
  ] | unique | .[]
')
if [ -n "$UNSAFE_CACHE" ]; then
  pass_with warn "Windows VMs with unsafe disk cache (data loss risk): $UNSAFE_CACHE"
fi
