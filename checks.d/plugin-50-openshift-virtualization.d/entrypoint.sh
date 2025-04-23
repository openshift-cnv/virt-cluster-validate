#!/usr/bin/bash

PLUGIN_NAME="OpenShift Virtualization"

main() {
    for STEP in $(ls -1d ??-* | sort);
    do
        export CHECK_NAME=$STEP
        $STEP/check.sh
    done
}

ping() { echo pong from $PLUGIN_NAME; }

${@:-main}
