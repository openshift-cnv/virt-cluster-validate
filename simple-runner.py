#!/usr/bin/env python3

import os, sys, json, subprocess, argparse, tempfile, time, threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, wait

# Global lock to prevent overlapping output when updating specific lines in the terminal
stdout_lock = threading.Lock()

def run_test(test_file, env):
    """Executes a single test script and returns its results as a dictionary."""
    test_env = env.copy()
    
    with tempfile.TemporaryFile() as report_f:
        # Get the underlying OS file descriptor
        fd = report_f.fileno()
        os.set_inheritable(fd, True)
        test_env["TEST_REPORT_FD"] = str(fd)
        
        start_ts = time.monotonic()
        res = subprocess.run(
            ["bash", "-e", test_file.name],
            cwd=test_file.parent,
            env=test_env,
            capture_output=True,
            text=True,
            pass_fds=(fd,)
        )
        duration = time.monotonic() - start_ts
        
        report_f.seek(0)
        report_messages = report_f.read().decode('utf-8').splitlines()
    
    output = (res.stdout + res.stderr).splitlines()
    return {
        "testpath": str(test_file),
        "success": res.returncode == 0,
        "duration": duration,
        "report_messages": report_messages,
        "log": output,
        "errors": output if res.returncode != 0 else [],
        "warnings": [line for line in output if "warn" in line.lower()]
    }

def format_time(seconds):
    """Converts seconds into a MM:SS string."""
    m, s = divmod(int(seconds), 60)
    return f"{m:02d}:{s:02d}"

def update_line_status(test_path, status_prefix, test_line_map, total_count):
    """Uses ANSI escape codes to update the status prefix of a specific test line."""
    if not sys.stdout.isatty():
        return
    line_idx = test_line_map[test_path]
    # Calculate how many lines up we need to jump from the progress bar
    lines_up = (total_count - line_idx) + 1
    with stdout_lock:
        # Save cursor, move up, overwrite start of line, restore cursor
        sys.stdout.write(f"\033[{lines_up}A\r{status_prefix}\033[{lines_up}B")
        sys.stdout.flush()

def run_test_task(test_file, env, test_line_map, total_count, GREEN, RED, NC):
    """Wrapper for run_test that updates the terminal status before and after execution."""
    test_path_str = str(test_file)
    # The user requested to not use the word "RUN", so we leave the status empty while running.
    update_line_status(test_path_str, "[    ] --:--", test_line_map, total_count)
    result = run_test(test_file, env)
    
    status_color = GREEN if result["success"] else RED
    status_text = "PASS" if result["success"] else "FAIL"
    duration_str = format_time(result["duration"])
    
    update_line_status(test_path_str, f"[{status_color}{status_text}{NC}] {duration_str}", test_line_map, total_count)
    return result

def main():
    parser = argparse.ArgumentParser(description="Simple test runner for virt-cluster-validate checks.")
    parser.add_argument("-o", "--output", choices=["json", "human"], default="human", help="Output format (default: human)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show test output in human-readable mode")
    args = parser.parse_args()

    bin_path = os.path.abspath("bin")
    env = {**os.environ, "PATH": f"{bin_path}{os.pathsep}{os.environ.get('PATH', '')}"}
    
    test_files = sorted(Path("checks.d").rglob("test.sh"))
    total_count = len(test_files)
    if total_count == 0:
        print("No tests found.")
        sys.exit(0)
    
    test_line_map = {str(t): i for i, t in enumerate(test_files)}
    workers = int(os.environ.get("NUM_CONCURRENT_TESTS", os.cpu_count() or 4))
    
    GREEN, RED, NC = ('\033[0;32m', '\033[0;31m', '\033[0m')
    results, completed_count, start_time = ([], 0, time.monotonic())
    
    is_human_tty = (args.output == "human" and sys.stdout.isatty())

    if is_human_tty:
        # Pre-print the full list of tests with empty status and duration placeholders
        for t in test_files:
            print(f"[    ] --:-- {t}")
        print("") # Placeholder for the progress bar
        sys.stdout.flush()

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(run_test_task, t, env, test_line_map, total_count, GREEN, RED, NC): t for t in test_files}
        pending = set(futures.keys())
        
        while pending:
            done, pending = wait(pending, timeout=1.0)
            for f in done:
                r = f.result()
                results.append(r)
                completed_count += 1

            if is_human_tty:
                elapsed_time = time.monotonic() - start_time
                
                prog_percent = int((completed_count / total_count) * 100)
                prog_bar_width = 20
                filled_len = int(prog_bar_width * completed_count // total_count)
                bar = '#' * filled_len + '-' * (prog_bar_width - filled_len)
                
                with stdout_lock:
                    sys.stdout.write("\r\033[K") # Clear progress bar line
                    prog_str = f"Progress: [{bar}] {prog_percent}% ({completed_count}/{total_count}) | Spent: {format_time(elapsed_time)}"
                    sys.stdout.write(prog_str)
                    sys.stdout.flush()

    if is_human_tty:
        sys.stdout.write("\r\033[K") # Final clear of progress bar
        sys.stdout.flush()

    results.sort(key=lambda x: x["testpath"])
    failed_count = sum(1 for r in results if not r["success"])
    summary_text = f"Passed: {total_count - failed_count}, Failed: {failed_count}, Total: {total_count}"
    
    if args.output == "human":
        # Print detailed output for failures, informational messages or if verbose is enabled
        has_details = any(r["report_messages"] for r in results)
        if has_details or args.verbose:
            print("\n" + "="*20 + " DETAILS " + "="*20)
            for r in results:
                if r["report_messages"] or args.verbose:
                    status = f"{GREEN}PASS{NC}" if r["success"] else f"{RED}FAIL{NC}"
                    print(f"\n[{status}] {format_time(r['duration'])} {r['testpath']}")
                    for msg in r["report_messages"]:
                        color = RED if msg.startswith("FAIL:") else ""
                        reset = NC if msg.startswith("FAIL:") else ""
                        print(f"    {color}-> {msg}{reset}")
                    if args.verbose and r["log"]:
                        for line in r["log"]:
                            print(f"    {line}")
        
        print("-" * 40)
        print(summary_text)
        print(f"Total time: {format_time(time.monotonic() - start_time)}")
    
    elif args.output == "json":
        print(json.dumps({"summary": summary_text, "results": results}, indent=2))
        
    sys.exit(1 if failed_count > 0 else 0)

if __name__ == "__main__":
    main()
