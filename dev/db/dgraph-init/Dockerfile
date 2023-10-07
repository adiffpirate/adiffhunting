FROM alpine:3.17.2

# Basic tools
RUN apk add --no-cache bash curl jq python3

ENV UTILS=/src/_utils
COPY _utils $UTILS

COPY dgraph-init/entrypoint.sh /src/entrypoint.sh
CMD /src/entrypoint.sh
