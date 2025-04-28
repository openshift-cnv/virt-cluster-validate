set -e
set -m  # job control

IMG_REPO_PREFIX=quay.io/virt-cluster-validate
IMG_TAG=latest

PLUGIN_INDEX_FILE=$PWD/generated-plugin-index.txt

:> $PLUGIN_INDEX_FILE

pushd checks.d

for PLUGIN_DIR in plugin-*.d/;
do
    echo "# BUILDING $PLUGIN_DIR"
    (
    PLUGIN_NAME=${PLUGIN_DIR%.*}
    PLUGIN_URL=$IMG_REPO_PREFIX/$PLUGIN_NAME:$IMG_TAG
    set -x
    podman -r \
        build $PLUGIN_DIR/ \
        -f Containerfile.simple_case \
        --build-arg PLUGIN_NAME="$PLUGIN_NAME" \
        --build-arg PLUGIN_DISPLAYNAME="${PLUGIN_NAME#plugin-*-}" \
        --build-arg PLUGIN_IMAGE_URL="$PLUGIN_URL" \
        --cache-ttl 4h \
        --tag $PLUGIN_URL
    echo $PLUGIN_URL >> $PLUGIN_INDEX_FILE
    ) 
done

wait -f

while read -r PLUGIN_URL
do
    podman -r run $PLUGIN_URL ping | grep pong
done < $PLUGIN_INDEX_FILE

wait -f
