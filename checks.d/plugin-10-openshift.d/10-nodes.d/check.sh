#!/usr/bin/bash

WORKER_NODE_COUNT=$(oc get nodes -o name -l node-role.kubernetes.io/worker | wc -l )
CTL_NODE_COUNT=$(oc get nodes -o name -l node-role.kubernetes.io/master | wc -l )

if [[ "$WORKER_NODE_COUNT" -gt 0 && "$CTL_NODE_COUNT" -eq 0 ]];
then pass_with info Topology "Looks like a Hosted Control planes."
elif [[ "$WORKER_NODE_COUNT" -eq 1 && "$CTL_NODE_COUNT" -eq 1 ]];
then pass_with info Topology "Looks like a single node cluster."
elif [[ "$WORKER_NODE_COUNT" -gt 1 && "$CTL_NODE_COUNT" -gt 1 ]];
then pass_with info Topology "Looks like a regular cluster."
else fail_with Topology "Unknown topology. Any nodes at all?"
fi

[[ "$WORKER_NODE_COUNT" -gt 100 ]] && pass_with warn Size "Found $WORKER_NODE_COUNT workers, which are more than recommended (100)."


if oc api-resources | grep machinehealthcheck
then pass_with info Remediation "Node remediation is provided by MachineHealthChecks"
# FIXME need to check if it's really this resource to look for
#elif oc api-resources | grep nodehealthcheck
#then pass_with_info Remediation "Node remediation is provided by NodeHealthChecks"
else fail_with Remediation "No node remediation found. Either use IPI or install a fencing solution like NHC with SNR."
fi
