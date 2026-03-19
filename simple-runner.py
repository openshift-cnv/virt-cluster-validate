#!/usr/bin/env python3

import os, sys, json, subprocess
from pathlib import Path

def run_test(test_file, env):
    """Executes a single test script and returns its results as a dictionary."""
    print(f"Running test: {test_file.parent}", file=sys.stderr)
    
    # Run bash -e inside the test's directory with the augmented PATH
    res = subprocess.run(
        ["bash", "-e", test_file.name],
        cwd=test_file.parent,
        env=env,
        capture_output=True,
        text=True
    )
    
    output = (res.stdout + res.stderr).splitlines()
    return {
        "testpath": str(test_file),
        "success": res.returncode == 0,
        "errors": output if res.returncode != 0 else [],
        "warnings": [line for line in output if "warn" in line.lower()]
    }

def main():
    # Setup PATH to include the local 'bin' folder
    bin_path = os.path.abspath("bin")
    env = {**os.environ, "PATH": f"{bin_path}{os.pathsep}{os.environ.get('PATH', '')}"}
    
    # Discover all tests, run them, and collect results
    results = [run_test(t, env) for t in sorted(Path("checks.d").rglob("test.sh"))]
    
    # Summarize and output
    failed_count = sum(1 for r in results if not r["success"])
    print(f"\nSummary: Passed: {len(results) - failed_count}, Failed: {failed_count}", file=sys.stderr)
    
    print(json.dumps(results, indent=2))
    sys.exit(1 if failed_count > 0 else 0)

if __name__ == "__main__":
    main()
