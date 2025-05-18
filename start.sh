#!/usr/bin/bashio
# undo options set by bashio
set +E
set +u
set +o pipefail


# Enable exit on error
set -e

# check for presence of network interface docker0
check_network=$(ifconfig | grep docker0 || true)

# if network interface docker0 is present then we are running in host mode and thus must exit
if [[ ! -z "${check_network}" ]]; then
	bashio::log.error "Network type detected as 'Host', this will cause major issues, please stop the container and switch back to 'Bridge' mode"
	# Sleep so it wont 'spam restart'
	sleep 10
	exit 1
fi

iptables_version=$(iptables -V)
bashio::log.info "The container is currently running ${iptables_version}."

# Create the directory to store WireGuard config files
mkdir -p /config/wireguard

# Set permmissions and owner for files in /config/wireguard directory
set +e
chown -R "${PUID}":"${PGID}" "/config/wireguard" &> /dev/null
exit_code_chown=$?
find "/config/wireguard" -type f -print0 | xargs -0 chmod 660
exit_code_chmod=$?
set -e
if (( ${exit_code_chown} != 0 || ${exit_code_chmod} != 0 )); then
	bashio::log.warning "Unable to chown/chmod /config/wireguard/, assuming SMB mountpoint"
fi

# Wildcard search for wireguard config files (match on first result)
export VPN_CONFIG=$(find /config/wireguard -maxdepth 1 -name "*.conf" -print -quit)

# If config file not found in /config/wireguard then exit
if [[ -z "${VPN_CONFIG}" ]]; then
	bashio::log.error "No WireGuard config file found in /config/wireguard/. Please download one from your VPN provider and restart this container. Make sure the file extension is '.conf'"

	# Sleep so it wont 'spam restart'
	sleep 10
	exit 1
fi

bashio::log.info "WireGuard config file is found at ${VPN_CONFIG}"
if [[ "${VPN_CONFIG}" != "/config/wireguard/wg0.conf" ]]; then
	bashio::log.error "WireGuard config filename is not 'wg0.conf'"
	bashio::log.error "Rename ${VPN_CONFIG} to 'wg0.conf'"
	sleep 10
	exit 1
fi

# parse values from the wireguard conf file
export vpn_remote_line=$(cat "${VPN_CONFIG}" | grep -o -m 1 '^Endpoint\s=\s.*$' | cut -d \  -f 3)

if [[ ! -z "${vpn_remote_line}" ]]; then
	bashio::log.info "VPN remote line defined as '${vpn_remote_line}'"
else
	bashio::log.error "VPN configuration file ${VPN_CONFIG} does not contain 'remote' line, showing contents of file before exit..."
	cat "${VPN_CONFIG}"
	
	# Sleep so it wont 'spam restart'
	sleep 10
	exit 1
fi

export VPN_REMOTE=$(echo "${vpn_remote_line}" | cut -d : -f 1)

if [[ ! -z "${VPN_REMOTE}" ]]; then
	bashio::log.info "VPN_REMOTE defined as '${VPN_REMOTE}'"
else
	bashio::log.error "VPN_REMOTE not found in ${VPN_CONFIG}, exiting..."
	
	# Sleep so it wont 'spam restart'
	sleep 10
	exit 1
fi

export VPN_PORT=$(echo "${vpn_remote_line}" | cut -d : -f 2)

if [[ ! -z "${VPN_PORT}" ]]; then
	bashio::log.info "VPN_PORT defined as '${VPN_PORT}'"
else
	bashio::log.error "VPN_PORT not found in ${VPN_CONFIG}, exiting..."
	
	# Sleep so it wont 'spam restart'
	sleep 10
	exit 1
fi

export VPN_PROTOCOL="udp"
bashio::log.info "VPN_PROTOCOL set as '${VPN_PROTOCOL}', since WireGuard is always ${VPN_PROTOCOL}."

export VPN_DEVICE_TYPE="wg0"
bashio::log.info "VPN_DEVICE_TYPE set as '${VPN_DEVICE_TYPE}', since WireGuard will always be wg0."

# get values from env vars as defined by user
export LAN_NETWORK=$(echo "${LAN_NETWORK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${LAN_NETWORK}" ]]; then
	bashio::log.info "LAN_NETWORK defined as '${LAN_NETWORK}'"
else
	bashio::log.error "LAN_NETWORK not defined (via -e LAN_NETWORK), exiting..."
	# Sleep so it wont 'spam restart'
	sleep 10
	exit 1
fi

export NAME_SERVERS=$(echo "${NAME_SERVERS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${NAME_SERVERS}" ]]; then
	bashio::log.info "NAME_SERVERS defined as '${NAME_SERVERS}'"
else
	bashio::log.warning "NAME_SERVERS not defined (via -e NAME_SERVERS), defaulting to CloudFlare and Google name servers"
	export NAME_SERVERS="1.1.1.1,8.8.8.8,1.0.0.1,8.8.4.4"
fi

# split comma seperated string into list from NAME_SERVERS env variable
IFS=',' read -ra name_server_list <<< "${NAME_SERVERS}"

# process name servers in the list
for name_server_item in "${name_server_list[@]}"; do
	# strip whitespace from start and end of lan_network_item
	name_server_item=$(echo "${name_server_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	bashio::log.info "Adding ${name_server_item} to resolv.conf"
	echo "nameserver ${name_server_item}" >> /etc/resolv.conf
done

if [[ -z "${PUID}" ]]; then
	bashio::log.info "PUID not defined. Defaulting to root user"
	export PUID="root"
fi

if [[ -z "${PGID}" ]]; then
	bashio::log.info "PGID not defined. Defaulting to root group"
	export PGID="root"
fi

bashio::log.info "Starting WireGuard..."
cd /config/wireguard
if ip link | grep -q `basename -s .conf $VPN_CONFIG`; then
	wg-quick down $VPN_CONFIG || bashio::log.info "WireGuard is down already" # Run wg-quick down as an extra safeguard in case WireGuard is still up for some reason
	sleep 0.5 # Just to give WireGuard a bit to go down
fi
wg-quick up $VPN_CONFIG

exec /etc/qbittorrent/iptables.sh
