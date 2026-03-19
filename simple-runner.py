#!/usr/bin/env python3

import os, sys, json, subprocess, argparse, tempfile, time, threading
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, wait

# Global lock to prevent overlapping output when updating specific lines in the terminal
stdout_lock = threading.Lock()

def run_test(test_file, env):
    """Executes a single test script in an isolated temporary directory."""
    test_env = env.copy()
    
    with tempfile.TemporaryDirectory(prefix="virt_validate_") as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        
        original_dir = test_file.parent
        for item in original_dir.iterdir():
            if item.is_file():
                dest_file = temp_dir / item.name
                os.symlink(item.absolute(), dest_file)
        
        with tempfile.TemporaryFile() as report_f:
            fd = report_f.fileno()
            os.set_inheritable(fd, True)
            test_env["TEST_REPORT_FD"] = str(fd)
            
            start_ts = time.monotonic()
            
            # Using Popen with stderr=subprocess.STDOUT interleaves stdout and stderr 
            # into a single stream in the correct chronological order.
            process = subprocess.Popen(
                ["bash", "-e", test_file.name],
                cwd=temp_dir,
                env=test_env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                pass_fds=(fd,)
            )
            
            log_lines = []
            # Read line-by-line as the process emits them to append accurate timestamps
            for line in process.stdout:
                # Add a timestamp with millisecond precision
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
    parser.add_argument("-f", "--fail-fast", nargs="?", const=1, type=int, metavar="N", help="Stop execution after N failures (default: 1 when flag is provided)")
    args = parser.parse_args()

    bin_path = os.path.abspath("bin")
    env = {**os.environ, "PATH": f"{bin_path}{os.pathsep}{os.environ.get('PATH', '')}"}
    
    test_files = sorted(Path("checks.d").rglob("test*.sh"))
    total_count = len(test_files)
    if total_count == 0:
        print("No tests found.")
        sys.exit(0)
    
    test_line_map = {str(t): i for i, t in enumerate(test_files)}
    workers = int(os.environ.get("NUM_CONCURRENT_TESTS", os.cpu_count() or 4))
    
    GREEN, RED, YELLOW, NC = ('\033[0;32m', '\033[0;31m', '\033[1;33m', '\033[0m')
    results, completed_count, start_time, failed_count_live = ([], 0, time.monotonic(), 0)
    
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
                # If a test was cancelled before it started, we skip processing it
                if f.cancelled():
                    continue
                r = f.result()
                results.append(r)
                completed_count += 1
                if not r["success"]:
                    failed_count_live += 1

            # Check if fail-fast condition is met
            if args.fail_fast is not None and failed_count_live >= args.fail_fast:
                for p in pending:
                    p.cancel()

            if is_human_tty:
                elapsed_time = time.monotonic() - start_time
                
                prog_percent = int((completed_count / total_count) * 100)
                prog_bar_width = 20
                filled_len = int(prog_bar_width * completed_count // total_count)
                bar = '#' * filled_len + '-' * (prog_bar_width - filled_len)
                
                with stdout_lock:
                    sys.stdout.write("\r\033[K") # Clear progress bar line
                    prog_str = f"Progress: [{bar}] {prog_percent}% ({completed_count}/{total_count}) | {format_time(elapsed_time)}"
                    sys.stdout.write(prog_str)
                    sys.stdout.flush()

    if is_human_tty:
        sys.stdout.write("\r\033[K") # Final clear of progress bar
        sys.stdout.flush()
        
        # Mark any skipped tests with a yellow [SKIP] tag in the UI
        executed_paths = {r["testpath"] for r in results}
        for t in test_files:
            t_str = str(t)
            if t_str not in executed_paths:
                update_line_status(t_str, f"[{YELLOW}SKIP{NC}] --:--", test_line_map, total_count)

    results.sort(key=lambda x: x["testpath"])
    
    executed_count = len(results)
    failed_count = sum(1 for r in results if not r["success"])
    passed_count = executed_count - failed_count
    skipped_count = total_count - executed_count
    
    summary_text = f"Passed: {passed_count}, Failed: {failed_count}"
    if skipped_count > 0:
        summary_text += f", Skipped: {skipped_count}"
    summary_text += f", Total: {total_count}"
    
    if args.output == "human":
        # Print detailed output for failures, informational messages or if verbose is enabled
        has_details = any(not r["success"] or r["report_messages"] for r in results)
        if has_details or args.verbose:
            print("\n" + "="*20 + " DETAILS " + "="*20)
            for r in results:
                if not r["success"] or r["report_messages"] or args.verbose:
                    status = f"{GREEN}PASS{NC}" if r["success"] else f"{RED}FAIL{NC}"
                    print(f"\n[{status}] {format_time(r['duration'])} {r['testpath']}")
                    for msg in r["report_messages"]:
                        color = RED if msg.startswith("FAIL:") else ""
                        reset = NC if msg.startswith("FAIL:") else ""
                        print(f"    {color}-> {msg}{reset}")
                    if r["log"] and (not r["success"] or args.verbose):
                        print("    --- Test Output ---")
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
