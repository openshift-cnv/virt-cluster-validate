FROM quay.io/fedora/fedora:latest

RUN dnf install -y jq podman

ADD . /

ENTRYPOINT ["/entrypoint.sh"]
