FROM debian:10-slim

WORKDIR /opt

RUN usermod -u 99 nobody

# Make directories
RUN mkdir -p /downloads /config/SABnzbd /etc/openvpn /etc/sabnzbd

# Install SABnzbd and its dependencies
RUN echo "deb http://deb.debian.org/debian/ buster non-free" > /etc/apt/sources.list.d/non-free-unrar.list \
    && printf 'Package: *\nPin: release a=non-free\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-non-free \
    && apt update \
    && apt -y upgrade \
    && apt -y install --no-install-recommends \
	ca-certificates \
	curl \
	jq \
	libffi6 \
	libpython3.7 \
	libssl1.1 \
	p7zip-full \
	par2 \
	python3 \
	python3-pip \
	python3-setuptools \
	unrar \
	unzip \
	zip \
    && SABNZBD_ASSETS=$(curl -sX GET "https://api.github.com/repos/sabnzbd/sabnzbd/releases" | jq '.[0] .assets_url' | tr -d '"') \
    && SABNZBD_DOWNLOAD_URL=$(curl -sX GET ${SABNZBD_ASSETS} | jq '.[] | select(.name | contains("tar.gz")) .browser_download_url' | tr -d '"') \
    && SABNZBD_NAME=$(curl -sX GET ${SABNZBD_ASSETS} | jq '.[] | select(.name | contains("tar.gz")) .name' | tr -d '"') \
    && curl -o /opt/${SABNZBD_NAME} -L ${SABNZBD_DOWNLOAD_URL} \
    && tar -xzf /opt/${SABNZBD_NAME} \
    && rm /opt/${SABNZBD_NAME} \
    && mv SABnzbd* SABnzbd \
    && cd /opt/SABnzbd \
    && python3 -m pip install wheel -U \
    && python3 -m pip install -r requirements.txt -U \
    && apt-get clean \
    && apt -y autoremove \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Install WireGuard, OpenVPN and other dependencies for running the container scripts
RUN echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable-wireguard.list \ 
    && printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable \
    && apt update \
    && apt -y install --no-install-recommends \
    ca-certificates \
    curl \
    dos2unix \
    inetutils-ping \
    ipcalc \
    iptables \
    kmod \
    moreutils \
    net-tools \
    openresolv \
    openvpn \
    procps \
    wireguard-tools \
    && apt-get clean \
    && apt -y autoremove \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

VOLUME /config /downloads

ADD openvpn/ /etc/openvpn/
ADD sabnzbd/ /etc/sabnzbd/

RUN chmod +x /etc/sabnzbd/*.sh /etc/sabnzbd/*.init /etc/openvpn/*.sh

EXPOSE 8080
EXPOSE 8443
CMD ["/bin/bash", "/etc/openvpn/start.sh"]
