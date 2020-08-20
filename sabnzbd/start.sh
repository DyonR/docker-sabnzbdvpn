#!/bin/bash
# Check if /config/SABnzbd exists, if not make the directory
if [[ ! -e /config/SABnzbd/config ]]; then
	mkdir -p /config/SABnzbd/config
fi
# Set the correct rights accordingly to the PUID and PGID on /config/SABnzbd
chown -R ${PUID}:${PGID} /config/SABnzbd

# Set the rights on the /downloads folder
chown -R ${PUID}:${PGID} /downloads

# Check if ServerConfig.json exists, if not, copy the template over
if [ ! -e /config/SABnzbd/sabnzbd.ini ]; then
	echo "[WARNING] sabnzbd.ini is missing, this is normal for the first launch! Copying template." | ts '%Y-%m-%d %H:%M:%.S'
	cp /etc/sabnzbd/sabnzbd.ini /config/SABnzbd/sabnzbd.ini
	chmod 755 /config/SABnzbd/sabnzbd.ini
	chown ${PUID}:${PGID} /config/SABnzbd/sabnzbd.ini
fi

# Check if the PGID exists, if not create the group with the name 'sabnzbd'
grep $"${PGID}:" /etc/group > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "[INFO] A group with PGID $PGID already exists in /etc/group, nothing to do." | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[INFO] A group with PGID $PGID does not exist, adding a group called 'sabnzbd' with PGID $PGID" | ts '%Y-%m-%d %H:%M:%.S'
	groupadd -g $PGID sabnzbd
fi

# Check if the PUID exists, if not create the user with the name 'sabnzbd', with the correct group
grep $"${PUID}:" /etc/passwd > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "[INFO] An user with PUID $PUID already exists in /etc/passwd, nothing to do." | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[INFO] An user with PUID $PUID does not exist, adding an user called 'sabnzbd user' with PUID $PUID" | ts '%Y-%m-%d %H:%M:%.S'
	useradd -c "sabnzbd user" -g $PGID -u $PUID sabnzbd
fi

# Set the umask
if [[ ! -z "${UMASK}" ]]; then
	echo "[INFO] UMASK defined as '${UMASK}'" | ts '%Y-%m-%d %H:%M:%.S'
	export UMASK=$(echo "${UMASK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
else
	echo "[WARNING] UMASK not defined (via -e UMASK), defaulting to '002'" | ts '%Y-%m-%d %H:%M:%.S'
	export UMASK="002"
fi

# Start SABnzbd
echo "[INFO] Starting SABnzbd daemon..." | ts '%Y-%m-%d %H:%M:%.S'
/bin/bash /etc/sabnzbd/sabnzbd.init start &
chmod -R 755 /config/sabnzbd

# Wait a second for it to start up and get the process id
sleep 1
sabnzbdpid=$(pgrep -o -x python3) 
echo "[INFO] SABnzbd PID: $sabnzbdpid" | ts '%Y-%m-%d %H:%M:%.S'

# If the process exists, make sure that the log file has the proper rights and start the health check
if [ -e /proc/$sabnzbdpid ]; then
	if [[ -e /config/SABnzbd/logs/sabnzbd_init.log ]]; then
		chmod 775 /config/SABnzbd/logs/sabnzbd_init.log
	fi
	
	# Set some variables that are used
	HOST=${HEALTH_CHECK_HOST}
	DEFAULT_HOST="one.one.one.one"
	INTERVAL=${HEALTH_CHECK_INTERVAL}
	DEFAULT_INTERVAL=300
	
	# If host is zero (not set) default it to the DEFAULT_HOST variable
	if [[ -z "${HOST}" ]]; then
		echo "[INFO] HEALTH_CHECK_HOST is not set. For now using default host ${DEFAULT_HOST}" | ts '%Y-%m-%d %H:%M:%.S'
		HOST=${DEFAULT_HOST}
	fi

	# If HEALTH_CHECK_INTERVAL is zero (not set) default it to DEFAULT_INTERVAL
	if [[ -z "${HEALTH_CHECK_INTERVAL}" ]]; then
		echo "[INFO] HEALTH_CHECK_INTERVAL is not set. For now using default interval of ${DEFAULT_INTERVAL}" | ts '%Y-%m-%d %H:%M:%.S'
		INTERVAL=${DEFAULT_INTERVAL}
	fi
	
	# If HEALTH_CHECK_SILENT is zero (not set) default it to supression
	if [[ -z "${HEALTH_CHECK_SILENT}" ]]; then
		echo "[INFO] HEALTH_CHECK_SILENT is not set. Because this variable is not set, it will be supressed by default" | ts '%Y-%m-%d %H:%M:%.S'
		HEALTH_CHECK_SILENT=1
	fi

	while true; do
		# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks, therefore we use this script to catch error code 2
		ping -c 1 $HOST > /dev/null 2>&1
		STATUS=$?
		if [[ "${STATUS}" -ne 0 ]]; then
			echo "[ERROR] Network is down, exiting this Docker" | ts '%Y-%m-%d %H:%M:%.S'
			exit 1
		fi
		if [ ! "${HEALTH_CHECK_SILENT}" -eq 1 ]; then
			echo "[INFO] Network is up" | ts '%Y-%m-%d %H:%M:%.S'
		fi
		sleep ${INTERVAL}
	done
else
	echo "[ERROR] SABnzbd failed to start!" | ts '%Y-%m-%d %H:%M:%.S'
fi
