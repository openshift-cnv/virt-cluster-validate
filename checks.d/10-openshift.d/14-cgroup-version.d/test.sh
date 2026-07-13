#!/usr/bin/bash

oc_cached nodes get nodes -o json > nodes.json \
  || fail_with "Unable to get nodes"

step "Cgroup Version Detection"
CGROUP_INFO=$(cat nodes.json | jq -r '
  [.items[] | {
    name: .metadata.name,
    version: (
      (.status.nodeInfo.containerRuntimeVersion // "") as $rt |
      (.metadata.annotations["machineconfiguration.openshift.io/currentConfig"] // "") as $mc |
      if ($rt | test("crun")) then "v2"
      elif (.status.nodeInfo.kernelVersion // "" | test("el9")) then "v2"
      elif (.status.nodeInfo.kernelVersion // "" | test("el7")) then "v1"
      else "unknown"
      end
    )
  }] | group_by(.version)
  | map({version: .[0].version, count: length, nodes: [.[].name][:5]})
  | .[] | "\(.version): \(.count) node(s)"
')

pass_with info "Cgroup distribution: $CGROUP_INFO"

VERSIONS=$(cat nodes.json | jq '
  [.items[] | (
    if (.status.nodeInfo.containerRuntimeVersion // "" | test("crun")) then "v2"
    elif (.status.nodeInfo.kernelVersion // "" | test("el9")) then "v2"
    elif (.status.nodeInfo.kernelVersion // "" | test("el7")) then "v1"
    else "unknown"
    end
  )] | unique
')
VERSION_COUNT=$(echo "$VERSIONS" | jq 'length')
HAS_UNKNOWN=$(echo "$VERSIONS" | jq 'any(. == "unknown")')

if [ "$HAS_UNKNOWN" == "true" ]; then
  pass_with warn "Some nodes have unrecognizable kernel versions for cgroup detection. Verify cgroup version manually."
fi

KNOWN_VERSIONS=$(echo "$VERSIONS" | jq '[.[] | select(. != "unknown")] | unique | length')
if [ "$KNOWN_VERSIONS" -gt 1 ]; then
  pass_with warn "Mixed cgroup versions detected across nodes. This can cause unpredictable container and VM behavior."
else
  TOTAL=$(cat nodes.json | jq '.items | length')
  pass_with info "Cgroup version is consistent across all $TOTAL nodes"
fi
