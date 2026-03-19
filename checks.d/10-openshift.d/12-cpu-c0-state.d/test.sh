#!/usr/bin/bash

# Retrieve all worker nodes
NODES=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)

if [ -z "$NODES" ]; then
  exit 0
fi

# We need a namespace to run our temporary pods in.
NAMESPACE=$(oc config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
if [ -z "$NAMESPACE" ]; then
  NAMESPACE="default"
fi

# Use a temporary directory to collect results from concurrent subshells
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Launch a background process for each node
for NODE_NAME in $NODES; do
  (
    # Truncate node name to ensure the pod name is valid
    POD_NAME="c0-check-${NODE_NAME:0:20}-${RANDOM}"
    
    # Create a regular pod targeted at the specific node
    cat <<POD_YAML | oc create -n "$NAMESPACE" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
spec:
  nodeName: ${NODE_NAME}
  restartPolicy: Never
  containers:
  - name: checker
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    securityContext:
      privileged: true 
    command: ["/bin/bash", "-c"]
    args:
    - |
      if [ ! -d /node-sys/devices/system/cpu/cpu0/cpuidle ]; then
        echo "C0_FORCED"
        exit 0
      fi
      ACTIVE=\$(grep -s "^0$" /node-sys/devices/system/cpu/cpu*/cpuidle/state[1-9]*/disable 2>/dev/null | wc -l)
      if [ -z "\$ACTIVE" ] || [ "\$ACTIVE" -eq 0 ]; then
        echo "C0_FORCED"
      else
        echo "C_STATES_ENABLED"
      fi
    volumeMounts:
    - name: node-sys
      mountPath: /node-sys
      readOnly: true
  volumes:
  - name: node-sys
    hostPath:
      path: /sys
      type: Directory
POD_YAML

    # Poll until the pod finishes (Succeeded or Failed)
    for i in {1..30}; do
      PHASE=$(oc get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
      if [[ "$PHASE" == "Succeeded" || "$PHASE" == "Failed" ]]; then
        break
      fi
      sleep 2
    done
    
    # Retrieve the logs
    OUT=$(oc logs pod/"$POD_NAME" -n "$NAMESPACE" 2>/dev/null)
    
    # Clean up the pod immediately
    oc delete pod/"$POD_NAME" -n "$NAMESPACE" --ignore-not-found=true >/dev/null 2>&1

    if [[ "$OUT" == *"C_STATES_ENABLED"* ]]; then
      touch "$TMP_DIR/$POD_NAME.warn"
    fi
  ) &
done

# Wait for all background checks to finish
wait

WARNINGS=$(ls -1q "$TMP_DIR"/*.warn 2>/dev/null | wc -l)

if [ "$WARNINGS" -gt 0 ]; then
  pass_with warn C0_State "Found $WARNINGS worker node(s) where CPUs are not forced to C0 state via sysfs."
fi

exit 0
