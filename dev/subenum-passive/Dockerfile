FROM alpine:3.17.2

# Basic tools
RUN apk add --no-cache bash curl jq wget unzip python3

# Amass
ARG AMASS_VERSION="4.2.0"
RUN wget https://github.com/OWASP/Amass/releases/download/v${AMASS_VERSION}/amass_linux_i386.zip -O amass.zip \
	&& unzip amass.zip \
	&& mv amass_linux_i386/amass /usr/bin/amass \
	&& chmod +x /usr/bin/amass \
	&& rm -rfv amass*

# Subfinder
ARG SUBFINDER_VERSION="2.6.3"
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

COPY subenum-passive/entrypoint.sh /src/entrypoint.sh
CMD /src/entrypoint.sh
