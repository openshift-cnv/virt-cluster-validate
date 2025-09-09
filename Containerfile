FROM fedora

RUN dnf install -y jq

ADD . /app
