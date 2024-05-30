## Objectives

* Fast, timeboxed 3min
* User understandable
* Easy to extend
* For arbitrary user clusters

## Why not tier1/2?

They are great candidates!
However, testsuites often have expectations on the environment, thus are not easy to run in arbitrary clusters.
Testsuites also usually have a long run time.

However, with some work, testsuites can be consumed in this tool to prvide checks if they meet the tools requirements.

## Example

```console
$ cd apps
$ rm -rf results.d/* ; time bash virt-cluster-validate 
# Tasks: /var/home/fabiand/work/openshift/virt-cluster-validate/app/checks.d (8)
# Results: /var/home/fabiand/work/openshift/virt-cluster-validate/app/results.d/2024-05-30-11:15:23.d
# Starting validation ...
# Dispatching 'high-performance' ...
# Dispatching 'host-network' ...
# Dispatching 'installation' ...
# Dispatching 'live-migration' ...
# Dispatching 'network' ...
# Dispatching 'snapshots' ...
# Dispatching 'storageclasses' ...
# Dispatching 'storageprofiles' ...
# Waiting for jobs to complete
# All jobs completed. Summarizing.
FAIL - High Performance VMs / Scheduling - Unable to schedule high performance VMs. Is the CPU manager enabled?
PASS - Host network 
PASS - Installation 
FAIL - Live Migration / Scheduling - Unable to schedule VMs?
PASS - Secondary networks 
FAIL - Snapshots / Restore - Failed to restore snapshots
PASS - Storage classes 
       Storage profiles / Known - INFO - Some storage classes are not covered by storage profiles
       Storage profiles / Clone - INFO - Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times
PASS - Storage profiles 

real	1m0,643s
user	0m12,735s
sys	0m2,570s
$

$ rm -rf results.d/* ; AS_JSON=true time bash virt-cluster-validate 
# Tasks: /var/home/fabiand/work/openshift/virt-cluster-validate/app/checks.d (8)
# Results: /var/home/fabiand/work/openshift/virt-cluster-validate/app/results.d/2024-05-30-11:17:00.d
# Starting validation ...
# Dispatching 'high-performance' ...
# Dispatching 'host-network' ...
# Dispatching 'installation' ...
# Dispatching 'live-migration' ...
# Dispatching 'network' ...
# Dispatching 'snapshots' ...
# Dispatching 'storageclasses' ...
# Dispatching 'storageprofiles' ...
# Waiting for jobs to complete
# All jobs completed. Summarizing.
{
  "apiVersion": "validate.kubevirt.io/v1alpha1",
  "kind": "Results",
  "items": [
    {
      "check": "high-performance",
      "subcheck": "Scheduling",
      "displayname": "High Performance VMs",
      "pass": false,
      "level": "FAIL",
      "message": "Unable to schedule high performance VMs. Is the CPU manager enabled?"
    },
    {
      "check": "host-network",
      "subcheck": "",
      "displayname": "Host network",
      "pass": true,
      "level": "",
      "message": ""
    },
    {
      "check": "installation",
      "subcheck": "",
      "displayname": "Installation",
      "pass": true,
      "level": "",
      "message": ""
    },
    {
      "check": "live-migration",
      "subcheck": "",
      "displayname": "Live Migration",
      "pass": true,
      "level": "",
      "message": ""
    },
    {
      "check": "network",
      "subcheck": "",
      "displayname": "Secondary networks",
      "pass": true,
      "level": "",
      "message": ""
    },
    {
      "check": "snapshots",
      "subcheck": "",
      "displayname": "Snapshots",
      "pass": true,
      "level": "",
      "message": ""
    },
    {
      "check": "storageclasses",
      "subcheck": "",
      "displayname": "Storage classes",
      "pass": true,
      "level": "",
      "message": ""
    },
    {
      "check": "storageprofiles",
      "subcheck": "Known",
      "displayname": "Storage profiles",
      "pass": true,
      "level": "INFO",
      "message": "Some storage classes are not covered by storage profiles"
    },
    {
      "check": "storageprofiles",
      "subcheck": "Clone",
      "displayname": "Storage profiles",
      "pass": true,
      "level": "INFO",
      "message": "Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times"
    },
    {
      "check": "storageprofiles",
      "subcheck": "",
      "displayname": "Storage profiles",
      "pass": true,
      "level": "INFO",
      "message": ""
    }
  ]
}
$
```
