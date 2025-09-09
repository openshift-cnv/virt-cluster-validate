FROM fedora

RUN dnf install -y jq

ENTRYPOINT ["/app/bin/entrypoint.sh"]

ADD . /app
