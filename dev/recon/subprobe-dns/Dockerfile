FROM alpine:3.19.1

# Basic tools
RUN apk add --no-cache bash coreutils curl wget sed jq unzip python3 uuidgen

# DNSX
ARG DNSX_VERSION="1.1.5"
RUN wget https://github.com/projectdiscovery/dnsx/releases/download/v${DNSX_VERSION}/dnsx_${DNSX_VERSION}_linux_386.zip -O dnsx.zip \
	&& unzip dnsx.zip -d dnsx \
	&& mv dnsx/dnsx /usr/bin/dnsx \
	&& chmod +x /usr/bin/dnsx \
	&& rm -rfv dnsx*

ENV UTILS=/src/_utils
COPY _utils $UTILS

COPY recon/subprobe-dns/* /src/
CMD /src/entrypoint.sh
