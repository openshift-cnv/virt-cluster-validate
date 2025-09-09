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
plugin() {
  plugin_metadata "$1" "$2" > plugin.result.json
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
 
pass_with_info() {
  jq_update_last_step_file -e --arg msg $1 '. | .status.level = "info" | .status.message = msg'; }
pass_with_warn() {
  jq_update_last_step_file -e --arg msg $1 '. | .status.level = "warn" | .status.message = msg'; }
fail_with() {
  jq_update_last_step_file -e --arg msg $1 '. | .status.pass = false | .status.level = "err" | .status.message = msg'; }

run_plugin() {
    plugin "$PLUGIN_NAME"

    # Find all checks, and run call them
    ls -1d ??-* | sort | xargs -n 1 -P 10 -- $0 run_check 
}

run_check() {
  local LOG_FILE="${RESULTSD}/log.txt"
  pushd $1
  check "$1"
  (
    ./check.sh run
    ./check.sh cleanup
  ) >> $LOG_FILE 2>&1
}


(
$@
)
