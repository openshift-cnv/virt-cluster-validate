#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Nodes"

run() {
  WORKER_NODE_COUNT=$(oc get nodes -o names -l node-role.kubernetes.io/worker | wc -l )
  CTL_NODE_COUNT=$(oc get nodes -o names -l node-role.kubernetes.io/master | wc -l )

  if [[ "$WORKER_NODE_COUNT" > 0 && "$CTL_NODE_COUNT" = 0 ]];
  then pass_with_info Topology "Looks like a Hosted Control planes."
  elif [[ "$WORKER_NODE_COUNT" = 1 && "$CTL_NODE_COUNT" = 1 ]];
  then pass_with_info Topology "Looks like a single node cluster."
  else pass_with_info Topology "Looks like a regular cluster."
  fi

  [[ "$WORKER_NODE_COUNT" > 100 ]] && pass_with_warn Size "More workers than recommended."
}

cleanup() {
  :
}

${@:-main}
