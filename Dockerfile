# Based on the official qbittorrent-nox image
FROM qbittorrentofficial/qbittorrent-nox:5.1.0-1

WORKDIR /opt

# Make directories
RUN mkdir -p /config/qBittorrent /etc/qbittorrent /etc/vuetorrent

# Download and extract VueTorrent
RUN apk --no-cache --update-cache update \
    && apk --no-cache --update-cache upgrade \
    && apk --no-cache --update-cache add \
    curl \
    unzip \
    jq \
    && VUETORRENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/VueTorrent/VueTorrent/tags" | jq '.[] | .name' | head -n 1 | tr -d '"') \
    && curl -o vuetorrent.zip -L "https://github.com/VueTorrent/VueTorrent/releases/download/${VUETORRENT_RELEASE}/vuetorrent.zip" \
    && unzip vuetorrent.zip -d /etc \
    && rm vuetorrent.zip \
    && apk del \
    curl \
    unzip \
    jq

# Install WireGuard and some other dependencies some of the scripts in the container rely on.
RUN apk --no-cache --update-cache update \
    && apk --no-cache --update-cache add \
    bash \
    curl \
    iputils-ping \
    ipcalc \
    iptables \
    jq \
    kmod \
    moreutils \
    net-tools \
    libnatpmp \
    openresolv \
    procps \
    shadow \
    wireguard-tools \
    openssl

# Remove src_valid_mark from wg-quick
RUN sed -i /net\.ipv4\.conf\.all\.src_valid_mark/d `which wg-quick`

ADD start.sh /
ADD qbittorrent/ /etc/qbittorrent/

RUN chmod +x /start.sh
RUN chmod +x /etc/qbittorrent/*.sh

#-- HassIO Section
# Install Bashio 
RUN mkdir -p /tmp/bashio
RUN curl -f -L -s -S "https://github.com/hassio-addons/bashio/archive/v0.17.0.tar.gz" | tar -xzf - --strip 1 -C /tmp/bashio
RUN mv /tmp/bashio/lib /usr/lib/bashio
RUN ln -s /usr/lib/bashio/bashio /usr/bin/bashio
RUN rm -rf /tmp/bashio

ADD apply_config.sh /
RUN chmod +x /apply_config.sh

EXPOSE 8080
ENTRYPOINT ["/apply_config.sh"]

HEALTHCHECK \
    --interval=5s \
    --retries=5 \
    --start-period=30s \
    --timeout=25s \
    CMD pgrep qbittorrent || exit 1
