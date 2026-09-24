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
#
# Synthetic must-gather fixture generator for omc-based integration tests.
#
# Generates minimal must-gather directory trees that omc can consume.
# Each scenario builder creates a specific broken (or healthy) cluster state.

import json
from pathlib import Path


# ---------------------------------------------------------------------------
# Minimal CRD stubs so omc recognises OpenShift resource types.
# omc auto-discovers CRDs from cluster-scoped-resources/apiextensions.k8s.io/
# ---------------------------------------------------------------------------

OPENSHIFT_CRDS = [
    {
        "group": "config.openshift.io",
        "names": {"plural": "clusteroperators", "singular": "clusteroperator",
                  "kind": "ClusterOperator", "shortNames": ["co"]},
        "scope": "Cluster",
    },
    {
        "group": "machineconfiguration.openshift.io",
        "names": {"plural": "machineconfigpools", "singular": "machineconfigpool",
                  "kind": "MachineConfigPool", "shortNames": ["mcp"]},
        "scope": "Cluster",
    },
    {
        "group": "config.openshift.io",
        "names": {"plural": "infrastructures", "singular": "infrastructure",
                  "kind": "Infrastructure", "shortNames": []},
        "scope": "Cluster",
    },
    {
        "group": "operator.openshift.io",
        "names": {"plural": "dnses", "singular": "dns",
                  "kind": "DNS", "shortNames": []},
        "scope": "Cluster",
    },
    {
        "group": "machine.openshift.io",
        "names": {"plural": "machinesets", "singular": "machineset",
                  "kind": "MachineSet", "shortNames": []},
        "scope": "Namespaced",
    },
    {
        "group": "config.openshift.io",
        "names": {"plural": "networks", "singular": "network",
                  "kind": "Network", "shortNames": []},
        "scope": "Cluster",
    },
    {
        "group": "operators.coreos.com",
        "names": {"plural": "clusterserviceversions", "singular": "clusterserviceversion",
                  "kind": "ClusterServiceVersion", "shortNames": ["csv"]},
        "scope": "Namespaced",
    },
    {
        "group": "hco.kubevirt.io",
        "names": {"plural": "hyperconvergeds", "singular": "hyperconverged",
                  "kind": "HyperConverged", "shortNames": ["hco"]},
        "scope": "Namespaced",
    },
    {
        "group": "kubevirt.io",
        "names": {"plural": "kubevirts", "singular": "kubevirt",
                  "kind": "KubeVirt", "shortNames": []},
        "scope": "Namespaced",
    },
    {
        "group": "kubevirt.io",
        "names": {"plural": "virtualmachines", "singular": "virtualmachine",
                  "kind": "VirtualMachine", "shortNames": ["vm", "vms"]},
        "scope": "Namespaced",
    },
    {
        "group": "cdi.kubevirt.io",
        "names": {"plural": "storageprofiles", "singular": "storageprofile",
                  "kind": "StorageProfile", "shortNames": []},
        "scope": "Cluster",
    },
    {
        "group": "operators.coreos.com",
        "names": {"plural": "subscriptions", "singular": "subscription",
                  "kind": "Subscription", "shortNames": ["sub"]},
        "scope": "Namespaced",
    },
]


def _make_crd(group, names, scope):
    crd_name = f"{names['plural']}.{group}"
    return {
        "apiVersion": "apiextensions.k8s.io/v1",
        "kind": "CustomResourceDefinition",
        "metadata": {
            "name": crd_name,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "group": group,
            "names": names,
            "scope": scope,
            "versions": [{"name": "v1", "served": True, "storage": True}],
        },
    }


# ---------------------------------------------------------------------------
# Low-level: write resources into the must-gather directory layout
# ---------------------------------------------------------------------------

def _write_resource(path, resource):
    """Write a single Kubernetes resource dict as a JSON file (valid YAML subset)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(resource, indent=2) + "\n")


def _cluster_scoped_path(root, api_group, resource_plural, name):
    group_dir = api_group if api_group else "core"
    return root / "cluster-scoped-resources" / group_dir / resource_plural / f"{name}.yaml"


def _namespace_path(root, namespace):
    return root / "namespaces" / namespace / f"{namespace}.yaml"


def _namespaced_resource_path(root, namespace, api_group, resource_plural, name):
    group_dir = api_group if api_group else "core"
    return root / "namespaces" / namespace / group_dir / resource_plural / f"{name}.yaml"


def _namespaced_aggregate_path(root, namespace, api_group, resource_plural):
    group_dir = api_group if api_group else "core"
    return root / "namespaces" / namespace / group_dir / f"{resource_plural}.yaml"


def write_cluster_resource(root, api_group, resource_plural, resource):
    name = resource["metadata"]["name"]
    _write_resource(_cluster_scoped_path(root, api_group, resource_plural, name), resource)


def write_namespace(root, namespace_resource):
    name = namespace_resource["metadata"]["name"]
    _write_resource(_namespace_path(root, name), namespace_resource)


def write_namespaced_resource(root, namespace, api_group, resource_plural, resource):
    name = resource["metadata"]["name"]
    _write_resource(
        _namespaced_resource_path(root, namespace, api_group, resource_plural, name),
        resource,
    )


def write_namespaced_aggregate(root, namespace, api_group, resource_plural, items):
    """Write a Kubernetes List containing multiple resources (e.g. pods.yaml)."""
    aggregate = {
        "apiVersion": "v1",
        "kind": "List",
        "items": items,
    }
    _write_resource(
        _namespaced_aggregate_path(root, namespace, api_group, resource_plural),
        aggregate,
    )


# ---------------------------------------------------------------------------
# Resource builders — return plain dicts
# ---------------------------------------------------------------------------

def make_node(name, ready=True, roles=None, pressures=None, labels=None, annotations=None,
              allocatable_memory="32Gi", allocatable_cpu="16"):
    conditions = [
        {
            "type": "Ready",
            "status": "True" if ready else "False",
            "reason": "KubeletReady" if ready else "KubeletNotReady",
            "message": "kubelet is posting ready status" if ready else "PLEG is not healthy",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
            "lastHeartbeatTime": "2026-07-28T12:00:00Z",
        }
    ]
    for ptype in ("MemoryPressure", "DiskPressure", "PIDPressure"):
        is_pressured = ptype in (pressures or [])
        conditions.append({
            "type": ptype,
            "status": "True" if is_pressured else "False",
            "reason": f"{ptype}Exists" if is_pressured else f"No{ptype}",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
            "lastHeartbeatTime": "2026-07-28T12:00:00Z",
        })

    node_labels = dict(labels or {})
    for role in (roles or ["worker"]):
        node_labels[f"node-role.kubernetes.io/{role}"] = ""
    node_labels["kubernetes.io/hostname"] = name
    node_labels["kubernetes.io/os"] = "linux"

    node_annotations = dict(annotations or {})

    return {
        "apiVersion": "v1",
        "kind": "Node",
        "metadata": {
            "name": name,
            "labels": node_labels,
            "annotations": node_annotations,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {},
        "status": {
            "conditions": conditions,
            "allocatable": {
                "memory": allocatable_memory,
                "cpu": allocatable_cpu,
                "pods": "250",
            },
            "capacity": {
                "memory": allocatable_memory,
                "cpu": allocatable_cpu,
                "pods": "250",
            },
            "nodeInfo": {
                "kubeletVersion": "v1.30.0",
                "osImage": "Red Hat Enterprise Linux CoreOS 417.94.202401011234-0",
                "kernelVersion": "5.14.0-427.el9.x86_64",
                "containerRuntimeVersion": "cri-o://1.30.0",
            },
        },
    }


def make_cluster_version(version="4.17.3", available=True, progressing=False,
                         channel="stable-4.17", overrides=None):
    conditions = [
        {
            "type": "Available",
            "status": "True" if available else "False",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
        {
            "type": "Progressing",
            "status": "True" if progressing else "False",
            "message": f"Working towards {version}" if progressing else f"Cluster version is {version}",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
        {
            "type": "Degraded",
            "status": "False",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
    ]
    spec = {
        "channel": channel,
        "clusterID": "test-cluster-id-00000000-0000-0000-0000-000000000000",
    }
    if overrides:
        spec["overrides"] = overrides
    return {
        "apiVersion": "config.openshift.io/v1",
        "kind": "ClusterVersion",
        "metadata": {
            "name": "version",
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": spec,
        "status": {
            "desired": {"version": version},
            "conditions": conditions,
            "history": [
                {
                    "state": "Completed",
                    "version": version,
                    "completionTime": "2026-01-15T12:00:00Z",
                }
            ],
        },
    }


def make_cluster_operator(name, available=True, progressing=False, degraded=False):
    return {
        "apiVersion": "config.openshift.io/v1",
        "kind": "ClusterOperator",
        "metadata": {
            "name": name,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {},
        "status": {
            "conditions": [
                {
                    "type": "Available",
                    "status": "True" if available else "False",
                    "lastTransitionTime": "2026-01-15T10:00:00Z",
                },
                {
                    "type": "Progressing",
                    "status": "True" if progressing else "False",
                    "lastTransitionTime": "2026-01-15T10:00:00Z",
                },
                {
                    "type": "Degraded",
                    "status": "True" if degraded else "False",
                    "lastTransitionTime": "2026-01-15T10:00:00Z",
                },
            ],
        },
    }


def make_mcp(name, machine_count=3, ready_count=3, degraded=False, paused=False):
    conditions = [
        {
            "type": "Updated",
            "status": "True" if machine_count == ready_count else "False",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
        {
            "type": "Updating",
            "status": "False" if machine_count == ready_count else "True",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
        {
            "type": "Degraded",
            "status": "True" if degraded else "False",
            "reason": "RenderDegraded" if degraded else "",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
    ]
    return {
        "apiVersion": "machineconfiguration.openshift.io/v1",
        "kind": "MachineConfigPool",
        "metadata": {
            "name": name,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "paused": paused,
        },
        "status": {
            "machineCount": machine_count,
            "readyMachineCount": ready_count,
            "updatedMachineCount": ready_count,
            "degradedMachineCount": machine_count - ready_count,
            "conditions": conditions,
        },
    }


def make_pv(name, phase="Bound", capacity="100Gi", storage_class="gp3-csi"):
    return {
        "apiVersion": "v1",
        "kind": "PersistentVolume",
        "metadata": {
            "name": name,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "capacity": {"storage": capacity},
            "storageClassName": storage_class,
            "accessModes": ["ReadWriteOnce"],
            "persistentVolumeReclaimPolicy": "Delete",
        },
        "status": {
            "phase": phase,
        },
    }


def make_storage_class(name, provisioner="ebs.csi.aws.com", is_default=False):
    annotations = {}
    if is_default:
        annotations["storageclass.kubernetes.io/is-default-class"] = "true"
    return {
        "apiVersion": "storage.k8s.io/v1",
        "kind": "StorageClass",
        "metadata": {
            "name": name,
            "annotations": annotations,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "provisioner": provisioner,
        "reclaimPolicy": "Delete",
        "volumeBindingMode": "WaitForFirstConsumer",
    }


def make_namespace(name, labels=None):
    ns_labels = {"kubernetes.io/metadata.name": name}
    ns_labels.update(labels or {})
    return {
        "apiVersion": "v1",
        "kind": "Namespace",
        "metadata": {
            "name": name,
            "labels": ns_labels,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {"finalizers": ["kubernetes"]},
        "status": {"phase": "Active"},
    }


def make_pod(name, namespace, phase="Running", ready=True, restart_count=0):
    return {
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "containers": [{"name": "main", "image": "registry.example.com/image:latest"}],
        },
        "status": {
            "phase": phase,
            "containerStatuses": [
                {
                    "name": "main",
                    "ready": ready,
                    "restartCount": restart_count,
                    "state": {"running": {"startedAt": "2026-01-15T10:01:00Z"}} if phase == "Running" else {},
                }
            ],
        },
    }


def make_pdb(name, namespace, disruptions_allowed=1):
    return {
        "apiVersion": "policy/v1",
        "kind": "PodDisruptionBudget",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "minAvailable": 1,
        },
        "status": {
            "disruptionsAllowed": disruptions_allowed,
            "currentHealthy": 1 if disruptions_allowed > 0 else 1,
            "desiredHealthy": 1,
            "expectedPods": 1 + disruptions_allowed,
        },
    }


def make_dns_operator(name="default", degraded=False, available=True):
    return {
        "apiVersion": "operator.openshift.io/v1",
        "kind": "DNS",
        "metadata": {
            "name": name,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {},
        "status": {
            "conditions": [
                {
                    "type": "Available",
                    "status": "True" if available else "False",
                    "message": "DNS is available" if available else "DNS pods not ready",
                    "lastTransitionTime": "2026-01-15T10:00:00Z",
                },
                {
                    "type": "Degraded",
                    "status": "True" if degraded else "False",
                    "message": "DNS resolution failing" if degraded else "",
                    "lastTransitionTime": "2026-01-15T10:00:00Z",
                },
            ],
        },
    }


def make_network_config(network_type="OVNKubernetes", cluster_cidrs=None,
                        service_cidrs=None):
    if cluster_cidrs is None:
        cluster_cidrs = ["10.128.0.0/14"]
    if service_cidrs is None:
        service_cidrs = ["172.30.0.0/16"]
    return {
        "apiVersion": "config.openshift.io/v1",
        "kind": "Network",
        "metadata": {
            "name": "cluster",
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "networkType": network_type,
            "clusterNetwork": [{"cidr": c, "hostPrefix": 23} for c in cluster_cidrs],
            "serviceNetwork": service_cidrs,
        },
        "status": {
            "networkType": network_type,
            "clusterNetwork": [{"cidr": c, "hostPrefix": 23} for c in cluster_cidrs],
            "serviceNetwork": service_cidrs,
        },
    }


def make_infrastructure(platform_type="BareMetal"):
    return {
        "apiVersion": "config.openshift.io/v1",
        "kind": "Infrastructure",
        "metadata": {
            "name": "cluster",
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "platformSpec": {
                "type": platform_type,
            },
        },
        "status": {
            "platform": platform_type,
            "infrastructureName": "test-cluster",
        },
    }


def make_hyperconverged(overcommit_pct=100, degraded=False, available=True,
                        upgradeable=True):
    spec = {}
    if overcommit_pct != 100:
        spec["resourceRequirements"] = {
            "memoryOvercommitPercentage": overcommit_pct,
        }
    conditions = [
        {
            "type": "Available",
            "status": "True" if available else "False",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
        {
            "type": "Degraded",
            "status": "True" if degraded else "False",
            "message": "HCO is degraded" if degraded else "",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
        {
            "type": "Upgradeable",
            "status": "True" if upgradeable else "False",
            "message": "" if upgradeable else "Not ready for upgrade",
            "lastTransitionTime": "2026-01-15T10:00:00Z",
        },
    ]
    return {
        "apiVersion": "hco.kubevirt.io/v1beta1",
        "kind": "HyperConverged",
        "metadata": {
            "name": "kubevirt-hyperconverged",
            "namespace": "openshift-cnv",
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": spec,
        "status": {
            "conditions": conditions,
        },
    }


def make_kubevirt(name="kubevirt", eviction_strategy=None):
    config = {}
    if eviction_strategy:
        config["evictionStrategy"] = eviction_strategy
    return {
        "apiVersion": "kubevirt.io/v1",
        "kind": "KubeVirt",
        "metadata": {
            "name": name,
            "namespace": "openshift-cnv",
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "configuration": config,
        },
        "status": {
            "phase": "Deployed",
        },
    }


def make_vm(name, namespace="default", run_strategy="Always",
            eviction_strategy=None, pvc_names=None):
    volumes = []
    if pvc_names:
        for pvc in pvc_names:
            volumes.append({"persistentVolumeClaim": {"claimName": pvc}})
    template_spec = {
        "domain": {
            "resources": {"requests": {"memory": "1Gi"}},
        },
        "volumes": volumes,
    }
    if eviction_strategy:
        template_spec["evictionStrategy"] = eviction_strategy
    return {
        "apiVersion": "kubevirt.io/v1",
        "kind": "VirtualMachine",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "runStrategy": run_strategy,
            "running": run_strategy == "Always",
            "template": {
                "spec": template_spec,
            },
        },
    }


def make_csv(name, namespace, phase="Succeeded"):
    return {
        "apiVersion": "operators.coreos.com/v1alpha1",
        "kind": "ClusterServiceVersion",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "displayName": name,
            "install": {"strategy": "deployment"},
        },
        "status": {
            "phase": phase,
        },
    }


def make_storageprofile(name, clone_strategy="snapshot", access_modes=None,
                        volume_mode="Filesystem"):
    if access_modes is None:
        access_modes = ["ReadWriteOnce"]
    return {
        "apiVersion": "cdi.kubevirt.io/v1beta1",
        "kind": "StorageProfile",
        "metadata": {
            "name": name,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {},
        "status": {
            "claimPropertySets": [
                {"accessModes": access_modes, "volumeMode": volume_mode},
            ],
            "cloneStrategy": clone_strategy,
            "provisioner": "ebs.csi.aws.com",
        },
    }


def make_pvc(name, namespace, access_modes=None, storage="10Gi"):
    if access_modes is None:
        access_modes = ["ReadWriteOnce"]
    return {
        "apiVersion": "v1",
        "kind": "PersistentVolumeClaim",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "creationTimestamp": "2026-01-15T10:00:00Z",
        },
        "spec": {
            "accessModes": access_modes,
            "resources": {"requests": {"storage": storage}},
            "storageClassName": "gp3-csi",
        },
        "status": {
            "phase": "Bound",
            "accessModes": access_modes,
        },
    }


# ---------------------------------------------------------------------------
# Helpers: populate a must-gather root with common baseline resources
# ---------------------------------------------------------------------------

def _add_baseline(root, include_cnv_ns=True, include_storage_class=True):
    """Add minimal resources that most checks expect to exist."""
    write_namespace(root, make_namespace("default"))
    write_cluster_resource(root, "", "namespaces", make_namespace("default"))
    if include_cnv_ns:
        write_namespace(root, make_namespace("openshift-cnv"))
        write_cluster_resource(root, "", "namespaces", make_namespace("openshift-cnv"))
    write_namespace(root, make_namespace("openshift-monitoring"))
    write_cluster_resource(root, "", "namespaces", make_namespace("openshift-monitoring"))
    if include_storage_class:
        write_cluster_resource(
            root, "storage.k8s.io", "storageclasses",
            make_storage_class("gp3-csi", is_default=True),
        )
    for crd_def in OPENSHIFT_CRDS:
        crd = _make_crd(**crd_def)
        write_cluster_resource(
            root, "apiextensions.k8s.io", "customresourcedefinitions", crd,
        )


def _add_standard_cluster(root):
    """Add a standard 1-master, 2-worker cluster with healthy operators and MCPs."""
    write_cluster_resource(root, "", "nodes", make_node("master-0", roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", roles=["worker"]))
    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))


# ---------------------------------------------------------------------------
# Scenario builders — create complete must-gather fixtures
# ---------------------------------------------------------------------------

def build_fixture(base_path, name="must-gather"):
    """Return the content root inside a must-gather directory structure."""
    root = base_path / name
    (root / "cluster-scoped-resources").mkdir(parents=True, exist_ok=True)
    (root / "namespaces").mkdir(parents=True, exist_ok=True)
    return root


# --- Original scenarios (5 negative + 1 positive baseline) ---

def build_nodes_not_ready(base_path):
    root = build_fixture(base_path)
    _add_baseline(root)

    write_cluster_resource(root, "", "nodes", make_node("master-0", ready=True, roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", ready=False, roles=["worker"]))

    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))

    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))

    return base_path


def build_operator_degraded(base_path):
    root = build_fixture(base_path)
    _add_baseline(root)

    write_cluster_resource(root, "", "nodes", make_node("master-0", ready=True, roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", ready=True, roles=["worker"]))

    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator("authentication"))
    write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator("console"))
    write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator("monitoring", degraded=True))
    write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator("ingress"))
    write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator("network"))

    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))

    return base_path


def build_cluster_upgrading(base_path):
    root = build_fixture(base_path)
    _add_baseline(root)

    write_cluster_resource(root, "", "nodes", make_node("master-0", ready=True, roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", ready=True, roles=["worker"]))

    write_cluster_resource(
        root, "config.openshift.io", "clusterversions",
        make_cluster_version(version="4.17.5", available=True, progressing=True),
    )
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))

    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))

    return base_path


def build_pv_unhealthy(base_path):
    root = build_fixture(base_path)
    _add_baseline(root)

    write_cluster_resource(root, "", "nodes", make_node("master-0", ready=True, roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", ready=True, roles=["worker"]))

    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))

    write_cluster_resource(root, "", "persistentvolumes", make_pv("pv-healthy-1", phase="Bound"))
    write_cluster_resource(root, "", "persistentvolumes", make_pv("pv-healthy-2", phase="Available"))
    write_cluster_resource(root, "", "persistentvolumes", make_pv("pv-data", phase="Released"))

    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))

    return base_path


def build_mcp_degraded(base_path):
    root = build_fixture(base_path)
    _add_baseline(root)

    write_cluster_resource(root, "", "nodes", make_node("master-0", ready=True, roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-2", ready=True, roles=["worker"]))

    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))

    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(
        root, "machineconfiguration.openshift.io", "machineconfigpools",
        make_mcp("worker", machine_count=3, ready_count=1, degraded=True),
    )

    return base_path


def build_healthy(base_path):
    root = build_fixture(base_path)
    _add_baseline(root)

    write_cluster_resource(root, "", "nodes", make_node("master-0", ready=True, roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", ready=True, roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", ready=True, roles=["worker"]))

    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))

    write_cluster_resource(root, "", "persistentvolumes", make_pv("pv-1", phase="Bound"))
    write_cluster_resource(root, "", "persistentvolumes", make_pv("pv-2", phase="Available"))

    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))

    return base_path


# --- Expanded negative scenarios ---

def build_pod_restarts(base_path):
    """Pods in openshift-cnv with excessive restart counts."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_aggregate(root, "openshift-cnv", "", "pods", [
        make_pod("virt-handler-abc", "openshift-cnv", restart_count=1000),
        make_pod("virt-api-xyz", "openshift-cnv"),
    ])
    return base_path


def build_pdb_blocking(base_path):
    """PDB with disruptionsAllowed=0 blocking evictions."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_resource(
        root, "openshift-cnv", "policy", "poddisruptionbudgets",
        make_pdb("my-critical-pdb", "openshift-cnv", disruptions_allowed=0),
    )
    return base_path


def build_cvo_overrides(base_path):
    """ClusterVersion with unmanaged CVO overrides."""
    root = build_fixture(base_path)
    _add_baseline(root)
    overrides = [
        {
            "kind": "Deployment",
            "group": "apps/v1",
            "name": "cluster-version-operator",
            "namespace": "openshift-cluster-version",
            "unmanaged": True,
        }
    ]
    write_cluster_resource(root, "", "nodes", make_node("master-0", roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-1", roles=["worker"]))
    write_cluster_resource(
        root, "config.openshift.io", "clusterversions",
        make_cluster_version(overrides=overrides),
    )
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))
    return base_path


def build_dns_degraded(base_path):
    """DNS operator in degraded state."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_cluster_resource(
        root, "operator.openshift.io", "dnses",
        make_dns_operator(degraded=True),
    )
    return base_path


def build_machine_config_drift(base_path):
    """Nodes with MachineConfig drift (currentConfig != desiredConfig)."""
    root = build_fixture(base_path)
    _add_baseline(root)
    mc_annotations = {
        "machineconfiguration.openshift.io/currentConfig": "rendered-worker-aaa111",
        "machineconfiguration.openshift.io/desiredConfig": "rendered-worker-bbb222",
        "machineconfiguration.openshift.io/state": "Degraded",
    }
    write_cluster_resource(root, "", "nodes", make_node("master-0", roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("worker-0", roles=["worker"]))
    write_cluster_resource(root, "", "nodes", make_node(
        "worker-1", roles=["worker"], annotations=mc_annotations,
    ))
    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 1, 1))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("worker", 2, 2))
    return base_path


def build_no_storage_classes(base_path):
    """Cluster with no storage classes at all."""
    root = build_fixture(base_path)
    _add_baseline(root, include_storage_class=False)
    _add_standard_cluster(root)
    return base_path


def build_monitoring_pods_unhealthy(base_path):
    """Monitoring namespace with unhealthy component pods."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_aggregate(root, "openshift-monitoring", "", "pods", [
        make_pod("prometheus-k8s-0", "openshift-monitoring"),
        make_pod("alertmanager-main-0", "openshift-monitoring"),
        make_pod("thanos-querier-abc", "openshift-monitoring", phase="CrashLoopBackOff", ready=False),
        make_pod("kube-state-metrics-xyz", "openshift-monitoring"),
        make_pod("node-exporter-111", "openshift-monitoring"),
    ])
    return base_path


def build_third_party_provisioner(base_path):
    """Storage class with unsupported third-party provisioner."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_cluster_resource(
        root, "storage.k8s.io", "storageclasses",
        make_storage_class("custom-storage", provisioner="custom.example.com/csi"),
    )
    return base_path


def build_ipv6_non_ovn(base_path):
    """IPv6/dual-stack cluster with non-OVN network type."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_cluster_resource(
        root, "config.openshift.io", "networks",
        make_network_config(
            network_type="OpenShiftSDN",
            cluster_cidrs=["10.128.0.0/14", "fd01::/48"],
            service_cidrs=["172.30.0.0/16", "fd02::/112"],
        ),
    )
    return base_path


def build_node_topology_unknown(base_path):
    """Only master nodes, no workers — unknown topology."""
    root = build_fixture(base_path)
    _add_baseline(root)
    write_cluster_resource(root, "", "nodes", make_node("master-0", roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("master-1", roles=["master"]))
    write_cluster_resource(root, "", "nodes", make_node("master-2", roles=["master"]))
    write_cluster_resource(root, "config.openshift.io", "clusterversions", make_cluster_version())
    for op in ("authentication", "console", "ingress", "monitoring", "network"):
        write_cluster_resource(root, "config.openshift.io", "clusteroperators", make_cluster_operator(op))
    write_cluster_resource(root, "machineconfiguration.openshift.io", "machineconfigpools", make_mcp("master", 3, 3))
    return base_path


def build_cnv_not_installed(base_path):
    """Cluster without openshift-cnv namespace — CNV not installed."""
    root = build_fixture(base_path)
    _add_baseline(root, include_cnv_ns=False)
    _add_standard_cluster(root)
    return base_path


def build_not_bare_metal(base_path):
    """Cluster running on vSphere — not bare metal."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_cluster_resource(
        root, "config.openshift.io", "infrastructures",
        make_infrastructure(platform_type="VSphere"),
    )
    return base_path


def build_memory_overcommit(base_path):
    """HCO with memory overcommit > 100%."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_resource(
        root, "openshift-cnv", "hco.kubevirt.io", "hyperconvergeds",
        make_hyperconverged(overcommit_pct=150),
    )
    return base_path


def build_no_remediation(base_path):
    """CNV installed but no node remediation CRDs present."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    return base_path


def build_vm_no_eviction(base_path):
    """Running VMs without LiveMigrate eviction strategy."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_resource(
        root, "openshift-cnv", "kubevirt.io", "kubevirts",
        make_kubevirt(eviction_strategy=None),
    )
    write_namespaced_resource(
        root, "default", "kubevirt.io", "virtualmachines",
        make_vm("test-vm-1", namespace="default", run_strategy="Always", eviction_strategy=None),
    )
    write_namespaced_resource(
        root, "default", "kubevirt.io", "virtualmachines",
        make_vm("test-vm-2", namespace="default", run_strategy="Halted"),
    )
    return base_path


def build_upgrade_readiness_degraded(base_path):
    """HCO degraded — not ready for upgrade."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_resource(
        root, "openshift-cnv", "operators.coreos.com", "clusterserviceversions",
        make_csv("kubevirt-hyperconverged-operator.v4.17.0", "openshift-cnv", phase="Succeeded"),
    )
    write_namespaced_resource(
        root, "openshift-cnv", "hco.kubevirt.io", "hyperconvergeds",
        make_hyperconverged(degraded=True),
    )
    return base_path


def build_storageprofile_no_rwx(base_path):
    """Storage profiles without ReadWriteMany — live migration impossible."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_cluster_resource(
        root, "cdi.kubevirt.io", "storageprofiles",
        make_storageprofile("gp3-csi", access_modes=["ReadWriteOnce"]),
    )
    return base_path


def build_migration_storage(base_path):
    """VM with LiveMigrate eviction using non-RWX PVC."""
    root = build_fixture(base_path)
    _add_baseline(root)
    _add_standard_cluster(root)
    write_namespaced_resource(
        root, "openshift-cnv", "kubevirt.io", "kubevirts",
        make_kubevirt(eviction_strategy="LiveMigrate"),
    )
    write_namespaced_resource(
        root, "default", "kubevirt.io", "virtualmachines",
        make_vm("migrate-vm", namespace="default", run_strategy="Always",
                pvc_names=["data-pvc"]),
    )
    write_namespaced_resource(
        root, "default", "", "persistentvolumeclaims",
        make_pvc("data-pvc", "default", access_modes=["ReadWriteOnce"]),
    )
    return base_path
