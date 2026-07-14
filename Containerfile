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
