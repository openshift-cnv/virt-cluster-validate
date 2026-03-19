# virt-cluster-validate

Validates an OpenShift cluster's virtualization readiness.

## Objectives

*   **Fast**: Execution time boxed to <3 minutes.
*   **Simple**: Direct feedback with human-readable and JSON outputs.
*   **Safe**: Runs unprivileged with `cluster-reader` permissions.
*   **Isolated**: Tests run in temporary sandboxes to prevent source tree pollution.
*   **Extensible**: Add new checks via `test*.sh` in `checks.d/`.

## Prerequisites

*   `oc` and `virtctl` binaries in your `PATH`.
*   Active `oc login` to the target cluster.
*   Python 3.x (to run the validator).

## Usage

```bash
# Basic run (Human readable)
./virt-cluster-validate

# Verbose run (Shows full logs)
./virt-cluster-validate -v

# JSON output (For automation)
./virt-cluster-validate -o json

# Fail fast (Stop after 1 failure)
./virt-cluster-validate -f

# Simulate execution (UI testing)
./virt-cluster-validate --mock -t 3s

# Identify slowest tests
./virt-cluster-validate --help
```

### CLI Options

*   `-o {human,json}`: Output format (Default: `human`).
*   `-v, --verbose`: Print full bash logs for every test.
*   `-s, --select PATH`: Run only a specific test script.
*   `-t, --timeout SPAN`: Max execution time per test (e.g. `2m`, `45s`, `180`. Default: `180`).
*   `-f [N], --fail-fast [N]`: Stop execution after N failures (Default: 1).
*   `--mock`: Simulate test execution with random success/failures and wait times.
*   `NUM_CONCURRENT_TESTS=N`: Environment variable to control parallelism.

## Development & Testing

The runner itself is tested using Python `unittest`:

```bash
python3 -m unittest discover -s tests
```

To add checks, create a new directory in `checks.d/` and add a script matching `test*.sh`. Use `pass_with` and `fail_with` helpers from `bin/`.
