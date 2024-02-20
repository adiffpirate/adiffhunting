FROM alpine:3.19.1

# Basic tools
RUN apk add --no-cache bash coreutils curl wget jq unzip python3

# Subfinder
ARG SUBFINDER_VERSION="2.6.5"
RUN wget https://github.com/projectdiscovery/subfinder/releases/download/v${SUBFINDER_VERSION}/subfinder_${SUBFINDER_VERSION}_linux_386.zip -O subfinder.zip \
	&& unzip subfinder.zip -d subfinder \
	&& mv subfinder/subfinder /usr/bin/subfinder \
	&& chmod +x /usr/bin/subfinder \
	&& rm -rfv subfinder*

# Chaos
ARG CHAOS_VERSION="0.5.1"
RUN wget https://github.com/projectdiscovery/chaos-client/releases/download/v${CHAOS_VERSION}/chaos-client_${CHAOS_VERSION}_linux_386.zip -O chaos.zip \
	&& unzip chaos.zip -d chaos \
	&& mv chaos/chaos-client /usr/bin/chaos \
	&& chmod +x /usr/bin/chaos \
	&& rm -rfv chaos*

ENV UTILS=/src/_utils
COPY _utils $UTILS

ENV ROOTDOMAIN_SCAN_COOLDOWN="1 hour"

COPY recon/subenum-passive/* /src/
CMD /src/entrypoint.sh
