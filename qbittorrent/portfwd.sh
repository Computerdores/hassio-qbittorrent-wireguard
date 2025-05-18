#!/usr/bin/bashio

# undo options set by bashio
set +e
set +E
set +u
set +o pipefail


port=$(natpmpc -a 1 0 udp 60 -g 10.2.0.1 | grep "public port" | awk '/Mapped public port/ {print $4}')

bashio::log.info "Public Listening Port: $port"

# find and replace "Session\Port=.*" in /config/qBittorrent/config/qBittorrent.conf with $port
sed -i -r "s/^(Session\\\Port=).*/\1$port/" /config/qBittorrent/config/qBittorrent.conf

# run the port forward loop.
rm /config/natpmpc.log >/dev/null 2>/dev/null
while true ; do date >/config/natpmpc.log 2>/config/natpmpc.log ; natpmpc -a 1 0 udp 60 -g 10.2.0.1 >/config/natpmpc.log 2>/config/natpmpc.log && natpmpc -a 1 0 tcp 60 -g 10.2.0.1 >/config/natpmpc.log 2>/config/natpmpc.log || { bashio::log.error "ERROR with natpmpc command \a" ; break ; } ; sleep 45 ; done
