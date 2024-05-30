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
# Tasks: /var/home/fabiand/work/openshift/virt-cluster-validate/app/checks.d (5)
# Results: /var/home/fabiand/work/openshift/virt-cluster-validate/app/results.d/2024-05-30-10:57:51.d
# Starting validation ...
# Dispatching 'high-performance' ...
# Dispatching 'live-migration' ...
# Dispatching 'snapshots' ...
# Dispatching 'storageclasses' ...
# Dispatching 'storageprofiles' ...
# Waiting for jobs to complete
# All jobs completed. Summarizing.
FAIL - High Performance VMs / Scheduling - Unable to schedule high performance VMs
PASS - Live Migration 
PASS - Snapshots 
PASS - Storage classes 
       Storage profiles / Known - INFO - Some storage classes are not covered by storage profiles
       Storage profiles / Clone - INFO - Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times
PASS - Storage profiles 

real	0m48,542s
user	0m13,765s
sys	0m2,913s
$

$ rm -rf results.d/* ; AS_JSON=true time bash virt-cluster-validate 
# Tasks: /var/home/fabiand/work/openshift/virt-cluster-validate/app/checks.d (5)
# Results: /var/home/fabiand/work/openshift/virt-cluster-validate/app/results.d/2024-05-30-10:57:51.d
# Starting validation ...
# Dispatching 'high-performance' ...
# Dispatching 'live-migration' ...
# Dispatching 'snapshots' ...
# Dispatching 'storageclasses' ...
# Dispatching 'storageprofiles' ...
# Waiting for jobs to complete
# All jobs completed. Summarizing.
FAIL - High Performance VMs / Scheduling - Unable to schedule high performance VMs
PASS - Live Migration 
PASS - Snapshots 
PASS - Storage classes 
       Storage profiles / Known - INFO - Some storage classes are not covered by storage profiles
       Storage profiles / Clone - INFO - Some storage classes only support dumb cloning, leading to slow cloning and potentially slow VM launch times
PASS - Storage profiles 

real	0m48,542s
user	0m13,765s
sys	0m2,913s
$

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
      "message": "Unable to schedule high performance VMs"
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
