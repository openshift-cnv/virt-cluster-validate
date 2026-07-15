# Copyright (C) 2024-2026 Red Hat, Inc.
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

FROM registry.access.redhat.com/ubi9/python-311:latest

USER 0

# Install required tools - oc and virtctl will be downloaded at runtime from the cluster
RUN dnf install -y jq && dnf clean all

# Make /usr/local/bin writable so tools can be downloaded at runtime
RUN chmod 777 /usr/local/bin

USER 1001

WORKDIR /opt/app-root/src

# Copy the core application files
COPY virt-cluster-validate .
COPY bin/ bin/
COPY checks.d/ checks.d/
COPY README.md .
COPY collection-scripts/gather /usr/bin/gather

# The runner expects 'bin' to be in the PATH
ENV PATH="/opt/app-root/src/bin:${PATH}"

# ENTRYPOINT is gather which detects must-gather vs normal mode
ENTRYPOINT ["/usr/bin/gather"]
