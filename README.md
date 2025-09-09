
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
# virt-cluster-validate (3d47616)
# Di 9. Sep 11:49:53 CEST 2025
# Building container image
61534bf9f0d8a71cd17d0026fab19346cd472bda4648069ef65eada98e8b1872
# Starting validation ...
Running './plugin-10-openshift.d/00-installation.d/test.sh'
Running './plugin-10-openshift.d/10-nodes.d/test.sh'
Running './plugin-10-openshift.d/11-host-network.d/test.sh'
Running './plugin-10-openshift.d/30-monitoring.d/test.sh'
Running './plugin-10-openshift.d/40-storageclasses.d/test.sh'
Running './plugin-50-openshift-virtualization.d/00-installation.d/test.sh'
Running './plugin-50-openshift-virtualization.d/10-quota.d/test.sh'
Running './plugin-50-openshift-virtualization.d/20-bare-metal.d/test.sh'
Running './plugin-50-openshift-virtualization.d/40-storageprofiles.d/test.sh'
Running './plugin-50-openshift-virtualization.d/45-network.d/test.sh'
Running './plugin-50-openshift-virtualization.d/50-snapshots.d/test.sh'
Running './plugin-50-openshift-virtualization.d/70-live-migration.d/test.sh'
Running './plugin-50-openshift-virtualization.d/80-high-performance.d/test.sh'
Running './plugin-50-openshift-virtualization.d/81-rebalance.d/test.sh'
Completed './plugin-50-openshift-virtualization.d/81-rebalance.d/test.sh'
Completed './plugin-10-openshift.d/11-host-network.d/test.sh'
Completed './plugin-10-openshift.d/30-monitoring.d/test.sh'
Completed './plugin-50-openshift-virtualization.d/20-bare-metal.d/test.sh'
Completed './plugin-50-openshift-virtualization.d/10-quota.d/test.sh'
Completed './plugin-10-openshift.d/40-storageclasses.d/test.sh'
Completed './plugin-50-openshift-virtualization.d/40-storageprofiles.d/test.sh'
Completed './plugin-50-openshift-virtualization.d/00-installation.d/test.sh'
Completed './plugin-50-openshift-virtualization.d/45-network.d/test.sh'
Completed './plugin-10-openshift.d/00-installation.d/test.sh'
Completed './plugin-10-openshift.d/10-nodes.d/test.sh'
PASS plugin-10-openshift.d/00-installation.d/
PASS plugin-10-openshift.d/10-nodes.d/
     INFO: Topology Looks like a regular cluster.
     INFO: Remediation Node remediation is provided by MachineHealthChecks
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-10-openshift.d/10-nodes.d//log.txt' for more details
PASS plugin-10-openshift.d/11-host-network.d/
PASS plugin-10-openshift.d/30-monitoring.d/
PASS plugin-10-openshift.d/40-storageclasses.d/
PASS plugin-50-openshift-virtualization.d/00-installation.d/
PASS plugin-50-openshift-virtualization.d/10-quota.d/
     WARN: Basic There is a quota set on the namespace, this can break this validation. Please remove the quota if any test fails, and retry.
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-50-openshift-virtualization.d/10-quota.d//log.txt' for more details
PASS plugin-50-openshift-virtualization.d/20-bare-metal.d/
     INFO: Infrastructure Platform 'BareMetal'
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-50-openshift-virtualization.d/20-bare-metal.d//log.txt' for more details
PASS plugin-50-openshift-virtualization.d/40-storageprofiles.d/
     INFO: Known Some storage classes are not covered by storage profiles
     INFO: Clone Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-50-openshift-virtualization.d/40-storageprofiles.d//log.txt' for more details
PASS plugin-50-openshift-virtualization.d/45-network.d/
FAIL plugin-50-openshift-virtualization.d/50-snapshots.d/
     FAIL: Create Failed to create snapshot with default storageclass
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-50-openshift-virtualization.d/50-snapshots.d//log.txt' for more details
FAIL plugin-50-openshift-virtualization.d/70-live-migration.d/
     FAIL: Scheduling Unable to schedule VMs?
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-50-openshift-virtualization.d/70-live-migration.d//log.txt' for more details
FAIL plugin-50-openshift-virtualization.d/80-high-performance.d/
     FAIL: Scheduling Unable to schedule high performance VMs. Is the CPU manager enabled?
     See '/var/home/fabiand/work/openshift/virt-cluster-validate/results.d//plugin-50-openshift-virtualization.d/80-high-performance.d//log.txt' for more details
PASS plugin-50-openshift-virtualization.d/81-rebalance.d/
# Di 9. Sep 11:51:58 CEST 2025

real	2m4,101s
user	0m0,119s
sys	0m0,106s
$
```
