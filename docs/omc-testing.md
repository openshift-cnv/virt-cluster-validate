<!--
Copyright (C) 2026 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Offline Testing with omc

## Overview

Most validation checks in this project use read-only `oc get` commands to inspect
cluster state. This makes them testable **without a live cluster** by using
[omc](https://github.com/gmeghnag/omc) (OpenShift Must-Gather Client), which
replays `oc get` responses from must-gather archives.

This approach enables:

- **Negative integration tests** — synthetic must-gather fixtures that simulate
  broken clusters (degraded operators, not-ready nodes, etc.) to verify that
  checks correctly detect and report problems.
- **Post-mortem analysis** — running the full validation suite against a
  must-gather captured from a real cluster, without needing cluster access.

## Architecture

```
check script  →  oc (or oc_cached)  →  oc shim  →  omc get  →  must-gather files
                                         │
                                         ├─ whoami        → canned "test-admin"
                                         ├─ auth can-i    → always "yes"
                                         ├─ cluster-info  → canned response
                                         ├─ api-resources → exit 1 (not supported)
                                         ├─ get           → omc get (with exit-code fix)
                                         └─ create/delete → exit 1 (rejected)
```

The **oc shim** (`tests/omc-shim/oc`) intercepts all `oc` calls and:
- Delegates `oc get` to `omc get`, which reads from the active must-gather
- Corrects omc's exit code when resources are not found (omc returns exit 0
  with "No resources found", but real `oc` returns exit 1)
- Returns canned responses for `whoami`, `auth can-i`, `cluster-info`
- Rejects mutating operations (`create`, `apply`, `delete`, `exec`)

The shim is placed first in `$PATH`, so both direct `oc` calls and `oc_cached`
calls (which internally `exec oc`) route through it.

## Check Compatibility

| Category | Count | Examples |
|----------|-------|---------|
| **omc-compatible** (pure `oc get`) | ~41 | node-health, cluster-operators, pv-status, mcp-health |
| **Partially compatible** (needs shim stubs) | ~5 | login, installation (use `whoami`, `auth can-i`) |
| **Incompatible** (mutating or unsupported) | 8 | basic VM test, live-migration, snapshots, rebalance, deprecated-apis |

Incompatible checks (6 mutating + 2 needing `oc api-resources`) are automatically
excluded by the Makefile and test harness.

## Running Checks Against a Must-Gather

### Prerequisites

Install [omc](https://github.com/gmeghnag/omc):

```bash
curl -sL https://github.com/gmeghnag/omc/releases/latest/download/omc_Linux_x86_64.tar.gz \
  | tar xzf - -C ~/.local/bin omc
```

### Usage

```bash
# Run all read-only checks against a must-gather directory
make must-gather-check MUST_GATHER=/path/to/must-gather

# Run with verbose output
make must-gather-check MUST_GATHER=/path/to/must-gather ARGS="-v"

# Run specific checks only
make must-gather-check MUST_GATHER=/path/to/must-gather ARGS="--include node-health,cluster-operators"

# Output as CTRF JSON
make must-gather-check MUST_GATHER=/path/to/must-gather ARGS="-o ctrf"

# Output as JUnit XML
make must-gather-check MUST_GATHER=/path/to/must-gather ARGS="-o junit"
```

The `MUST_GATHER` path can be:
- An extracted must-gather directory
- A `.tar.gz` tarball
- A remote URL (omc downloads and extracts it)

## Integration Tests

### Running

```bash
# Run only the omc integration tests
make test-omc

# Run all tests (unit + omc)
make test
```

### Test Scenarios

The integration tests use synthetic must-gather fixtures generated at test time
(no large files committed to git). Each scenario creates a minimal must-gather
directory with specific broken states:

**Baseline scenarios:**

| Test | Scenario | Check | Expected |
|------|----------|-------|----------|
| `test_nodes_not_ready_fails` | `worker-1` has `Ready=False` | `13-node-health` | FAIL |
| `test_operator_degraded_fails` | `monitoring` operator `Degraded=True` | `03-cluster-operators` | FAIL |
| `test_cluster_upgrading_warns` | ClusterVersion `Progressing=True` | `02-cluster-version` | WARN |
| `test_pv_released_warns` | PV `pv-data` in `Released` phase | `42-pv-status` | WARN |
| `test_mcp_degraded_fails` | `worker` MCP `Degraded=True` | `16-mcp-health` | FAIL |
| `test_healthy_baseline_passes` | Everything healthy | Multiple checks | All PASS |

**Expanded scenarios (OCP platform checks):**

| Test | Scenario | Check | Expected |
|------|----------|-------|----------|
| `test_pod_restarts_warns` | Pod with 1000+ restarts in openshift-cnv | `50-pod-restarts` | WARN |
| `test_pdb_blocking_warns` | PDB with `disruptionsAllowed=0` | `51-pdb-blocking` | WARN |
| `test_cvo_overrides_warns` | CVO with unmanaged overrides | `52-operator-state` | WARN |
| `test_dns_degraded_fails` | DNS operator `Degraded=True` | `22-dns-health` | FAIL |
| `test_machine_config_drift_warns` | Node `currentConfig != desiredConfig` | `15-machine-config` | WARN |
| `test_no_storage_classes_fails` | No StorageClasses defined | `40-storageclasses` | FAIL |
| `test_monitoring_pods_unhealthy_warns` | `thanos-querier` in CrashLoopBackOff | `31-monitoring-pods` | WARN |
| `test_third_party_provisioner_warns` | SC with unsupported provisioner | `41-storage-provisioners` | WARN |
| `test_ipv6_non_ovn_warns` | Dual-stack with OpenShiftSDN | `20-ip-stack` | WARN |
| `test_node_topology_unknown_fails` | Only master nodes, no workers | `10-nodes` | FAIL |

**Expanded scenarios (CNV-specific checks):**

| Test | Scenario | Check | Expected |
|------|----------|-------|----------|
| `test_cnv_not_installed_fails` | No `openshift-cnv` namespace | `00-installation` | FAIL |
| `test_not_bare_metal_fails` | Infrastructure platform is vSphere | `20-bare-metal` | FAIL |
| `test_memory_overcommit_warns` | HCO overcommit at 150% | `13-memory-overhead` | WARN |
| `test_no_remediation_warns` | No remediation CRDs found | `14-machine-health-checks` | WARN |
| `test_vm_no_eviction_warns` | Running VM without LiveMigrate | `30-vm-run-strategy` | WARN |
| `test_upgrade_readiness_degraded_fails` | HCO `Degraded=True` | `85-upgrade-readiness` | FAIL |
| `test_storageprofile_no_rwx_warns` | No StorageProfile with RWX | `40-storageprofiles` | WARN |
| `test_migration_storage_warns` | LiveMigrate VM with RWO PVC | `60-migration-storage` | WARN |

### Test Isolation

Each test creates an isolated environment:
- Temporary workspace with symlinked `checks.d/` and `bin/`
- `HOME` set to a temp directory so `omc use` writes its config there
- The oc shim is prepended to `$PATH`

### Adding New Scenarios

1. Add a resource builder to `tests/fixtures.py` if the resource type isn't
   already covered (follow the `make_node()` pattern).

2. Add a scenario builder function (follow the `build_nodes_not_ready()` pattern):
   ```python
   def build_my_scenario(base_path):
       root = build_fixture(base_path)
       _add_baseline(root)
       # Add resources representing the broken state
       write_cluster_resource(root, ...)
       return base_path
   ```

3. Add a test method in `tests/test_omc_integration.py`:
   ```python
   def test_my_scenario(self):
       self._setup_fixture(build_my_scenario)
       ctrf = self._run_checks(include="my-check-name")
       test = self._get_test(ctrf, "my-check-name")
       self.assertEqual(test["status"], "failed")
       self.assertIn("expected-message", test.get("message", ""))
   ```

## Must-Gather Directory Structure

omc expects this layout (which mirrors what `oc adm must-gather` produces):

```
must-gather/
  cluster-scoped-resources/
    core/
      nodes/<name>.yaml
      namespaces/<name>.yaml
      persistentvolumes/<name>.yaml
    config.openshift.io/
      clusterversions/<name>.yaml
      clusteroperators/<name>.yaml
      infrastructures/<name>.yaml
      networks/<name>.yaml
    machineconfiguration.openshift.io/
      machineconfigpools/<name>.yaml
    operator.openshift.io/
      dnses/<name>.yaml
    storage.k8s.io/
      storageclasses/<name>.yaml
    cdi.kubevirt.io/
      storageprofiles/<name>.yaml
    apiextensions.k8s.io/
      customresourcedefinitions/<name>.yaml
  namespaces/
    <namespace>/
      <namespace>.yaml
      core/
        pods.yaml                              # Aggregate list
        persistentvolumeclaims/<name>.yaml
      policy/
        poddisruptionbudgets/<name>.yaml
      hco.kubevirt.io/
        hyperconvergeds/<name>.yaml
      kubevirt.io/
        kubevirts/<name>.yaml
        virtualmachines/<name>.yaml
      operators.coreos.com/
        clusterserviceversions/<name>.yaml
```

omc auto-discovers CRDs from `apiextensions.k8s.io/customresourcedefinitions/`
to learn about non-core resource types. The fixture generator includes CRD stubs
for: ClusterOperator, MachineConfigPool, Infrastructure, DNS, MachineSet,
Network, ClusterServiceVersion, HyperConverged, KubeVirt, VirtualMachine,
StorageProfile, and Subscription.

**Note:** omc returns exit 0 with "No resources found" for missing resources
(unlike real `oc` which returns exit 1). The oc shim detects this pattern and
corrects the exit code so check scripts behave correctly.

## CI

The omc integration tests run in a dedicated GitHub Actions workflow
(`.github/workflows/omc-integration.yml`) that installs omc and runs the tests.
They are separate from the main lint workflow so failures in omc integration
don't block unrelated changes.
