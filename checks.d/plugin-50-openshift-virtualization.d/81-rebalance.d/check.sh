#!/usr/bin/bash

source ../lib.sh

export CHECK_DISPLAYNAME="Rebalancing"

promql() { oc exec -c prometheus -n openshift-monitoring prometheus-k8s-0 -- curl -s --data-urlencode "query=$@" http://localhost:9090/api/v1/query ; }

run() {
    echo TBD FIXME
}

cleanup() {
    :
}

${@:-main}
