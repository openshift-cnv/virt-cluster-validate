#!/usr/bin/bash

export PATH=$PATH:/app/bin

if [[ "$1" = "podman-args" ]];
then
# arguments for podman
cat <<EOC
      --env WD=/ \
      --env HOME=/ \
      --env RESULTSD=/results.d/ \
      --env NUM_CONCURRENT_TESTS=42 \
      --env SINGLE_TEST_TIMEOUT=5m \
      --env TEST_FILTER="\$PLUGIN_FILTER" \
      --volume \${RESULTSD:-\$PWD/results.d/}:/results.d:rw,z \
      --volume \$HOME/.kube:/.kube:ro,z \
      --volume \$(which oc):/usr/bin/oc:ro,bind,exec,z \
      --volume \$(which virtctl):/usr/bin/virtctl:ro,bind,exec,z
EOC
  exit 0
else
  testrunner
  summarize_results "$RESULTSD"
fi
