#!/usr/bin/bash

set -x

export PLUGIN_DISPLAYNAME="OpenShift"

main() {
    for STEP in $(ls -1d ??-* | sort);
    do
        export CHECK_NAME=$STEP
        $STEP/check.sh
    done
}

ping() { echo pong from $PLUGIN_NAME; }

${@:-main}
