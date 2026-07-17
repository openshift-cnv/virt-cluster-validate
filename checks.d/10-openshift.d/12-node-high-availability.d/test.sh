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

if oc api-resources | grep machinehealthcheck
then pass_with info Remediation "Node remediation is provided by MachineHealthChecks"
# FIXME need to check if it's really this resource to look for
#elif oc api-resources | grep nodehealthcheck
#then pass_with_info Remediation "Node remediation is provided by NodeHealthChecks"
else fail_with Remediation "No node remediation found. Either use IPI or install a fencing solution like NHC with SNR."
fi
