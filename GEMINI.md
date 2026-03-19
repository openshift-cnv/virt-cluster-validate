# Gemini AI Context: virt-cluster-validate

`virt-cluster-validate` is a fast, safe, and unprivileged CLI tool that validates an OpenShift cluster's readiness for virtualization workloads (similar to `virt-host-validate`).

## Core Architecture & Execution

* **Runner (`virt-cluster-validate`)**: A zero-dependency Python 3 script that executes bash checks concurrently.
* **Sandboxing**: The runner executes every `test*.sh` script in a securely isolated, auto-destructing temporary directory (`/tmp/virt_validate_...`). Files are symlinked from the source directory.
* **Communication**: Tests report status and logs back to the Python runner via a secure POSIX file descriptor (`TEST_REPORT_FD`), completely avoiding disk writes.

## Rules for LLM Agents

When writing or modifying code in this project, adhere strictly to the following:

### 1. Writing Cluster Checks (`checks.d/`)
* **Format:** Checks MUST be executable Bash scripts ending in `.sh` (e.g., `test.sh`, `test-feature.sh`).
* **Exit Codes:** Use `exit 0` for success and `exit 1` for failure.
* **Reporting:** You MUST use the `pass_with` and `fail_with` helpers provided in `bin/` to emit structured messages. (e.g., `pass_with warn "Feature" "Message"`).
* **Cluster Interaction:** Rely entirely on standard `oc` commands.
* **Remote Execution:** Do **NOT** use `oc debug node/...` to run commands on specific nodes. Instead, spawn standard Pods using the `ubi-minimal` image, utilizing `nodeName` for targeting and `hostPath` mounts if node filesystem access (like `/sys`) is strictly required. Ensure immediate cleanup.

### 2. Modifying the Runner (`virt-cluster-validate`)
* **No Dependencies:** Use only Python 3 standard libraries (`os`, `sys`, `json`, `subprocess`, `concurrent.futures`, `argparse`). No `pip install`.
* **UI Updates:** All terminal UI rendering must be thread-safe. Use `TerminalUI` and its `lock`.
* **Streaming Logs:** Preserve the live log streaming feature activated by `--select <test> --verbose`.

### 3. Automated Testing (`tests/`)
* Any modification to the core runner logic (e.g., new CLI flags, concurrency changes) MUST include a corresponding integration test in `tests/test_virt_cluster_validate.py` using the standard `unittest` framework.
