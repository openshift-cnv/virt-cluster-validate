## Objectives

* Fast, timeboxed 3min
* User understandable
* Actionable

## Example

```console
$ cd apps
$ $ rm -rf results.d/* ; time bash virt-cluster-validate 
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
```
