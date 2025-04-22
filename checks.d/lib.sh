#!/usr/bin/bash

#set -x

install_oc() {
  #curl -sL http://downloads.openshift-console.svc.cluster.local/amd64/linux/oc.tar | tar xf -
  #curl -sL http://hyperconverged-cluster-cli-download.openshift-cnv.svc.cluster.local:8080/amd64/linux/virtctl.tar.gz | tar xfz -
  echo TBD
}

WD="${WD:-(mktemp -d)}"
RESULTSD="${RESULTSD:-$WD}"

#
# Internal
#
c() { echo "# $@" ; }
n() { echo "" ; }
x() { echo "\$ $@" ; eval "$@" ; }
red() { echo -e "\e[0;31m$@\e[0m" ; }
green() { echo -e "\e[0;32m$@\e[0m" ; }
die() { red "FATAL: $@" ; exit 1 ; }
assert() { echo "(assert:) \$ $@" ; eval $@ || { echo "(assert?) FALSE" ; die "Assertion ret 0 failed: '$@'" ; } ; green "(assert?) True" ; }

#
# Return results
#
append_result_json() {
    [[ "$PASS" =~ true|false ]] || die "pass must be true or false"
    [[ "$LVL" =~ INFO|WARN|FAIL ]] || die "level must be one of INFO WARN FAIL"
    cat >> ${RESULTSD}/result.json <<EOJ
{
  "plugin": {
    "name": "$PLUGIN_NAME"
  },
  "check": {
    "name": "$CHECK_NAME"
   },
  "step": {
    "name": "$STEP",
    "displayname": "$DISPLAYNAME",
    "pass": $PASS,
    "level": "$LVL",
    "message": "$MESSAGE"
  }
}
EOJ
}
 
pass() { STEP= PASS=true LVL=INFO MESSAGE="$@" ; append_result_json ; }
pass_with_warn() { STEP=$1 ; shift ; PASS=true LVL=WARN ; export MESSAGE="$@" ; append_result_json ; }
pass_with_info() { STEP=$1 ; shift ; PASS=true LVL=INFO ; export MESSAGE="$@" ; append_result_json ; }
fail_with() { STEP=$1 ; shift ; PASS=false LVL=FAIL MESSAGE="$@" ; append_result_json ; exit 1 ; }

#
# Expected to be called from external
#
ping() { echo "pong  # $DISPLAYNAME $(date)" | tee /results.d/pong; }
run() { die "PLUGIN should provide this"; }
cleanup() { die "PLUGIN should provide this"; }
main() {
  local LOG_FILE="${RESULTSD}/log.txt"
  local DISPLAYNAME=${DISPLAYNAME:-$CHECK}

  export PASS=true LVL= MESSAGE= STEP=

  (
    set -x
    pushd $WD
    run
    pass
    cleanup
  ) >> $LOG_FILE 2>&1
}
