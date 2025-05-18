#!/usr/bin/bashio

# undo options set by bashio
set +e
set +E
set +u
set +o pipefail


# Check if /config/qBittorrent exists, if not make the directory
if [[ ! -e /config/qBittorrent/config ]]; then
	mkdir -p /config/qBittorrent/config
fi
# Set the correct rights accordingly to the PUID and PGID on /config/qBittorrent
chown -R ${PUID}:${PGID} /config/qBittorrent

# Check if qBittorrent.conf exists, if not, copy the template over
if [ ! -e /config/qBittorrent/config/qBittorrent.conf ]; then
	bashio::log.warning "qBittorrent.conf is missing, this is normal for the first launch! Copying template."
	cp /etc/qbittorrent/qBittorrent.conf /config/qBittorrent/config/qBittorrent.conf
	chmod 755 /config/qBittorrent/config/qBittorrent.conf
	chown ${PUID}:${PGID} /config/qBittorrent/config/qBittorrent.conf
fi

# The mess down here checks if SSL is enabled.
export ENABLE_SSL=$(echo "${ENABLE_SSL,,}")

if [[ ${ENABLE_SSL} == "1" || ${ENABLE_SSL} == "true" || ${ENABLE_SSL} == "yes" ]]; then
	bashio::log.info "ENABLE_SSL is set to '${ENABLE_SSL}'"
	if [[ ${HOST_OS,,} == 'unraid' ]]; then
		bashio::log.notice "If you use Unraid, and get something like a 'ERR_EMPTY_RESPONSE' in your browser, add https:// to the front of the IP, and/or do this:"
		bashio::log.notice "Edit this Docker, change the slider in the top right to 'advanced view' and change http to https at the WebUI setting."
	fi
	# Allow for cert and key to be secrets
	if [[ -e /run/secrets/WebUICertificate.crt ]]; then
		# Overwrite if they exist, assume secret is correct so that certs can be easily updated
		rm /config/qBittorrent/config/WebUICertificate.crt
		ln -s /run/secrets/WebUICertificate.crt /config/qBittorrent/config/WebUICertificate.crt
	fi
	if [[ -e /run/secrets/WebUIKey.key ]]; then
		rm /config/qBittorrent/config/WebUIKey.key
		ln -s /run/secrets/WebUIKey.key /config/qBittorrent/config/WebUIKey.key
	fi
	if [ ! -e /config/qBittorrent/config/WebUICertificate.crt ]; then
		bashio::log.warning "WebUI Certificate is missing, generating a new Certificate and Key"
		openssl req -new -x509 -nodes -out /config/qBittorrent/config/WebUICertificate.crt -keyout /config/qBittorrent/config/WebUIKey.key -subj "/C=NL/ST=localhost/L=localhost/O=/OU=/CN="
		chown -R ${PUID}:${PGID} /config/qBittorrent/config
	elif [ ! -e /config/qBittorrent/config/WebUIKey.key ]; then
		bashio::log.warning "WebUI Key is missing, generating a new Certificate and Key"
		openssl req -new -x509 -nodes -out /config/qBittorrent/config/WebUICertificate.crt -keyout /config/qBittorrent/config/WebUIKey.key -subj "/C=NL/ST=localhost/L=localhost/O=/OU=/CN="
		chown -R ${PUID}:${PGID} /config/qBittorrent/config
	fi
	if grep -Fxq 'WebUI\HTTPS\CertificatePath=/config/qBittorrent/config/WebUICertificate.crt' "/config/qBittorrent/config/qBittorrent.conf"; then
		bashio::log.info "/config/qBittorrent/config/qBittorrent.conf already has the line WebUICertificate.crt loaded, nothing to do."
	else
		bashio::log.warning "/config/qBittorrent/config/qBittorrent.conf doesn't have the WebUICertificate.crt loaded. Added it to the config."
		echo 'WebUI\HTTPS\CertificatePath=/config/qBittorrent/config/WebUICertificate.crt' >>"/config/qBittorrent/config/qBittorrent.conf"
	fi
	if grep -Fxq 'WebUI\HTTPS\KeyPath=/config/qBittorrent/config/WebUIKey.key' "/config/qBittorrent/config/qBittorrent.conf"; then
		bashio::log.info "/config/qBittorrent/config/qBittorrent.conf already has the line WebUIKey.key loaded, nothing to do."
	else
		bashio::log.warning "/config/qBittorrent/config/qBittorrent.conf doesn't have the WebUIKey.key loaded. Added it to the config."
		echo 'WebUI\HTTPS\KeyPath=/config/qBittorrent/config/WebUIKey.key' >>"/config/qBittorrent/config/qBittorrent.conf"
	fi
	if grep -xq 'WebUI\\HTTPS\\Enabled=true\|WebUI\\HTTPS\\Enabled=false' "/config/qBittorrent/config/qBittorrent.conf"; then
		if grep -xq 'WebUI\\HTTPS\\Enabled=false' "/config/qBittorrent/config/qBittorrent.conf"; then
			bashio::log.warning "/config/qBittorrent/config/qBittorrent.conf does have the WebUI\HTTPS\Enabled set to false, changing it to true."
			sed -i 's/WebUI\\HTTPS\\Enabled=false/WebUI\\HTTPS\\Enabled=true/g' "/config/qBittorrent/config/qBittorrent.conf"
		else
			bashio::log.info "/config/qBittorrent/config/qBittorrent.conf does have the WebUI\HTTPS\Enabled already set to true."
		fi
	else
		bashio::log.warning "/config/qBittorrent/config/qBittorrent.conf doesn't have the WebUI\HTTPS\Enabled loaded. Added it to the config."
		echo 'WebUI\HTTPS\Enabled=true' >>"/config/qBittorrent/config/qBittorrent.conf"
	fi
elif [[ ${ENABLE_SSL} == "0" || ${ENABLE_SSL} == "false" || ${ENABLE_SSL} == "no" ]]; then
	bashio::log.warning "ENABLE_SSL is set to '${ENABLE_SSL}', SSL is not enabled. This could cause issues with logging if other apps use the same Cookie name (SID)."
	bashio::log.warning "Removing the SSL configuration from the config file..."
	sed -i '/^WebUI\\HTTPS*/d' "/config/qBittorrent/config/qBittorrent.conf"
else
	bashio::log.warning "ENABLE_SSL is set to '${ENABLE_SSL}', SSL config ignored. No changes made."
fi

# Check qbtUser, change UID/GID if they don't match the environment variables.
qbtUID=$(id -u qbtUser)
qbtGID=$(id -g qbtUser)
if [[ ${PUID} != $qbtUID || ${PGID} != $qbtGID ]]; then
	usermod -u ${PUID} -g ${PGID} qbtUser
fi

# Start qBittorrent
bashio::log.info "Starting qBittorrent daemon..."
chmod -R 755 /config/qBittorrent
nohup /bin/bash /entrypoint.sh >/dev/null 2>&1 &

# wait for the entrypoint.sh script to finish and grab the qbittorrent pid
while ! pgrep -f "qbittorrent-nox" >/dev/null; do
	sleep 0.5
done
qbittorrentpid=$(pgrep -f "qbittorrent-nox")

# If the process exists, make sure that the log file has the proper rights and start the health check
if [ -e /proc/$qbittorrentpid ]; then
	bashio::log.info "qBittorrent PID: $qbittorrentpid"

	if [[ -e /config/qBittorrent/data/logs/qbittorrent.log ]]; then
		chmod 775 /config/qBittorrent/data/logs/qbittorrent.log
	fi

	# Set some variables that are used
	HOST=${HEALTH_CHECK_HOST}
	DEFAULT_HOST="one.one.one.one"
	INTERVAL=${HEALTH_CHECK_INTERVAL}
	DEFAULT_INTERVAL=300
	DEFAULT_HEALTH_CHECK_AMOUNT=1

	# If host is zero (not set) default it to the DEFAULT_HOST variable
	if [[ -z "${HOST}" ]]; then
		bashio::log.info "HEALTH_CHECK_HOST is not set. For now using default host ${DEFAULT_HOST}"
		HOST=${DEFAULT_HOST}
	fi

	# If HEALTH_CHECK_INTERVAL is zero (not set) default it to DEFAULT_INTERVAL
	if [[ -z "${HEALTH_CHECK_INTERVAL}" ]]; then
		bashio::log.info "HEALTH_CHECK_INTERVAL is not set. For now using default interval of ${DEFAULT_INTERVAL}"
		INTERVAL=${DEFAULT_INTERVAL}
	fi

	# If HEALTH_CHECK_SILENT is zero (not set) default it to supression
	if [[ -z "${HEALTH_CHECK_SILENT}" ]]; then
		bashio::log.info "HEALTH_CHECK_SILENT is not set. Because this variable is not set, it will be supressed by default"
		HEALTH_CHECK_SILENT=1
	fi

	if [ ! -z ${RESTART_CONTAINER} ]; then
		bashio::log.info "RESTART_CONTAINER defined as '${RESTART_CONTAINER}'"
	else
		bashio::log.warning "RESTART_CONTAINER not defined,(via -e RESTART_CONTAINER), defaulting to 'yes'"
		export RESTART_CONTAINER="yes"
	fi

	# If HEALTH_CHECK_AMOUNT is zero (not set) default it to DEFAULT_HEALTH_CHECK_AMOUNT
	if [[ -z ${HEALTH_CHECK_AMOUNT} ]]; then
		bashio::log.info "HEALTH_CHECK_AMOUNT is not set. For now using default interval of ${DEFAULT_HEALTH_CHECK_AMOUNT}"
		HEALTH_CHECK_AMOUNT=${DEFAULT_HEALTH_CHECK_AMOUNT}
	fi
	bashio::log.info "HEALTH_CHECK_AMOUNT is set to ${HEALTH_CHECK_AMOUNT}"

	while true; do
		# First wait for the health check interval.
		sleep ${INTERVAL}

		# Confirm the process is still running, start it back up if it's not.
		if ! ps -p $qbittorrentpid >/dev/null; then
			bashio::log.error "qBittorrent daemon is not running. Restarting..."
			nohup /bin/bash /entrypoint.sh >/dev/null 2>&1 &

			# wait for the entrypoint.sh script to finish and grab the qbittorrent pid
			while ! pgrep -f "qbittorrent-nox" >/dev/null; do
				sleep 0.5
			done
			qbittorrentpid=$(pgrep -f "qbittorrent-nox")
		fi
		# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks, therefore we use this script to catch error code 2
		ping -c ${HEALTH_CHECK_AMOUNT} $HOST >/dev/null 2>&1
		STATUS=$?
		if [[ "${STATUS}" -ne 0 ]]; then
			bashio::log.error "Network is possibly down."
			sleep 1
			if [[ ${RESTART_CONTAINER,,} == "1" || ${RESTART_CONTAINER,,} == "true" || ${RESTART_CONTAINER,,} == "yes" ]]; then
				bashio::log.info "Restarting container."
				exit 1
			fi
		fi
		if [[ ${HEALTH_CHECK_SILENT,,} == "0" || ${HEALTH_CHECK_SILENT,,} == "false" || ${HEALTH_CHECK_SILENT,,} == "no" ]]; then
			bashio::log.info "Network is up"
		fi

		# Check the NAT port forward and update qBittorrent config if there is a change.
		if [[ $ENABLEPROTONVPNPORTFWD -eq 1 ]]; then
			if [[ -e /run/secrets/webui_pass ]]; then
				WEBUI_PASS=$(cat /run/secrets/webui_pass)
			fi
			loginData="username=$WEBUI_USER&password=$WEBUI_PASS"
			cookie=$(curl -i --silent --header "Referer: $WEBUI_URL" --data $loginData $WEBUI_URL/api/v2/auth/login | grep "set-cookie" | awk '/set-cookie:/ {print $2}' | sed 's/;//') >/dev/null 2>&1
			if [[ $cookie ]]; then
				setPort=$(curl --silent $WEBUI_URL/api/v2/app/preferences --cookie $cookie | jq '.listen_port') >/dev/null 2>&1
				currentPort=$(natpmpc -a 1 0 udp 60 -g 10.2.0.1 | grep "public port" | awk '/Mapped public port/ {print $4}')
				if [[ $setPort -ne $currentPort ]]; then
					portData="json={\"listen_port\":$currentPort}"
					curl -i --silent --data $portData $WEBUI_URL/api/v2/app/setPreferences --cookie $cookie >/dev/null 2>&1
				fi
				curl --silent -X 'POST' "$WEBUI_URL/api/v2/auth/logout" -H 'accept: */*' -d '' --cookie $cookie >/dev/null 2>&1
			else
				bashio::log.warning "Unable to log into the web UI."
			fi
			unset cookie
		fi
	done
else
	bashio::log.error "qBittorrent failed to start!"
fi
