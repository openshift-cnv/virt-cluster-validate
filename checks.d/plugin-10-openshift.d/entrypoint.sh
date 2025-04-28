#!/usr/bin/bash

export PLUGIN_DISPLAYNAME="OpenShift"

main() {
    set -m
    for STEP in $(ls -1d ??-* | sort);
    do
        (
        export CHECK_NAME=$STEP
        $STEP/check.sh
        ) &
    done
    wait -f
}

ping() { echo pong from $PLUGIN_NAME; }

${@:-main}
