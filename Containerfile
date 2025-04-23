FROM quay.io/fedora/fedora:latest

RUN dnf install -y jq podman

ADD . /

ENV WD=/
ENTRYPOINT ["/entrypoint.sh"]
