---
name: virt-cluster-validate-developer-skill
description: Guidelines and core rules for developers contributing to the virt-cluster-validate project. Use when writing new checks, modifying the runner, or adding tests.
---

# virt-cluster-validate Developer Skill

This skill provides the strict architectural and behavioral guidelines necessary when contributing to the `virt-cluster-validate` repository.

## Core Rules

`virt-cluster-validate` is a fast, safe, and unprivileged Python CLI tool that executes bash validation checks in isolated temporary sandboxes. 

### Writing Checks (`checks.d/`)
1. **Format:** Checks MUST be executable Bash scripts ending in `.sh`.
2. **Exit Codes:** Use `exit 0` for success and `exit 1` for failure.
3. **Reporting:** You MUST use the `pass_with` and `fail_with` helpers to emit structured messages. Do not write markers to disk. Example:
   ```bash
   pass_with warn "Feature" "Non-optimal state found"
   fail_with "Database" "Cannot connect to DB"
   ```
4. **Cluster Interaction:** Rely entirely on standard `oc` commands.
5. **Node Execution:** NEVER use `oc debug node/...` to run commands on nodes. Instead, spawn standard Pods using the `registry.access.redhat.com/ubi9/ubi-minimal:latest` image. Use `nodeName` targeting and `hostPath` mounts if node filesystem access (like `/sys`) is strictly required. You must clean up the Pods immediately.

### Modifying the Runner (`virt-cluster-validate`)
1. **Zero Dependencies:** Use only Python 3 standard libraries (`os`, `sys`, `json`, `subprocess`, `concurrent.futures`, `argparse`). Do NOT use `pip install`.
2. **UI Updates:** All terminal UI rendering must be thread-safe. Use the `TerminalUI` class and its internal `lock`.
3. **Streaming Logs:** Preserve the live log streaming feature activated by `./virt-cluster-validate --select <test> --verbose`.

### Automated Testing (`tests/`)
Any modification to the core runner logic (e.g., new CLI flags, concurrency changes) MUST include a corresponding integration test in `tests/test_virt_cluster_validate.py` using the standard `unittest` framework.

### Documentation (`README.md`)
Whenever adding new features, changing CLI flags, or altering core behavior, you MUST update `README.md` to reflect these changes. Keep explanations extremely short, terse, and update the usage examples.
