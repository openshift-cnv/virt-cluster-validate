#!/usr/bin/bash

set -e

export PATH=$PATH:/app/bin

if [[ -z "$@" ]];
then
# arguments for podman
cat <<EOC
      --env WD=/ \
      --env HOME=/ \
      --env RESULTSD=/results.d/ \
      --env NUM_CONCURRENT_TESTS=42 \
      --env SINGLE_TEST_TIMEOUT=5m \
      --env TEST_FILTER="\$PLUGIN_FILTER" \
      --volume \$PWD:/app:ro,z \
      --volume \$RESULTSD:/results.d:rw,z \
      --volume \$HOME/.kube:/.kube:ro,z \
      --volume \$(which oc):/usr/bin/oc:ro,bind,exec,z \
      --volume \$(which virtctl):/usr/bin/virtctl:ro,bind,exec,z \
      \$IMAGEURL \
      testrunner
EOC
  exit 0
else
  testrunner
  summarize_results "$RESULTSD"
fi
