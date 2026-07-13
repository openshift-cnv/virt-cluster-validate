# Writing Checks

A check is a bash script that validates one aspect of cluster readiness for OpenShift Virtualization.

## Quick Start

    mkdir checks.d/50-openshift-virtualization.d/60-my-check.d/
    cat > checks.d/50-openshift-virtualization.d/60-my-check.d/test.sh << 'EOF'
    #!/usr/bin/bash

    # Guard: exit early if precondition is missing
    oc get crd widgets.example.io >/dev/null 2>&1 \
      || { pass_with info "Widget CRD not installed, skipping"; exit 0; }

    COUNT=$(oc get widgets -A --no-headers 2>/dev/null | wc -l)
    if [ "$COUNT" -eq 0 ]; then
      fail_with "No widgets found on the cluster"
    fi

    pass_with info "Found $COUNT widget(s)"
    EOF
    chmod +x checks.d/50-openshift-virtualization.d/60-my-check.d/test.sh

That's it. The runner discovers `test*.sh` files automatically -- no registration needed.

## Directory Layout

    checks.d/
      <priority>-<category>.d/
        <priority>-<check-name>.d/
          test.sh
          helper-data.yaml   # optional, symlinked into the sandbox

The numeric prefix controls execution order (sorted lexicographically by full path). Place platform-level checks under `10-openshift.d/` and virtualization-specific checks under `50-openshift-virtualization.d/`.

## Reporting Results

Use the helpers from `bin/`:

*   `pass_with info "message"` -- informational, test passes.
*   `pass_with warn "message"` -- test passes but flags a concern.
*   `fail_with "message"` -- test fails and the script exits immediately.

A check that exits 0 without calling any helper is a silent pass.
A check that exits non-zero is a failure.

## Rules

### Guard your preconditions

The runner has no dependency system. If your check requires a CRD, namespace, or operator to be present, check for it at the top of the script and `exit 0` if missing. Don't assume a prior check verified it.

    oc get namespace openshift-cnv >/dev/null 2>&1 \
      || { pass_with info "OpenShift Virtualization not installed"; exit 0; }

### Clean up cluster resources

If your check creates resources (VMs, pods, migrations, snapshots), add a cleanup trap. The runner sends SIGTERM on timeout, giving traps time to run before a hard SIGKILL.

    cleanup() {
      [ -f vm.yaml ] && oc delete -f vm.yaml --ignore-not-found=true >/dev/null 2>&1 || true
    }
    trap cleanup EXIT

    virtctl create vm ... | tee vm.yaml
    oc create -f vm.yaml
    # ... test logic ...
    # cleanup runs automatically on exit, pass or fail

Delete resources in reverse creation order (restore before snapshot before VM).

### Always set `--timeout` on `oc wait`

Without an explicit `--timeout`, `oc wait` can hang indefinitely if the condition is never met. The runner has a per-check timeout, but the check should not rely on being killed externally.

    oc wait --for=condition=Ready=true --timeout=2m -f vm.yaml

### Keep checks fast and safe

*   Target under 2 minutes per check. The default per-check timeout is 3 minutes.
*   Use `cluster-reader` permissions where possible. Checks that create resources should document it.
*   Checks run inside `oc adm must-gather` in production -- don't do anything destructive.
*   The script runs with `bash -xe` (trace + exit-on-error).

### Avoid TTY assumptions

Checks run without a terminal (piped stdout, no stdin). Don't use interactive commands (`read`, `select`), don't rely on `tput` or terminal width, and don't use `oc` flags that request a TTY (`-t`, `-it`).

## Supporting Files

Any files in the same directory as `test.sh` are symlinked into an isolated temp sandbox before execution. Use this for YAML manifests, templates, or helper scripts that the check needs.

    checks.d/50-openshift-virtualization.d/60-my-check.d/
      test.sh
      vm-template.yaml    # available as ./vm-template.yaml inside the check

## Testing Your Check

    # Run just your check
    ./virt-cluster-validate -v -s checks.d/50-openshift-virtualization.d/60-my-check.d/test.sh

    # Run with mock mode (no cluster needed, verifies discovery)
    VIRT_VALIDATE_MOCK=1 ./virt-cluster-validate --include my-check
