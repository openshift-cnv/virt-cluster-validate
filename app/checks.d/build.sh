IMG_REPO_PREFIX=quay.io/virt-cluster-validate
IMG_TAG=latest

:> generated-plugin-index.txt
for PLUGIN_DIR in plugin-*.d/;
do
    PLUGIN_NAME=${PLUGIN_DIR%.*}
    PLUGIN_URL=$IMG_REPO_PREFIX/$PLUGIN_NAME:$IMG_TAG
    podman -r \
        build $PLUGIN_DIR/ \
        -f $PWD/Containerfile.simple_case \
        --cache-ttl 5m \
        --tag $PLUGIN_URL
    echo $PLUGIN_URL >> generated-plugin-index.txt
done

while read -r PLUGIN_URL
do
    podman -r run $PLUGIN_URL ping
done < generated-plugin-index.txt
