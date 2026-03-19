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

    def test_runner_json_output(self):
        """Test that the runner correctly identifies passes and failures and outputs JSON."""
        
        self._create_test("10-pass.d", "#!/bin/bash\necho 'I passed!'\nexit 0")
        self._create_test("20-fail.d", "#!/bin/bash\necho 'I failed!'\nexit 1")
        
        # Run the script inside the temporary workspace, requesting JSON output
        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "json"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )
        
        # The runner should exit with code 1 because a test failed
        self.assertEqual(res.returncode, 1)
        
        # Parse the JSON output
        output = json.loads(res.stdout)
        
        # Assert the summary is correct
        self.assertEqual(output["summary"], "Passed: 1, Failed: 1, Total: 2")
        self.assertEqual(len(output["results"]), 2)
        
        # Assert the individual test results
        self.assertTrue(output["results"][0]["success"])
        self.assertTrue(any("I passed!" in log for log in output["results"][0]["log"]))
        
        self.assertFalse(output["results"][1]["success"])
        self.assertTrue(any("I failed!" in log for log in output["results"][1]["log"]))

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
            [sys.executable, str(RUNNER_SCRIPT), "-o", "json", "-f", "1", "-c", "1"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )
        
        self.assertEqual(res.returncode, 1)
        output = json.loads(res.stdout)
        
        # Verify that it aborted early and skipped at least some tests
        self.assertTrue("Skipped:" in output["summary"], f"Summary was: {output['summary']}")
        
        # Assert that the fast-failing test was captured
        executed_paths = [r["testpath"] for r in output["results"]]
        self.assertTrue(any("10-fail" in p for p in executed_paths))

    def test_runner_timeout(self):
        """Test that the runner correctly enforces timeouts and kills hung processes."""
        self._create_test("10-timeout.d", "#!/bin/bash\necho 'start'\nsleep 10\necho 'done'\nexit 0")
        
        # Run with timeout=2
        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "json", "-t", "2"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )
        
        self.assertEqual(res.returncode, 1)
        output = json.loads(res.stdout)
        
        self.assertEqual(len(output["results"]), 1)
        self.assertFalse(output["results"][0]["success"])
        self.assertTrue(any("TIMEOUT: Test exceeded 2 seconds" in log for log in output["results"][0]["log"]))
        self.assertTrue(any("start" in log for log in output["results"][0]["log"]))
        self.assertFalse(any("done" in log for log in output["results"][0]["log"]))

    def test_runner_mock_mode(self):
        """Test that the runner successfully simulates tests without executing them when --mock is used."""
        # Create a test script that would normally fail instantly with a syntax error
        self._create_test("10-syntax-error.d", "!!!this is not bash!!!")
        
        # Run with the --mock flag. Give it a long timeout so it rarely simulates a timeout.
        res = subprocess.run(
            [sys.executable, str(RUNNER_SCRIPT), "-o", "json", "--mock", "-t", "10"],
            cwd=self.workspace,
            capture_output=True,
            text=True
        )
        
        output = json.loads(res.stdout)
        
        # Ensure the test was discovered and executed
        self.assertEqual(len(output["results"]), 1)
        
        # Since it was mocked, it shouldn't have executed the bad bash script.
        # Instead, it should have generated a simulated log line.
        self.assertTrue(any("Executing simulated test" in log for log in output["results"][0]["log"]))
        
        # The report_messages should contain our simulated pass/fail messages, unless it simulated a timeout
        if output["results"][0].get("cancelled"):
            self.assertTrue(any("TIMEOUT" in log for log in output["results"][0]["log"]))
        else:
            self.assertTrue(any("simulated" in msg.lower() for msg in output["results"][0]["report_messages"]), f"report_messages were: {output['results'][0]['report_messages']}")

if __name__ == "__main__":
    unittest.main()
