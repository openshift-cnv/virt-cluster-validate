#!/usr/bin/bash

cat <<EOC
# Paste the following command into a shell
podman -r run --rm \
--volume \$HOME/.kube:/app/.kube:ro,z \
--volume \$(which oc):/usr/bin/oc:ro,bind,exec,z \
--volume \$(which virtctl):/usr/bin/virtctl:ro,bind,exec,z \
--entrypoint bash \
$DEFAULT_IMAGE \
-c "testrunner ; summarize_results"
EOC
