#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Nodes"

run() {
  WORKER_NODE_COUNT=$(oc get nodes -o name -l node-role.kubernetes.io/worker | wc -l )
  CTL_NODE_COUNT=$(oc get nodes -o name -l node-role.kubernetes.io/master | wc -l )

  if [[ "$WORKER_NODE_COUNT" -gt 0 && "$CTL_NODE_COUNT" -eq 0 ]];
  then pass_with_info Topology "Looks like a Hosted Control planes."
  elif [[ "$WORKER_NODE_COUNT" -eq 1 && "$CTL_NODE_COUNT" -eq 1 ]];
  then pass_with_info Topology "Looks like a single node cluster."
  elif [[ "$WORKER_NODE_COUNT" -gt 1 && "$CTL_NODE_COUNT" -gt 1 ]];
  then pass_with_info Topology "Looks like a regular cluster."
  else fail_with Topology "Unknown topology. Any nodes at all?"
  fi

  [[ "$WORKER_NODE_COUNT" -gt 100 ]] && pass_with_warn Size "Found $WORKER_NODE_COUNT workers, which are more than recommended (100)."
}

cleanup() {
  :
}

${@:-main}
