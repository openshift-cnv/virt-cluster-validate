set -xe
podman -r build -t quay.io/fdeutsch/virtualization-validation . \
&& podman -r push quay.io/fdeutsch/virtualization-validation \
&& podman -r run quay.io/fdeutsch/virtualization-validation
#&& oc apply -f pipeline-virtualization-validation.yaml \
#&& oc create -f run.yaml
