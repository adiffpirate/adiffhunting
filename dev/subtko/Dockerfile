FROM alpine:3.17.2

# Basic tools
RUN apk add --no-cache bash curl wget jq unzip python3

# Nuclei
ARG NUCLEI_VERSION="2.9.15"
RUN wget https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_linux_amd64.zip -O nuclei.zip \
	&& unzip nuclei.zip -d nuclei \
	&& mv nuclei/nuclei /usr/bin/nuclei \
	&& chmod +x /usr/bin/nuclei \
	&& rm -rfv nuclei*

ENV UTILS=/src/_utils
COPY _utils $UTILS

COPY subtko/entrypoint.sh /src/entrypoint.sh
CMD /src/entrypoint.sh
