#!/usr/bin/env python3

import os, sys, json, subprocess, argparse
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def run_test(test_file, env):
    """Executes a single test script and returns its results as a dictionary."""
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
        "log": output,
        "errors": output if res.returncode != 0 else [],
        "warnings": [line for line in output if "warn" in line.lower()]
    }

def main():
    parser = argparse.ArgumentParser(description="Simple test runner for virt-cluster-validate checks.")
    parser.add_argument(
        "-o", "--output", 
        choices=["json", "human"], 
        default="human", 
        help="Output format (default: human)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show test output in human-readable mode"
    )
    args = parser.parse_args()

    # Setup PATH to include the local 'bin' folder
    bin_path = os.path.abspath("bin")
    env = {**os.environ, "PATH": f"{bin_path}{os.pathsep}{os.environ.get('PATH', '')}"}
    
    test_files = sorted(Path("checks.d").rglob("test.sh"))
    
    # Honor original NUM_CONCURRENT_TESTS env var, default to CPU core count
    workers = int(os.environ.get("NUM_CONCURRENT_TESTS", os.cpu_count() or 4))
    
    # Run tests concurrently
    with ThreadPoolExecutor(max_workers=workers) as executor:
        # executor.map guarantees the final results list remains in the same sorted order as test_files
        results = list(executor.map(lambda t: run_test(t, env), test_files))
    
    # Summarize and output
    total_count = len(results)
    failed_count = sum(1 for r in results if not r["success"])
    passed_count = total_count - failed_count
    
    summary_text = f"Passed: {passed_count}, Failed: {failed_count}, Total: {total_count}"
    
    if args.output == "human":
        GREEN = '\033[0;32m'
        RED = '\033[0;31m'
        NC = '\033[0m'
        
        for r in results:
            if r["success"]:
                status = f"{GREEN}PASS{NC}"
            else:
                status = f"{RED}FAIL{NC}"
            
            # Print the one-line status per testcase
            print(f"[{status}] {r['testpath']}")
            
            # If verbose is set, print the logs indented
            if args.verbose and r["log"]:
                for line in r["log"]:
                    print(f"    {line}")
            
        print("-" * 40)
        print(summary_text)
    
    elif args.output == "json":
        output_data = {
            "summary": summary_text,
            "results": results
        }
        print(json.dumps(output_data, indent=2))
        
    sys.exit(1 if failed_count > 0 else 0)

if __name__ == "__main__":
    main()
