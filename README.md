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
*   Active `oc login` to the target cluster (required before execution).
*   Python 3.x (to run the validator).
*   [Gemini CLI](https://github.com/google/gemini-cli) (Optional, for AI-assisted development).

## Usage

    # Login to the cluster
    oc login ...

    # Basic run (Human readable)
    ./virt-cluster-validate

    # Verbose run (Shows full logs)
    ./virt-cluster-validate -v

    # JSON output (For automation)
    ./virt-cluster-validate -o json

    # Fail fast (Stop after 1 failure)
    ./virt-cluster-validate -f

    # Identify slowest tests
    ./virt-cluster-validate --help

### CLI Options

*   `-o {human,json}`: Output format (Default: `human`).
*   `-v, --verbose`: Print full bash logs for every test.
*   `-s, --select PATH`: Run only a specific test script.
*   `-t, --timeout SPAN`: Max execution time per test (e.g. `2m`, `45s`, `180`. Default: `180`).
*   `-c, --concurrency N`: Number of tests to run in parallel (Default: Number of CPU cores).
*   `-f [N], --fail-fast [N]`: Stop execution after N failures (Default: 1).

## Disconnected Environments (Container)

If you are running in a restricted environment or don't have Python/`oc` installed on your bastion, you can build and run the tool as a container.

1.  **Build the Image:**
    ```bash
    podman build -t myregistry.internal/virt-cluster-validate:latest -f Containerfile .
    ```
2.  **Push to your Mirror:**
    ```bash
    podman push myregistry.internal/virt-cluster-validate:latest
    ```
3.  **Run as a Job:**
    You can deploy this as a Kubernetes `Job` within your cluster. The container already includes the `oc` and `virtctl` binaries.

4.  **Run locally with Podman:**
    To test the container locally, mount your `KUBECONFIG`:
    ```bash
    podman run --rm \
      -v ${KUBECONFIG:-$HOME/.kube/config}:/opt/app-root/src/.kube/config:z \
      -e KUBECONFIG=/opt/app-root/src/.kube/config \
      myregistry.internal/virt-cluster-validate:latest
    ```

## Development & Testing

### Unit Tests

    python3 -m unittest discover -s tests

### AI-Assisted Development

This project includes a [Gemini CLI](https://github.com/google/gemini-cli) developer skill to ensure architectural consistency.
To enable it in your workspace:

    gemini skills install .gemini/skills/virt-cluster-validate-developer-skill/ --scope workspace

To add checks, create a new directory in `checks.d/` and add a script matching `test*.sh`. Use `pass_with` and `fail_with` helpers from `bin/`.
