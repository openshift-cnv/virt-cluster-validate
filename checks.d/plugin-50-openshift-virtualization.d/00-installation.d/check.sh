#!/usr/bin/bash

oc get namespace openshift-cnv \
|| fail_with Operator "The openshift-cnv namespace does not exist. Did you install OpenShift Virtualization?"

oc get -n openshift-cnv kubevirt kubevirt-kubevirt-hyperconverged \
|| fail_with OperatorDeployment "The kubevirt config kubevirt-kubevirt-hyperconverged does not exist. Did you deploy the operator?"
