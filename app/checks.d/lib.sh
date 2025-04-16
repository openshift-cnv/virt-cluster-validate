#!/usr/bin/bash

install_oc() {
#curl -sL http://downloads.openshift-console.svc.cluster.local/amd64/linux/oc.tar | tar xf -
#curl -sL http://hyperconverged-cluster-cli-download.openshift-cnv.svc.cluster.local:8080/amd64/linux/virtctl.tar.gz | tar xfz -
echo TBD
}

c() { echo "# $@" ; }
n() { echo "" ; }
x() { echo "\$ $@" ; eval "$@" ; }
red() { echo -e "\e[0;31m$@\e[0m" ; }
green() { echo -e "\e[0;32m$@\e[0m" ; }
die() { red "FATAL: $@" ; exit 1 ; }
assert() { echo "(assert:) \$ $@" ; eval $@ || { echo "(assert?) FALSE" ; die "Assertion ret 0 failed: '$@'" ; } ; green "(assert?) True" ; }

append_result_json() {
    [[ "$2" =~ true|false ]] || die "pass must be true or false"
    [[ "$3" =~ INFO|WARN|FAIL ]] || die "level must be one of INFO WARN FAIL"
    cat >> result.json <<EOJ
{
  "step": "$1",
  "pass": "$2",
  "level": "$3",
  "message": "$4",
  "displayname": "$5"
}
EOJ
}

ping() { echo "pong  # $DISPLAYNAME"; }

run() { die "PLUGIN should provide this"; }
cleanup() { die "PLUGIN should provide this"; }

main() {
  local WD="/wd.d"
  local LOG_FILE="/log.txt"
  local RESULT_RAW_FILE_JSON="/result_raw.json"
  local DISPLAYNAME=${DISPLAYNAME:-$CHECK}

  export PASS=true LVL= MESSAGE= STEP=

  mkdir -p $WD

  _write_result_json() {
    append_result_json "$STEP" "$PASS" "$LVL" "$MESSAGE" "$DISPLAYNAME"
  }
 
  pass() { STEP= PASS=true MESSAGE="$@" ; _write_result_json ; }
  pass_with_warn() { STEP=$1 ; shift ; PASS=true LVL=WARN ; export MESSAGE="$@" ; _write_result_json ; }
  pass_with_info() { STEP=$1 ; shift ; PASS=true LVL=INFO ; export MESSAGE="$@" ; _write_result_json ; }
  fail_with() { STEP=$1 ; shift ; PASS=false LVL=FAIL MESSAGE="$@" ; _write_result_json ; exit 1 ; }

  (
    set -x
    pushd $WD
    run
    pass
  ) > $LOG_FILE 2>&1
  (
    set -x
    pushd $WD
    cleanup
  ) >> $LOG_FILE 2>&1
}
