  podman -r run \
      --rm \
      --env WD=/ \
      --env HOME=/ \
      --env RESULTSD=/results.d/ \
      --env NUM_CONCURRENT_TESTS=10 \
      --env TEST_FITER=".*" \
      --volume $PWD:/app:ro,z \
      --volume $PWD/results.d:/app/results.d:rw,z \
      --volume $HOME/.kube:/.kube:ro,z \
      --volume $(which oc):/usr/bin/oc:ro,bind,exec,z \
      --volume $(which virtctl):/usr/bin/virtctl:ro,bind,exec,z \
      fedora:latest \
      bash -e -c 'export PATH=$PATH:/app/bin ; prepare ; testrunner "$TEST_FILTER"'


