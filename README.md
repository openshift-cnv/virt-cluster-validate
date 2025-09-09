
> [!NOTE]
> This is an early stage prototype, it's runing unprivileged (thus is likely unable to do real harm),
> but it might destroy workloads, and is at least difficult to debug right now.

If [`virt-host-validate`](https://libvirt.org/manpages/virt-host-validate.html) is validating a hosts virtualization setup
then this tool is validating a clusters virtualization setup.

## Objectives

* Fast, timeboxed 3min
* User understandable
* Easy to extend
* For arbitrary clusters
* Run with cluster-reader permissions
* There is no skip - Either the cluster is okay, or not

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
```

Now you can run the checks:

> [!NOTE]
> `oc` and `virtctl` are expected to be in your `PATH`.

```console
$ oc login …  # Login
$ oc project my-test-project  # Switch to the project where the testing can be performed

$ rm -rf results.d/*  # Cleanup any previous results
$ virt-cluster-validate
# virt-cluster-validate (50e8c09)
# Di 9. Sep 12:15:07 CEST 2025
# Building container image
b94497c4cf55bae961166a86dc7ac910dbe7ee02d8a56c56164f775f301f5ba5
# Starting validation ...
Running './10-openshift.d/00-installation.d/test.sh'
…
Completed './50-openshift-virtualization.d/80-high-performance.d/test.sh'
PASS 10-openshift.d/00-installation.d/
PASS 10-openshift.d/10-nodes.d/
     INFO: Topology Looks like a regular cluster.
     INFO: Remediation Node remediation is provided by MachineHealthChecks
     See 'results.d/10-openshift.d/10-nodes.d/log.txt' for more details
PASS 10-openshift.d/11-host-network.d/
PASS 10-openshift.d/30-monitoring.d/
PASS 10-openshift.d/40-storageclasses.d/
PASS 50-openshift-virtualization.d/00-installation.d/
PASS 50-openshift-virtualization.d/10-quota.d/
     WARN: Basic There is a quota set on the namespace, this can break this validation. Please remove the quota if any test fails, and retry.
     See 'results.d/50-openshift-virtualization.d/10-quota.d/log.txt' for more details
PASS 50-openshift-virtualization.d/20-bare-metal.d/
     INFO: Infrastructure Platform 'BareMetal'
     See 'results.d/50-openshift-virtualization.d/20-bare-metal.d/log.txt' for more details
PASS 50-openshift-virtualization.d/40-storageprofiles.d/
     INFO: Clone Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times
     See 'results.d/50-openshift-virtualization.d/40-storageprofiles.d/log.txt' for more details
PASS 50-openshift-virtualization.d/45-network.d/
PASS 50-openshift-virtualization.d/50-snapshots.d/
PASS 50-openshift-virtualization.d/70-live-migration.d/
     INFO: No permission to perform live migration. This is ok since 4.19+
     See 'results.d/50-openshift-virtualization.d/70-live-migration.d/log.txt' for more details
PASS 50-openshift-virtualization.d/80-high-performance.d/
     WARN: Scheduling Unable to schedule high performance VMs. Is the CPU manager enabled?
     See 'results.d/50-openshift-virtualization.d/80-high-performance.d/log.txt' for more details
PASS 50-openshift-virtualization.d/81-rebalance.d/
# Di 9. Sep 12:15:41 CEST 2025

real	0m33,055s
user	0m0,128s
sys	0m0,113s
$
```
