FROM registry.access.redhat.com/ubi9/python-311:latest

USER 0

# Install required CLI tools for the validation checks
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | tar -xz -C /usr/local/bin/ oc && \
    curl -L https://github.com/kubevirt/kubevirt/releases/download/v1.1.1/virtctl-v1.1.1-linux-amd64 -o /usr/local/bin/virtctl && \
    chmod +x /usr/local/bin/oc /usr/local/bin/virtctl

USER 1001

WORKDIR /opt/app-root/src

# Copy the core application files
COPY virt-cluster-validate .
COPY bin/ bin/
COPY checks.d/ checks.d/
COPY README.md .

# The runner expects 'bin' to be in the PATH
ENV PATH="/opt/app-root/src/bin:${PATH}"

# By default, run the validation tool
ENTRYPOINT ["/opt/app-root/src/virt-cluster-validate"]
CMD ["-v"]
