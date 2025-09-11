FROM fedora

RUN dnf install -y jq

ENV APP=virt-cluster-validate

ENV WD="/app"
ENV HOME="$WD"
ENV PATH="$PATH:/app/bin"

ENV RESULTSD="/results.d"
ENV NUM_CONCURRENT_TESTS="42"
ENV SINGLE_TEST_TIMEOUT="5m"
ENV FILTER_ON=".*"

ENV DEFAULT_IMAGE="quay.io/openshift-virtualization/$APP"

ENTRYPOINT ["/app/bin/entrypoint.sh"]

RUN mkdir $RESULTSD
ADD . /app
