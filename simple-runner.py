#!/usr/bin/env python3

import os, sys, json, subprocess, argparse, tempfile, time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

def run_test(test_file, env):
    """Executes a single test script and returns its results as a dictionary."""
    test_env = env.copy()
    
    with tempfile.TemporaryFile() as fail_f:
        # Get the underlying OS file descriptor
        fd = fail_f.fileno()
        
        # Ensure the file descriptor is inheritable by the bash child process
        os.set_inheritable(fd, True)
        test_env["FAIL_FD"] = str(fd)
        
        # Run bash -e inside the test's directory with the augmented PATH
        res = subprocess.run(
            ["bash", "-e", test_file.name],
            cwd=test_file.parent,
            env=test_env,
            capture_output=True,
            text=True,
            pass_fds=(fd,)
        )
        
        # Seek back to the beginning of the temporary file to read what bash wrote
        fail_f.seek(0)
        fail_messages = fail_f.read().decode('utf-8').splitlines()
    
    output = (res.stdout + res.stderr).splitlines()
    return {
        "testpath": str(test_file),
        "success": res.returncode == 0,
        "fail_messages": fail_messages,
        "log": output,
        "errors": output if res.returncode != 0 else [],
        "warnings": [line for line in output if "warn" in line.lower()]
    }

def format_time(seconds):
    """Converts seconds into a MM:SS string."""
    m, s = divmod(int(seconds), 60)
    return f"{m:02d}:{s:02d}"

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
    total_count = len(test_files)
    
    if total_count == 0:
        print("No tests found.")
        sys.exit(0)
    
    # Honor original NUM_CONCURRENT_TESTS env var, default to CPU core count
    workers = int(os.environ.get("NUM_CONCURRENT_TESTS", os.cpu_count() or 4))
    
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    NC = '\033[0m'
    
    results = []
    completed_count = 0
    start_time = time.time()
    
    # Run tests concurrently
    with ThreadPoolExecutor(max_workers=workers) as executor:
        # Submit all tasks
        future_to_test = {executor.submit(run_test, t, env): t for t in test_files}
        
        # Process them as they complete to provide real-time feedback
        for future in as_completed(future_to_test):
            r = future.result()
            results.append(r)
            completed_count += 1
            
            # ETA Logic: Based on runtime so far and amount of completed tests
            # rate = tests_completed / time_elapsed
            # remaining_time = tests_remaining / rate
            elapsed_time = time.time() - start_time
            
            if completed_count > 0:
                tests_remaining = total_count - completed_count
                rate = completed_count / elapsed_time
                eta_seconds = tests_remaining / rate
            else:
                eta_seconds = 0

            if args.output == "human":
                # Clear the current line (which holds the progress bar)
                sys.stdout.write("\r\033[K")
                
                # Print the result of the completed test
                status = f"{GREEN}PASS{NC}" if r["success"] else f"{RED}FAIL{NC}"
                print(f"[{status}] {r['testpath']}")
                
                if not r["success"] and r["fail_messages"]:
                    for msg in r["fail_messages"]:
                        print(f"    {RED}-> {msg}{NC}")
                
                if args.verbose and r["log"]:
                    for line in r["log"]:
                        print(f"    {line}")
                
                # Redraw the progress bar at the bottom if it's a TTY
                if sys.stdout.isatty():
                    prog_percent = int((completed_count / total_count) * 100)
                    prog_bar_width = 20
                    filled_len = int(prog_bar_width * completed_count // total_count)
                    bar = '#' * filled_len + '-' * (prog_bar_width - filled_len)
                    
                    prog_str = (
                        f"Progress: [{bar}] {prog_percent}% ({completed_count}/{total_count}) | "
                        f"Spent: {format_time(elapsed_time)} | "
                        f"Remaining: {format_time(eta_seconds)}"
                    )
                    sys.stdout.write(prog_str)
                    sys.stdout.flush()

    # Sort results back to sequential order based on test path for stable output
    results.sort(key=lambda x: x["testpath"])
    
    failed_count = sum(1 for r in results if not r["success"])
    passed_count = total_count - failed_count
    
    summary_text = f"Passed: {passed_count}, Failed: {failed_count}, Total: {total_count}"
    
    if args.output == "human":
        # Clear the final progress bar
        if sys.stdout.isatty():
            sys.stdout.write("\r\033[K")
        print("-" * 40)
        print(summary_text)
        print(f"Total time: {format_time(time.time() - start_time)}")
    
    elif args.output == "json":
        output_data = {
            "summary": summary_text,
            "results": results
        }
        print(json.dumps(output_data, indent=2))
        
    sys.exit(1 if failed_count > 0 else 0)

if __name__ == "__main__":
    main()
