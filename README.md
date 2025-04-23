
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

- Improve debuggability
- Allow checks to be run locally
- Fetch `virtctl` and `oc` from the env
- Decouple plugin building and running them

## Extending

Just drop a new dir and check into `checks.d/plugin-*` or create a new plugin if it's a different project, product, or vendor.

## Usage

First you have to build the containerized plugins:

```console
$ dnf install -y podman  # podman is required
$ bash build-plugins.sh
# BUILDING plugin-10-openshift.d/
...
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
# Summarizing results from '.../virt-cluster-validate/results.d/'
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
FAIL - OpenShift Virtualization / High Performance VMs: Scheduling - Unable to schedule high performance VMs. Is the CPU manager enabled?
PASS - OpenShift Virtualization / High Performance VMs
PASS - OpenShift Virtualization / Rebalancing

real	1m46,773s
user	0m0,076s
sys	0m0,086s
$
```

A JSON report is available at `results.d/result.json`:

```console
$ cat results.d/result.json 
{
  "apiVersion": "validate.kubevirt.openshift.com/v1alpha1",
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
