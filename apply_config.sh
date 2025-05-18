#!/usr/bin/bashio

# Create required directories
mkdir -p /share/qBittorrent

# read config values
export ENABLEPROTONVPNPORTFWD=$([ "$(bashio::config 'enable_protonvpn_port_forwarding')" = "true" ] && echo 1 || echo 0)
export LAN_NETWORK=$(bashio::config 'lan_network')
export NAME_SERVERS=$(bashio::config 'name_servers')
export RESTART_CONTAINER=$(bashio::config 'restart_container')

# other necessary env vars
export ENABLE_SSL="false"
export PUID=0
export PGID=0

bashio::log.info "Done reading config values"

/start.sh
