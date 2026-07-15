#!/usr/bin/bash
#
# Copyright (C) 2025-2026 Red Hat, Inc.
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
#

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
