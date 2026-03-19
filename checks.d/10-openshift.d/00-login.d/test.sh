#!/usr/bin/bash

# Check if we are logged in
oc whoami > /dev/null 2>&1 || fail_with "Not logged into an OpenShift cluster. Please run 'oc login' first."

# Report success with the current user name
pass_with info login "Logged in as $(oc whoami)"
