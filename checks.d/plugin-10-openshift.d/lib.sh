#!/usr/bin/bash

#set -x

install_oc() {
  #curl -sL http://downloads.openshift-console.svc.cluster.local/amd64/linux/oc.tar | tar xf -
  #curl -sL http://hyperconverged-cluster-cli-download.openshift-cnv.svc.cluster.local:8080/amd64/linux/virtctl.tar.gz | tar xfz -
  echo TBD
}

WD="${WD:-$(mktemp -d)}"
RESULTSD="${RESULTSD:-$WD}"
RESULTFILE="${RESULTFILE:-${RESULTSD}/result.json}"

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


# a plugin is a containerimage, it fails if any check fails
# a plugin has many checks, it fails if any step fails
# a check has many steps, each can fail, warn, or info

plugin_metadata() {
  [[ -z "$1" ]] && die "PLUGIN_NAME must be set"
  [[ -z "$2" ]] && die "PLUGIN_DISPLAYNAME must be set"
  jq -e "." > result.json <<EOJ
{
  "kind": "Plugin",
  "metadata": {
    "name": "$1",
    "displayname": "$2",
    "containerImage": "$3"
  },
  "status": {
    "pass": true
  }
EOJ
}

check_metadata() {
  [[ -z "$1" ]] && die "CHECK_NAME must be set"
  [[ -z "$2" ]] && die "CHECK_DISPLAYNAME must be set"
  [[ "$3" =~ true|false ]] || die "pass must be true or false"
  jq -e "." > result.json <<EOJ
{
  "kind": "Check",
  "metadata": {
    "name": "$1",
    "displayname": "$2",
  },
  "status": {
    "pass": true
    "message": "$4"
  }
}
EOJ
}
check() {
  check_metadata > $1.check.result.json
}

step_metadata() {
  [[ -z "$1" ]] && die "STEP_NAME must be set"
  jq -e "." > result.json <<EOJ
{
  "kind": "Step",
  "metadata": {
    "name": "$1",
  },
  "status": {
    "pass": true
    "level": "",
    "message": ""
  }
}
EOJ
}
step() {
  local STEP_NAME="$1"
  local STEP_NO=$(ls -1 *.step.result.json | wc -l)
  step_metadata $STEP_NAME > "${STEP_NO}-${STEP_NAME}".step.result.json
}
last_step_file() { ls -1 *.step.result.json | sort -h | tail -n 1 ; }
jq_update_last_step_file() {
  cat "$(last_step_file)" | jq -e $@ > ".tmp.$(last_step_file)" ;
  mv ".tmp.$(last_step_file)" "$(last_step_file)" ; }

#
# Return results
#
 
pass()           { true ; }
pass_with_info() {
  jq_update_last_step_file -e --arg msg $1 '. | .status.level = "info" | .status.message = msg'; }
pass_with_warn() {
  jq_update_last_step_file -e --arg msg $1 '. | .status.level = "warn" | .status.message = msg'; }
fail_with() {
  jq_update_last_step_file -e --arg msg $1 '. | .status.pass = false | .status.level = "err" | .status.message = msg'; }

#
# Expected to be called from external
#
ping() { echo "pong  # $DISPLAYNAME $(date)" | tee /results.d/pong; }
run() { die "PLUGIN should provide this"; }
cleanup() { die "PLUGIN should provide this"; }

# mian of a chcek
main() {
  local LOG_FILE="${RESULTSD}/log.txt"

export CHECK_DISPLAYNAME=${CHECK_DISPLAYNAME:-$CHECK_NAME}
  export PASS=true LVL= MESSAGE= STEP=

  (
    set -x
    pushd $WD
    plugin "
    run
    pass
    cleanup
  ) >> $LOG_FILE 2>&1
}
