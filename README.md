
> [!NOTE]
> This is an early stage prototype, it's runing unprivileged (thus is likely unable to do real harm),
> but it might destroy workloads, and is at least difficult to debug right now.

## Objectives

* Fast, timeboxed 3min
* User understandable
* Easy to extend
* For arbitrary clusters
* Run with cluster-reader permissions

## Why not tier1/2?

They are great candidates!
However, testsuites often have expectations on the environment, thus are not easy to run in arbitrary clusters.
Testsuites also usually have a long run time.

However, with some work, testsuites can be consumed in this tool to prvide checks if they meet the tools requirements.

## Open items

- Allow checks to be run locally
- Improve debuggability

## Usage

First you have to build the containerized plugins:

```console
$ bash build-plugins.sh
~/work/openshift/virt-cluster-validate/checks.d ~/work/openshift/virt-cluster-validate
# BUILDING plugin-10-openshift.d/
STEP 1/10: FROM quay.io/fedora/fedora:latest
STEP 2/10: RUN dnf install -y jq
…
+ ping
+ echo pong from plugin-10-openshift
pong from plugin-10-openshift
pong from OpenShift Virtualization
$ 
```

Now you can run the checks:

> [!NOTE]
> `oc` and `virtctl` are expected to be in your `PATH`.

```console
$ oc login …  # Login
$ oc project my-test-project  # Switch to the project where the testing can be performed

$ rm -rf results.d/*  # Cleanup any previous results
$ virt-cluster-validate
# Starting validation ...
# Dispatching 'quay.io/virt-cluster-validate/plugin-10-openshift:latest' ...
# Dispatching 'quay.io/virt-cluster-validate/plugin-50-openshift-virtualization:latest' ...
# Waiting for jobs to complete
# All jobs completed.
# Summarizing results from '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d/'
PASS - plugin-10-openshift / Installation
INFO - plugin-10-openshift / Nodes: Topology - Looks like a regular cluster.
PASS - plugin-10-openshift / Nodes
PASS - plugin-10-openshift / Host network
PASS - plugin-10-openshift / Storage classes
WARN - OpenShift Virtualization / Quota: Basic - There is a quota set on the namespace, this can break this validation. Please remove the quota if any test fails, and retry.
PASS - OpenShift Virtualization / Quota
INFO - OpenShift Virtualization / Storage profiles: Known - Some storage classes are not covered by storage profiles
INFO - OpenShift Virtualization / Storage profiles: Clone - Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times
PASS - OpenShift Virtualization / Storage profiles
PASS - OpenShift Virtualization / Secondary networks
PASS - OpenShift Virtualization / Snapshots
PASS - OpenShift Virtualization / Live Migration
FAIL - OpenShift Virtualization / : Scheduling - Unable to schedule high performance VMs. Is the CPU manager enabled?
PASS - OpenShift Virtualization / 
PASS - OpenShift Virtualization / Rebalancing

real	1m34,687s
user	0m0,097s
sys	0m0,086s
$
```

A JSON report is available at `results.d/result.json`:

```console
$ cat results.d/result.json 
{
  "apiVersion": "validate.kubevirt.io/v1alpha1",
  "kind": "Results",
  "items": [
    {
      "plugin": {
        "name": "plugin-10-openshift",
        "image": "quay.io/virt-cluster-validate/plugin-10-openshift:latest"
      },
      "check": {
        "name": "00-installation.d",
        "displayname": "Installation",
        "pass": true
      }
    },

```
