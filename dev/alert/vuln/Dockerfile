FROM alpine:3.19.1

# Basic tools
RUN apk add --no-cache bash coreutils curl wget sed jq unzip python3 uuidgen

# yq
ARG YQ_VERSION="4.41.1"
RUN wget https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq \
	&& chmod +x /usr/bin/yq

# Notify
ARG NOTIFY_VERSION="1.0.6"
RUN wget https://github.com/projectdiscovery/notify/releases/download/v${NOTIFY_VERSION}/notify_${NOTIFY_VERSION}_linux_amd64.zip -O notify.zip \
	&& unzip notify.zip -d notify \
	&& mv notify/notify /usr/bin/notify \
	&& chmod +x /usr/bin/notify \
	&& rm -rfv notify*

ENV UTILS=/src/_utils
COPY _utils $UTILS

ENV ALERT_COOLDOWN_SECONDS="30"

COPY alert/vuln/* /src/
CMD /src/entrypoint.sh
