# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL := /bin/bash

# Checks that require a live cluster (mutating operations or oc exec)
MUTATING_CHECKS := 50-basic,70-live-migration,75-snapshots,80-high-performance,12-cpu-c0-state,81-rebalance

# Checks that need commands omc cannot serve (oc api-resources)
UNSUPPORTED_CHECKS := 05-deprecated-apis,12-node-high-availability

EXCLUDE_PATTERN := $(MUTATING_CHECKS),$(UNSUPPORTED_CHECKS)

.PHONY: test test-unit test-omc must-gather-check lint help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

test: test-unit test-omc ## Run all tests

test-unit: ## Run unit tests (no omc required)
	python3 -m unittest discover -s tests -p 'test_virt_cluster_validate*' -v

test-omc: ## Run omc integration tests (requires omc)
	@command -v omc >/dev/null 2>&1 || { echo "omc not found. Install from https://github.com/gmeghnag/omc"; exit 1; }
	python3 -m unittest discover -s tests -p 'test_omc*' -v

must-gather-check: ## Run read-only checks against a must-gather archive (MUST_GATHER=path)
must-gather-check:
	@if [ -z "$(MUST_GATHER)" ]; then \
		echo "Usage: make must-gather-check MUST_GATHER=/path/to/must-gather"; \
		echo ""; \
		echo "Runs all read-only checks against a must-gather archive using omc."; \
		echo "The path can be a directory, a tarball, or a remote URL."; \
		exit 1; \
	fi
	@command -v omc >/dev/null 2>&1 || { echo "omc not found. Install from https://github.com/gmeghnag/omc"; exit 1; }
	@export FAKE_HOME=$$(mktemp -d) && \
	trap "rm -rf $$FAKE_HOME" EXIT && \
	HOME=$$FAKE_HOME omc use "$(MUST_GATHER)" && \
	echo "" && \
	HOME=$$FAKE_HOME PATH="$(CURDIR)/tests/omc-shim:$$PATH" \
		python3 virt-cluster-validate --exclude "$(EXCLUDE_PATTERN)" $(ARGS); \
	rc=$$?; rm -rf $$FAKE_HOME; exit $$rc

lint: ## Run shellcheck and python checks
	@find checks.d -name '*.sh' -exec shellcheck -S warning {} +
	@python3 -m py_compile virt-cluster-validate
