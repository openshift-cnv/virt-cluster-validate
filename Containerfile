FROM quay.io/fedora/fedora:latest

RUN dnf install -y jq

ADD app /app
