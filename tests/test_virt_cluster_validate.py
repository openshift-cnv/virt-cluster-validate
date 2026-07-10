import os
import sys
import json
import unittest
import subprocess
import tempfile
from pathlib import Path

# Path to the script we are testing
RUNNER_SCRIPT = Path(__file__).parent.parent / "virt-cluster-validate"

class TestVirtClusterValidate(unittest.TestCase):
    def setUp(self):
        # Create a temporary environment to act as our workspace
        self.test_dir = tempfile.TemporaryDirectory()
        self.workspace = Path(self.test_dir.name)
        
        # Create a mock checks.d directory
        self.checks_dir = self.workspace / "checks.d"
        self.checks_dir.mkdir()
        
        # We need to symlink the 'bin' directory so helper scripts work
        os.symlink(Path(__file__).parent.parent / "bin", self.workspace / "bin")

    def tearDown(self):
        self.test_dir.cleanup()

    def _create_test(self, name, content):
        """Helper to create a test script in the mock checks.d directory."""
        test_dir = self.checks_dir / name
        test_dir.mkdir(parents=True, exist_ok=True)
        test_file = test_dir / "test.sh"
        test_file.write_text(content)
        # Make the test executable
        test_file.chmod(0o755)
        return test_file

    def test_runner_ctrf_output(self):
        """Test that the runner correctly identifies passes and failures and outputs CTRF."""

        self._create_test("10-pass.d", "#!/bin/bash\necho 'I passed!'\nexit 0")
        self._create_test("20-fail.d", "#!/bin/bash\necho 'I failed!'\nexit 1")

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 1)

        output = json.loads(res.stdout)
        summary = output["results"]["summary"]
        tests = output["results"]["tests"]

        self.assertEqual(summary["passed"], 1)
        self.assertEqual(summary["failed"], 1)
        self.assertEqual(summary["tests"], 2)
        self.assertEqual(len(tests), 2)

        passed_test = next(t for t in tests if "10-pass" in t["name"])
        self.assertEqual(passed_test["status"], "passed")

        failed_test = next(t for t in tests if "20-fail" in t["name"])
        self.assertEqual(failed_test["status"], "failed")
        self.assertIn("trace", failed_test)
        self.assertTrue("I failed!" in failed_test["trace"])

    def test_runner_fail_fast(self):
        """Test that the runner correctly stops after N failures when --fail-fast is used."""

        # In a ThreadPoolExecutor with N workers, Python proactively schedules N tasks.
        # If max_workers is 1, it will queue up the first task, but it STILL pre-fetches
        # the next task and submits it to the underlying work queue. So `cancel()` can only
        # safely abort tasks that haven't been popped off the queue yet.
        #
        # By creating 4 tests and limiting workers to 1, we guarantee at least some of
        # the trailing tests are trapped in the pending queue and can be cancelled.
        self._create_test("10-fail.d", "#!/bin/bash\necho 'fail'\nexit 1")
        self._create_test("20-long.d", "#!/bin/bash\nsleep 1\nexit 0")
        self._create_test("30-long.d", "#!/bin/bash\nsleep 1\nexit 0")
        self._create_test("40-long.d", "#!/bin/bash\nsleep 1\nexit 0")

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf", "-f", "1", "-c", "1"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 1)
        output = json.loads(res.stdout)
        summary = output["results"]["summary"]

        self.assertGreater(summary["skipped"], 0, f"Summary was: {summary}")

        executed_names = [t["name"] for t in output["results"]["tests"] if t["status"] != "skipped"]
        self.assertTrue(any("10-fail" in n for n in executed_names))

    def test_runner_timeout(self):
        """Test that the runner correctly enforces timeouts and kills hung processes."""
        self._create_test("10-timeout.d", "#!/bin/bash\necho 'start'\nsleep 10\necho 'done'\nexit 0")

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf", "-t", "2"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 1)
        output = json.loads(res.stdout)
        tests = output["results"]["tests"]

        self.assertEqual(len(tests), 1)
        self.assertEqual(tests[0]["status"], "failed")
        self.assertIn("TIMEOUT", tests[0].get("trace", ""))
        self.assertIn("start", tests[0].get("trace", ""))
        self.assertNotIn("done", tests[0].get("trace", ""))

    def test_runner_mock_mode(self):
        """Test that the runner successfully simulates tests without executing them when --mock is used."""
        self._create_test("10-syntax-error.d", "!!!this is not bash!!!")

        mock_env = os.environ.copy()
        mock_env["VIRT_VALIDATE_MOCK"] = "1"
        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf", "-t", "10"],
            cwd=self.workspace,
            env=mock_env,
            capture_output=True,
            text=True
        )

        output = json.loads(res.stdout)
        tests = output["results"]["tests"]

        self.assertEqual(len(tests), 1)
        self.assertIn(tests[0]["status"], ("passed", "failed"))

    def test_ctrf_schema(self):
        """Test that -o ctrf produces a fully valid CTRF JSON report with all required fields."""
        self._create_test("10-pass.d", "#!/bin/bash\npass_with INFO 'All good'\nexit 0")
        self._create_test("20-fail.d", "#!/bin/bash\nfail_with 'Something broke'")

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 1)
        output = json.loads(res.stdout)

        self.assertIn("results", output)
        results = output["results"]
        self.assertIn("tool", results)
        self.assertIn("summary", results)
        self.assertIn("tests", results)

        self.assertEqual(results["tool"]["name"], "virt-cluster-validate")

        summary = results["summary"]
        self.assertEqual(summary["tests"], 2)
        self.assertEqual(summary["passed"], 1)
        self.assertEqual(summary["failed"], 1)
        self.assertEqual(summary["pending"], 0)
        self.assertEqual(summary["skipped"], 0)
        self.assertEqual(summary["other"], 0)
        self.assertIsInstance(summary["start"], int)
        self.assertIsInstance(summary["stop"], int)
        self.assertGreaterEqual(summary["stop"], summary["start"])

        tests = results["tests"]
        self.assertEqual(len(tests), 2)

        passed_test = next(t for t in tests if "10-pass" in t["name"])
        self.assertEqual(passed_test["status"], "passed")
        self.assertIsInstance(passed_test["duration"], int)
        self.assertIn("message", passed_test)

        failed_test = next(t for t in tests if "20-fail" in t["name"])
        self.assertEqual(failed_test["status"], "failed")
        self.assertIn("trace", failed_test)

    def test_include_filter(self):
        """Test that --include filters tests by substring match."""
        self._create_test("10-nodes.d", "#!/bin/bash\nexit 0")
        self._create_test("20-network.d", "#!/bin/bash\nexit 0")
        self._create_test("30-basic.d", "#!/bin/bash\nexit 0")

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf", "--include", "nodes,basic"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 0)
        output = json.loads(res.stdout)

        names = [t["name"] for t in output["results"]["tests"]]
        self.assertEqual(len(names), 2)
        self.assertTrue(any("nodes" in n for n in names))
        self.assertTrue(any("basic" in n for n in names))
        self.assertFalse(any("network" in n for n in names))

    def test_exclude_filter(self):
        """Test that --exclude skips tests by substring match."""
        self._create_test("10-nodes.d", "#!/bin/bash\nexit 0")
        self._create_test("20-network.d", "#!/bin/bash\nexit 0")
        self._create_test("30-basic.d", "#!/bin/bash\nexit 0")

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf", "--exclude", "network"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 0)
        output = json.loads(res.stdout)

        names = [t["name"] for t in output["results"]["tests"]]
        self.assertEqual(len(names), 2)
        self.assertTrue(any("nodes" in n for n in names))
        self.assertTrue(any("basic" in n for n in names))
        self.assertFalse(any("network" in n for n in names))

    def test_log_dir(self):
        """Test that --log-dir writes per-check log files."""
        self._create_test("10-pass.d", "#!/bin/bash\necho 'hello from test'\nexit 0")

        log_dir = self.workspace / "test-logs"

        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "ctrf", "--log-dir", str(log_dir)],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )

        self.assertEqual(res.returncode, 0)
        self.assertTrue(log_dir.exists())

        log_files = list(log_dir.iterdir())
        self.assertEqual(len(log_files), 1)
        log_content = log_files[0].read_text()
        self.assertIn("hello from test", log_content)

if __name__ == "__main__":
    unittest.main()
