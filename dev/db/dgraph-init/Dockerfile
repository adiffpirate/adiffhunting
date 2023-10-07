FROM alpine:3.18.4

# Basic tools
RUN apk add --no-cache bash curl jq python3

ENV UTILS=/src/_utils
COPY _utils $UTILS

COPY db/dgraph-init/* /src/
CMD /src/entrypoint.sh
