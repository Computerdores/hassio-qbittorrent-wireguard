#!/usr/bin/bashio
# Forked from binhex's OpenVPN dockers
# undo options set by bashio
set +e
set +E
set +u
set +o pipefail


# Wait until tunnel is up
while :; do
	tunnelstat=$(netstat -ie | grep -E "tun|tap|wg")
	if [[ ! -z "${tunnelstat}" ]]; then
		break
	else
		sleep 1
	fi
done

# identify docker bridge interface name (probably eth0)
docker_interface=$(netstat -ie | grep -vE "lo|tun|tap|wg" | sed -n '1!p' | head -n 1 | cut -d : -f 1)
if [[ "${DEBUG}" == "true" ]]; then
	bashio::log.debug "Docker interface defined as ${docker_interface}"
fi

# identify ip for docker bridge interface
docker_ip=$(ifconfig "${docker_interface}" | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
if [[ "${DEBUG}" == "true" ]]; then
	bashio::log.debug "Docker IP defined as ${docker_ip}"
fi

# identify netmask for docker bridge interface
docker_mask=$(ifconfig "${docker_interface}" | grep -o "netmask [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
if [[ "${DEBUG}" == "true" ]]; then
	bashio::log.debug "Docker netmask defined as ${docker_mask}"
fi

# convert netmask into cidr format
docker_network_cidr=$(ipcalc "${docker_ip}" "${docker_mask}" | grep -o -m 1 'Network:\s*.*' | cut -d : -f 2 | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
bashio::log.info "Docker network defined as ${docker_network_cidr}"

# ip route
###

# get default gateway of interfaces as looping through them
DEFAULT_GATEWAY=$(ip -4 route list 0/0 | cut -d ' ' -f 3)

# split comma separated string into list from LAN_NETWORK env variable
IFS=',' read -ra lan_network_list <<<"${LAN_NETWORK}"

# process lan networks in the list
for lan_network_item in "${lan_network_list[@]}"; do
	# strip whitespace from start and end of lan_network_item
	lan_network_item=$(echo "${lan_network_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	bashio::log.info "Adding ${lan_network_item} as route via docker ${docker_interface}"
	ip route add "${lan_network_item}" via "${DEFAULT_GATEWAY}" dev "${docker_interface}"
done

bashio::log.info "ip route defined as follows..."
echo "--------------------"
ip route
echo "--------------------"

# setup iptables marks to allow routing of defined ports via "${docker_interface}"
###

if [[ "${DEBUG}" == "true" ]]; then
	bashio::log.debug "Modules currently loaded for kernel"
	lsmod
fi

# check we have iptable_mangle, if so setup fwmark
lsmod | grep iptable_mangle
iptable_mangle_exit_code=$?

if [[ $iptable_mangle_exit_code == 0 ]]; then
	bashio::log.info "iptable_mangle support detected, adding fwmark for tables"

	# Make directory if doesn't exist
	if [[ ! -e /etc/iproute2 ]]; then
		mkdir /etc/iproute2
	fi
	# setup route for qBittorrent webui using set-mark to route traffic for port 8080 and 8999 to "${docker_interface}"
	echo "8080    webui" >>/etc/iproute2/rt_tables
	echo "8999    webui" >>/etc/iproute2/rt_tables
	ip rule add fwmark 1 table webui
	ip route add default via ${DEFAULT_GATEWAY} table webui
fi

# input iptable rules
###

# set policy to drop ipv4 for input
iptables -P INPUT DROP

# set policy to drop ipv6 for input
ip6tables -P INPUT DROP 1>&- 2>&-

# accept input to tunnel adapter
iptables -A INPUT -i "${VPN_DEVICE_TYPE}" -j ACCEPT

# accept input to/from LANs (172.x range is internal dhcp)
iptables -A INPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

# accept input to vpn gateway
iptables -A INPUT -i "${docker_interface}" -p $VPN_PROTOCOL --sport $VPN_PORT -j ACCEPT

# accept input to qBittorrent webui port
iptables -A INPUT -i "${docker_interface}" -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -i "${docker_interface}" -p tcp --sport 8080 -j ACCEPT

# additional port list for scripts or container linking
if [[ ! -z "${ADDITIONAL_PORTS}" ]]; then
	# split comma separated string into list from ADDITIONAL_PORTS env variable
	IFS=',' read -ra additional_port_list <<<"${ADDITIONAL_PORTS}"

	# process additional ports in the list
	for additional_port_item in "${additional_port_list[@]}"; do

		# strip whitespace from start and end of additional_port_item
		additional_port_item=$(echo "${additional_port_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

		bashio::log.info "Adding additional incoming port ${additional_port_item} for ${docker_interface}"

		# accept input to additional port for "${docker_interface}"
		iptables -A INPUT -i "${docker_interface}" -p tcp --dport "${additional_port_item}" -j ACCEPT
		iptables -A INPUT -i "${docker_interface}" -p tcp --sport "${additional_port_item}" -j ACCEPT
	done
fi

# accept input icmp (ping)
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# accept input to local loopback
iptables -A INPUT -i lo -j ACCEPT

# output iptable rules
###

# set policy to drop ipv4 for output
iptables -P OUTPUT DROP

# set policy to drop ipv6 for output
ip6tables -P OUTPUT DROP 1>&- 2>&-

# accept output from tunnel adapter
iptables -A OUTPUT -o "${VPN_DEVICE_TYPE}" -j ACCEPT

# accept output to/from LANs
iptables -A OUTPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

# accept output from vpn gateway
iptables -A OUTPUT -o "${docker_interface}" -p $VPN_PROTOCOL --dport $VPN_PORT -j ACCEPT

# if iptable mangle is available (kernel module) then use mark
if [[ $iptable_mangle_exit_code == 0 ]]; then
	# accept output from qBittorrent webui port - used for external access
	iptables -t mangle -A OUTPUT -p tcp --dport 8080 -j MARK --set-mark 1
	iptables -t mangle -A OUTPUT -p tcp --sport 8080 -j MARK --set-mark 1
fi

# accept output from qBittorrent webui port - used for lan access
iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport 8080 -j ACCEPT
iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport 8080 -j ACCEPT

# additional port list for scripts or container linking
if [[ ! -z "${ADDITIONAL_PORTS}" ]]; then
	# split comma separated string into list from ADDITIONAL_PORTS env variable
	IFS=',' read -ra additional_port_list <<<"${ADDITIONAL_PORTS}"

	# process additional ports in the list
	for additional_port_item in "${additional_port_list[@]}"; do

		# strip whitespace from start and end of additional_port_item
		additional_port_item=$(echo "${additional_port_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

		bashio::log.info "Adding additional outgoing port ${additional_port_item} for ${docker_interface}"

		# accept output to additional port for lan interface
		iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport "${additional_port_item}" -j ACCEPT
		iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport "${additional_port_item}" -j ACCEPT

	done
fi

# accept output for icmp (ping)
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

# accept output from local loopback adapter
iptables -A OUTPUT -o lo -j ACCEPT

bashio::log.info "iptables defined as follows..."
echo "--------------------"
iptables -S
echo "--------------------"

# start the NAT-PMP port forward loop
if [[ $ENABLEPROTONVPNPORTFWD -eq 1 ]]; then
	nohup /etc/qbittorrent/portfwd.sh &
fi
exec /etc/qbittorrent/start.sh
