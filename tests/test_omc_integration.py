# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Integration tests using omc to run real check scripts against
# synthetic must-gather fixtures that simulate broken clusters.

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from fixtures import (
    build_cluster_upgrading,
    build_cnv_not_installed,
    build_cvo_overrides,
    build_dns_degraded,
    build_healthy,
    build_ipv6_non_ovn,
    build_machine_config_drift,
    build_mcp_degraded,
    build_memory_overcommit,
    build_migration_storage,
    build_monitoring_pods_unhealthy,
    build_no_remediation,
    build_no_storage_classes,
    build_node_topology_unknown,
    build_nodes_not_ready,
    build_not_bare_metal,
    build_operator_degraded,
    build_pdb_blocking,
    build_pod_restarts,
    build_pv_unhealthy,
    build_storageprofile_no_rwx,
    build_third_party_provisioner,
    build_upgrade_readiness_degraded,
    build_vm_no_eviction,
)

RUNNER_SCRIPT = Path(__file__).parent.parent / "virt-cluster-validate"
PROJECT_ROOT = Path(__file__).parent.parent
OMC_SHIM_DIR = Path(__file__).parent / "omc-shim"


@unittest.skipUnless(shutil.which("omc"), "omc not installed, skipping omc integration tests")
class TestOmcIntegration(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.workspace = Path(self.test_dir.name) / "workspace"
        self.workspace.mkdir()

        os.symlink(PROJECT_ROOT / "checks.d", self.workspace / "checks.d")
        os.symlink(PROJECT_ROOT / "bin", self.workspace / "bin")

        self.fake_home = Path(self.test_dir.name) / "home"
        self.fake_home.mkdir()

        self.fixture_dir = Path(self.test_dir.name) / "fixture"
        self.fixture_dir.mkdir()

    def tearDown(self):
        self.test_dir.cleanup()

    def _setup_fixture(self, builder):
        builder(self.fixture_dir)
        env = os.environ.copy()
        env["HOME"] = str(self.fake_home)
        subprocess.run(
            ["omc", "use", str(self.fixture_dir)],
            env=env, check=True,
            capture_output=True,
        )

    def _run_checks(self, include=None, exclude=None):
        env = os.environ.copy()
        env["HOME"] = str(self.fake_home)
        env["PATH"] = f"{OMC_SHIM_DIR}:{env.get('PATH', '')}"

        cmd = [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf"]
        if include:
            cmd += ["--include", include]
        if exclude:
            cmd += ["--exclude", exclude]

        result = subprocess.run(
            cmd, cwd=self.workspace,
            capture_output=True, text=True, env=env,
        )

        if not result.stdout.strip():
            self.fail(
                f"Runner produced no CTRF output.\n"
                f"exit code: {result.returncode}\n"
                f"stderr: {result.stderr}"
            )

        return json.loads(result.stdout)

    def _get_test(self, ctrf, name_substring):
        for t in ctrf["results"]["tests"]:
            if name_substring in t["name"]:
                return t
        self.fail(f"No test matching '{name_substring}' in CTRF output")

    # ------------------------------------------------------------------
    # Original negative scenarios
    # ------------------------------------------------------------------

    def test_nodes_not_ready_fails(self):
        self._setup_fixture(build_nodes_not_ready)
        ctrf = self._run_checks(include="13-node-health")

        test = self._get_test(ctrf, "13-node-health")
        self.assertEqual(test["status"], "failed")
        self.assertIn("worker-1", test.get("message", "") + test.get("trace", ""))

    def test_operator_degraded_fails(self):
        self._setup_fixture(build_operator_degraded)
        ctrf = self._run_checks(include="03-cluster-operators")

        test = self._get_test(ctrf, "03-cluster-operators")
        self.assertEqual(test["status"], "failed")
        self.assertIn("monitoring", test.get("message", "") + test.get("trace", ""))

    def test_cluster_upgrading_warns(self):
        self._setup_fixture(build_cluster_upgrading)
        ctrf = self._run_checks(include="02-cluster-version")

        test = self._get_test(ctrf, "02-cluster-version")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg or "upgrading" in msg.lower() or "4.17.5" in msg,
            f"Expected upgrade warning, got: {msg}",
        )

    def test_pv_released_warns(self):
        self._setup_fixture(build_pv_unhealthy)
        ctrf = self._run_checks(include="42-pv-status")

        test = self._get_test(ctrf, "42-pv-status")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "pv-data" in msg,
            f"Expected WARN about pv-data, got: {msg}",
        )

    def test_mcp_degraded_fails(self):
        self._setup_fixture(build_mcp_degraded)
        ctrf = self._run_checks(include="16-mcp-health")

        test = self._get_test(ctrf, "16-mcp-health")
        self.assertEqual(test["status"], "failed")
        self.assertIn("worker", test.get("message", "") + test.get("trace", ""))

    # ------------------------------------------------------------------
    # Original positive baseline
    # ------------------------------------------------------------------

    def test_healthy_baseline_passes(self):
        self._setup_fixture(build_healthy)
        checks = "13-node-health,03-cluster-operators,02-cluster-version"
        ctrf = self._run_checks(include=checks)

        for name in ("13-node-health", "03-cluster-operators", "02-cluster-version"):
            test = self._get_test(ctrf, name)
            self.assertEqual(
                test["status"], "passed",
                f"{name} should pass on healthy cluster, got {test['status']}: "
                f"{test.get('message', '')}",
            )

    # ------------------------------------------------------------------
    # Expanded negative scenarios
    # ------------------------------------------------------------------

    def test_pod_restarts_warns(self):
        self._setup_fixture(build_pod_restarts)
        ctrf = self._run_checks(include="50-pod-restarts")

        test = self._get_test(ctrf, "50-pod-restarts")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "virt-handler" in msg,
            f"Expected WARN about virt-handler restarts, got: {msg}",
        )

    def test_pdb_blocking_warns(self):
        self._setup_fixture(build_pdb_blocking)
        ctrf = self._run_checks(include="51-pdb-blocking")

        test = self._get_test(ctrf, "51-pdb-blocking")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "my-critical-pdb" in msg,
            f"Expected WARN about PDB blocking, got: {msg}",
        )

    def test_cvo_overrides_warns(self):
        self._setup_fixture(build_cvo_overrides)
        ctrf = self._run_checks(include="52-operator-state")

        test = self._get_test(ctrf, "52-operator-state")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "override" in msg.lower(),
            f"Expected WARN about CVO overrides, got: {msg}",
        )

    def test_dns_degraded_fails(self):
        self._setup_fixture(build_dns_degraded)
        ctrf = self._run_checks(include="22-dns-health")

        test = self._get_test(ctrf, "22-dns-health")
        self.assertEqual(test["status"], "failed")
        msg = test.get("message", "") + test.get("trace", "")
        self.assertIn("DNS", msg)

    def test_machine_config_drift_warns(self):
        self._setup_fixture(build_machine_config_drift)
        ctrf = self._run_checks(include="15-machine-config")

        test = self._get_test(ctrf, "15-machine-config")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "worker-1" in msg,
            f"Expected WARN about worker-1 drift, got: {msg}",
        )

    def test_no_storage_classes_fails(self):
        self._setup_fixture(build_no_storage_classes)
        ctrf = self._run_checks(include="40-storageclasses")

        test = self._get_test(ctrf, "40-storageclasses")
        self.assertEqual(test["status"], "failed")

    def test_monitoring_pods_unhealthy_warns(self):
        self._setup_fixture(build_monitoring_pods_unhealthy)
        ctrf = self._run_checks(include="31-monitoring-pods")

        test = self._get_test(ctrf, "31-monitoring-pods")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "thanos-querier" in msg,
            f"Expected WARN about thanos-querier, got: {msg}",
        )

    def test_third_party_provisioner_warns(self):
        self._setup_fixture(build_third_party_provisioner)
        ctrf = self._run_checks(include="41-storage-provisioners")

        test = self._get_test(ctrf, "41-storage-provisioners")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg,
            f"Expected WARN about third-party provisioner, got: {msg}",
        )

    def test_ipv6_non_ovn_warns(self):
        self._setup_fixture(build_ipv6_non_ovn)
        ctrf = self._run_checks(include="20-ip-stack")

        test = self._get_test(ctrf, "20-ip-stack")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "IPv6" in msg,
            f"Expected WARN about IPv6 with non-OVN, got: {msg}",
        )

    def test_node_topology_unknown_fails(self):
        self._setup_fixture(build_node_topology_unknown)
        ctrf = self._run_checks(include="10-nodes")

        test = self._get_test(ctrf, "10-nodes")
        self.assertEqual(test["status"], "failed")

    def test_cnv_not_installed_fails(self):
        self._setup_fixture(build_cnv_not_installed)
        ctrf = self._run_checks(include="50-openshift-virtualization.d/00-installation")

        test = self._get_test(ctrf, "50-openshift-virtualization.d/00-installation")
        self.assertEqual(test["status"], "failed")

    def test_not_bare_metal_fails(self):
        self._setup_fixture(build_not_bare_metal)
        ctrf = self._run_checks(include="20-bare-metal")

        test = self._get_test(ctrf, "20-bare-metal")
        self.assertEqual(test["status"], "failed")
        msg = test.get("message", "") + test.get("trace", "")
        self.assertIn("VSphere", msg)

    def test_memory_overcommit_warns(self):
        self._setup_fixture(build_memory_overcommit)
        ctrf = self._run_checks(include="13-memory-overhead")

        test = self._get_test(ctrf, "13-memory-overhead")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "150" in msg,
            f"Expected WARN about 150% overcommit, got: {msg}",
        )

    def test_no_remediation_warns(self):
        self._setup_fixture(build_no_remediation)
        ctrf = self._run_checks(include="14-machine-health-checks")

        test = self._get_test(ctrf, "14-machine-health-checks")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "remediation" in msg.lower(),
            f"Expected WARN about missing remediation, got: {msg}",
        )

    def test_vm_no_eviction_warns(self):
        self._setup_fixture(build_vm_no_eviction)
        ctrf = self._run_checks(include="30-vm-run-strategy")

        test = self._get_test(ctrf, "30-vm-run-strategy")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "test-vm-1" in msg,
            f"Expected WARN about test-vm-1 eviction, got: {msg}",
        )

    def test_upgrade_readiness_degraded_fails(self):
        self._setup_fixture(build_upgrade_readiness_degraded)
        ctrf = self._run_checks(include="85-upgrade-readiness")

        test = self._get_test(ctrf, "85-upgrade-readiness")
        self.assertEqual(test["status"], "failed")

    def test_storageprofile_no_rwx_warns(self):
        self._setup_fixture(build_storageprofile_no_rwx)
        ctrf = self._run_checks(include="40-storageprofiles")

        test = self._get_test(ctrf, "40-storageprofiles")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "ReadWriteMany" in msg,
            f"Expected WARN about missing RWX, got: {msg}",
        )

    def test_migration_storage_warns(self):
        self._setup_fixture(build_migration_storage)
        ctrf = self._run_checks(include="60-migration-storage")

        test = self._get_test(ctrf, "60-migration-storage")
        self.assertEqual(test["status"], "passed")
        msg = test.get("message", "")
        self.assertTrue(
            "WARN" in msg and "migrate-vm" in msg,
            f"Expected WARN about migrate-vm storage, got: {msg}",
        )


if __name__ == "__main__":
    unittest.main()
