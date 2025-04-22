#!/usr/bin/bash

PLUGIN_NAME="OpenShift Virtualization"

main() {
    for STEP in $(ls -1d ??-* | sort);
    do
        $STEP/check.sh
    done
}

ping() { echo pong; }

${@:-main}
