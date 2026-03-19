#!/usr/bin/env python3

import os
import sys
import json
import argparse
import tempfile
import time
import threading
import subprocess
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, wait

# --- Globals & Constants ---

stdout_lock = threading.Lock()

class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    NC = '\033[0m'

# --- Core Test Execution ---

def run_test(test_file, env):
    """Executes a single test script in an isolated temporary directory."""
    test_env = env.copy()
    
    with tempfile.TemporaryDirectory(prefix="virt_validate_") as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        
        # Mirror the test environment via symlinks
        for item in test_file.parent.iterdir():
            if item.is_file():
                os.symlink(item.absolute(), temp_dir / item.name)
        
        with tempfile.TemporaryFile() as report_f:
            fd = report_f.fileno()
            os.set_inheritable(fd, True)
            test_env["TEST_REPORT_FD"] = str(fd)
            
            start_ts = time.monotonic()
            
            process = subprocess.Popen(
                ["bash", "-xe", test_file.name],
                cwd=temp_dir,
                env=test_env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                pass_fds=(fd,)
            )
            
            # Read line-by-line to append accurate timestamps
            log_lines = []
            for line in process.stdout:
                ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
                log_lines.append(f"[{ts}] {line.rstrip(chr(10))}")
                
            process.wait()
            duration = time.monotonic() - start_ts
            
            report_f.seek(0)
            report_messages = report_f.read().decode('utf-8').splitlines()
    
    return {
        "testpath": str(test_file),
        "success": process.returncode == 0,
        "duration": duration,
        "report_messages": report_messages,
        "log": log_lines,
        "errors": log_lines if process.returncode != 0 else [],
        "warnings": [line for line in log_lines if "warn" in line.lower()]
    }

# --- UI Helpers ---

def format_time(seconds):
    """Converts seconds into a MM:SS string."""
    m, s = divmod(int(seconds), 60)
    return f"{m:02d}:{s:02d}"

def update_line_status(test_path, status_prefix, test_line_map, total_count):
    """Uses ANSI escape codes to update the status prefix of a specific test line."""
    if not sys.stdout.isatty():
        return
    lines_up = (total_count - test_line_map[test_path]) + 1
    with stdout_lock:
        sys.stdout.write(f"\033[{lines_up}A\r{status_prefix}\033[{lines_up}B")
        sys.stdout.flush()

def draw_progress_bar(completed, total, elapsed_time):
    """Draws a live-updating progress bar at the bottom of the screen."""
    prog_percent = int((completed / total) * 100)
    filled_len = int(20 * completed // total)
    bar = '#' * filled_len + '-' * (20 - filled_len)
    
    with stdout_lock:
        sys.stdout.write(f"\r\033[KProgress: [{bar}] {prog_percent}% ({completed}/{total}) | {format_time(elapsed_time)}")
        sys.stdout.flush()

def clear_progress_bar():
    with stdout_lock:
        sys.stdout.write("\r\033[K")
        sys.stdout.flush()

def run_test_task(test_file, env, test_line_map, total_count):
    """Wrapper for run_test that updates the terminal status before and after execution."""
    test_path_str = str(test_file)
    update_line_status(test_path_str, "[    ] --:--", test_line_map, total_count)
    
    result = run_test(test_file, env)
    
    color = Colors.GREEN if result["success"] else Colors.RED
    status = "PASS" if result["success"] else "FAIL"
    duration = format_time(result["duration"])
    
    update_line_status(test_path_str, f"[{color}{status}{Colors.NC}] {duration}", test_line_map, total_count)
    return result

def print_details_section(results, verbose):
    """Prints the expanded logs and reports for failed tests (and passes if verbose)."""
    has_details = any(not r["success"] or r["report_messages"] for r in results)
    if not (has_details or verbose):
        return

    print(f"\n{'='*20} DETAILS {'='*20}")
    for r in results:
        if not r["success"] or r["report_messages"] or verbose:
            status_color = Colors.GREEN if r["success"] else Colors.RED
            status_text = "PASS" if r["success"] else "FAIL"
            
            print(f"\n[{status_color}{status_text}{Colors.NC}] {format_time(r['duration'])} {r['testpath']}")
            
            for msg in r["report_messages"]:
                color = Colors.RED if msg.startswith("FAIL:") else ""
                reset = Colors.NC if msg.startswith("FAIL:") else ""
                print(f"    {color}-> {msg}{reset}")
                
            if r["log"] and (not r["success"] or verbose):
                print("    --- Test Output ---")
                for line in r["log"]:
                    print(f"    {line}")

# --- Main Logic ---

def main():
    parser = argparse.ArgumentParser(description="Simple test runner for virt-cluster-validate checks.")
    parser.add_argument("-o", "--output", choices=["json", "human"], default="human", help="Output format (default: human)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show test output in human-readable mode")
    parser.add_argument("-f", "--fail-fast", nargs="?", const=1, type=int, metavar="N", help="Stop execution after N failures (default: 1 when flag is provided)")
    args = parser.parse_args()

    # 1. Environment Setup
    bin_path = os.path.abspath("bin")
    env = {**os.environ, "PATH": f"{bin_path}{os.pathsep}{os.environ.get('PATH', '')}"}
    
    # 2. Test Discovery
    test_files = sorted(Path("checks.d").rglob("test*.sh"))
    total_count = len(test_files)
    if total_count == 0:
        print("No tests found.")
        sys.exit(0)
    
    test_line_map = {str(t): i for i, t in enumerate(test_files)}
    workers = int(os.environ.get("NUM_CONCURRENT_TESTS", os.cpu_count() or 4))
    is_human_tty = (args.output == "human" and sys.stdout.isatty())

    # 3. UI Initialization
    if is_human_tty:
        for t in test_files:
            print(f"[    ] --:-- {t}")
        print("") # Space for progress bar
        sys.stdout.flush()

    # 4. Execution
    results = []
    completed_count = 0
    failed_count_live = 0
    start_time = time.monotonic()

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(run_test_task, t, env, test_line_map, total_count): t for t in test_files}
        pending = set(futures.keys())
        
        while pending:
            done, pending = wait(pending, timeout=1.0)
            
            for f in done:
                if f.cancelled():
                    continue
                r = f.result()
                results.append(r)
                completed_count += 1
                if not r["success"]:
                    failed_count_live += 1

            # Fail-Fast Trigger
            if args.fail_fast is not None and failed_count_live >= args.fail_fast:
                for p in pending:
                    p.cancel()

            # UI Update
            if is_human_tty:
                draw_progress_bar(completed_count, total_count, time.monotonic() - start_time)

    # 5. Post-Execution UI Cleanup & Skipped Marking
    if is_human_tty:
        clear_progress_bar()
        executed_paths = {r["testpath"] for r in results}
        for t in test_files:
            if str(t) not in executed_paths:
                update_line_status(str(t), f"[{Colors.YELLOW}SKIP{Colors.NC}] --:--", test_line_map, total_count)

    # 6. Summary Calculation
    results.sort(key=lambda x: x["testpath"])
    executed_count = len(results)
    failed_count = sum(1 for r in results if not r["success"])
    passed_count = executed_count - failed_count
    skipped_count = total_count - executed_count
    
    summary_text = f"Passed: {passed_count}, Failed: {failed_count}"
    if skipped_count > 0:
        summary_text += f", Skipped: {skipped_count}"
    summary_text += f", Total: {total_count}"
    
    # 7. Final Output Rendering
    if args.output == "human":
        print_details_section(results, args.verbose)
        print("-" * 40)
        print(summary_text)
        print(f"Total time: {format_time(time.monotonic() - start_time)}")
    
    elif args.output == "json":
        print(json.dumps({"summary": summary_text, "results": results}, indent=2))
        
    sys.exit(1 if failed_count > 0 else 0)

if __name__ == "__main__":
    main()
