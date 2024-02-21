FROM alpine:3.19.1

# Basic tools
RUN apk add --no-cache bash coreutils curl wget jq unzip python3 uuidgen

ENV UTILS=/src/_utils
COPY _utils $UTILS

COPY db/dgraph-init/* /src/
CMD /src/entrypoint.sh
