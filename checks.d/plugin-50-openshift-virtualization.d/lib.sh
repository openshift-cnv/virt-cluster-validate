#!/usr/bin/bash

#set -x

install_oc() {
  #curl -sL http://downloads.openshift-console.svc.cluster.local/amd64/linux/oc.tar | tar xf -
  #curl -sL http://hyperconverged-cluster-cli-download.openshift-cnv.svc.cluster.local:8080/amd64/linux/virtctl.tar.gz | tar xfz -
  echo TBD
}

WD="${WD:-$(mktemp -d)}"
RESULTSD="${RESULTSD:-$WD}"
RESULTFILE="${RESULTSD}/result.json"

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
    [[ -z "$PLUGIN_NAME" ]] && die "PLUGIN_NAME must be set"
    [[ -z "$CHECK_NAME" ]] && die "CHECK_NAME must be set"
    [[ -z "$CHECK_DISPLAYNAME" ]] && die "CHECK_DISPLAYNAME must be set"
    [[ "$PASS" =~ true|false ]] || die "pass must be true or false"
    [[ "$LVL" =~ INFO|WARN|ERR ]] || die "level must be one of INFO WARN ERR"
    cat <<EOJ | { if [[ -z "$STEP" ]]; then jq "del(.step)"; else cat; fi  } >> $RESULTFILE
{
  "plugin": {
    "name": "$PLUGIN_NAME",
    "image": "$PLUGIN_IMAGE_URL"
  },
  "check": {
    "name": "$CHECK_NAME",
    "displayname": "$CHECK_DISPLAYNAME",
    "message": "$MESSAGE",
    "pass": ${CHECK_PASS:-true}
  },
  "step": {
    "name": "$STEP",
    "pass": $PASS,
    "level": "$LVL",
    "message": "$MESSAGE"
  }
}
EOJ
}
 
pass()           { STEP=""         ; PASS=true  LVL="INFO" MESSAGE="$@" ; append_result_json ; }
pass_with_info() { STEP=$1 ; shift ; PASS=true  LVL="INFO" MESSAGE="$@" ; append_result_json ; }
pass_with_warn() { STEP=$1 ; shift ; PASS=true  LVL="WARN" MESSAGE="$@" ; append_result_json ; }
fail_with()      { STEP=$1 ; shift ; PASS=false LVL="ERR " MESSAGE="$@" CHECK_PASS=false ; append_result_json ; exit 1 ; }

#
# Expected to be called from external
#
ping() { echo "pong  # $DISPLAYNAME $(date)" | tee /results.d/pong; }
run() { die "PLUGIN should provide this"; }
cleanup() { die "PLUGIN should provide this"; }
main() {
  local LOG_FILE="${RESULTSD}/log.txt"

export CHECK_DISPLAYNAME=${CHECK_DISPLAYNAME:-$CHECK_NAME}
  export PASS=true LVL= MESSAGE= STEP=

  (
    set -x
    pushd $WD
    run
    pass
    cleanup
  ) >> $LOG_FILE 2>&1
}
