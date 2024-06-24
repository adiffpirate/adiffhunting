FROM alpine:3.19.1

# Basic tools
RUN apk add --no-cache bash coreutils curl wget sed jq unzip python3 uuidgen

# Install python modules
RUN apk add --no-cache py3-requests

ENV UTILS=/src/_utils
COPY _utils $UTILS

COPY recon/rootenum/* /src/
CMD /src/entrypoint.sh
