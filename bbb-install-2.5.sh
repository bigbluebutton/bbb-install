#!/bin/bash -e

# Copyright (c) 2022 BigBlueButton Inc.
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

# BigBlueButton is an open source conferencing system. For more information see
#    https://www.bigbluebutton.org/.
#
# This bbb-install-2.5.sh script automates many of the installation and configuration
# steps at
#    https://docs.bigbluebutton.org/2.5/install.html
#
#
#  Examples
#
#  Install BigBlueButton 2.5.x with a SSL certificate from Let's Encrypt using hostname bbb.example.com
#  and email address info@example.com and apply a basic firewall
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install-2.5.sh | bash -s -- -w -v focal-250 -s bbb.example.com -e info@example.com 
#
#  Same as above but also install the API examples for testing.
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install-2.5.sh | bash -s -- -w -a -v focal-250 -s bbb.example.com -e info@example.com 
#
#  Install BigBlueButton with SSL + Greenlight
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install-2.5.sh | bash -s -- -w -v focal-250 -s bbb.example.com -e info@example.com -g
#

usage() {
    set +x
    cat 1>&2 <<HERE

Script for installing a BigBlueButton 2.5 (or later) server in under 30 minutes.

This script also supports installation of a coturn (TURN) server on a separate server.

USAGE:
    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install-2.5.sh | bash -s -- [OPTIONS]

OPTIONS (install BigBlueButton):

  -v <version>           Install given version of BigBlueButton (e.g. 'focal-250') (required)

  -s <hostname>          Configure server with <hostname>
  -e <email>             Email for Let's Encrypt certbot

  -x                     Use Let's Encrypt certbot with manual dns challenges

  -a                     Install BBB API demos
  -g                     Install Greenlight
  -c <hostname>:<secret> Configure with coturn server at <hostname> using <secret>

  -m <link_path>         Create a Symbolic link from /var/bigbluebutton to <link_path> 

  -p <host>              Use apt-get proxy at <host>
  -r <host>              Use alternative apt repository (such as packages-eu.bigbluebutton.org)

  -d                     Skip SSL certificates request (use provided certificates from mounted volume) in /local/certs/
  -w                     Install UFW firewall (recommended)

  -h                     Print help

OPTIONS (install coturn only):

  -c <hostname>:<secret> Setup a coturn server with <hostname> and <secret> (required)
  -e <email>             Configure email for Let's Encrypt certbot (required)

OPTIONS (install Let's Encrypt certificate only):

  -s <hostname>          Configure server with <hostname> (required)
  -e <email>             Configure email for Let's Encrypt certbot (required)
  -l                     Only install Let's Encrypt certificate (not BigBlueButton)
  -x                     Use Let's Encrypt certbot with manual dns challenges (optional)


EXAMPLES:

Sample options for setup a BigBlueButton server

    -v focal-250 -s bbb.example.com -e info@example.com
    -v focal-250 -s bbb.example.com -e info@example.com -g
    -v focal-250 -s bbb.example.com -e info@example.com -g -c turn.example.com:1234324

Sample options for setup of a coturn server (on a Ubuntu 20.04)

    -c turn.example.com:1234324 -e info@example.com

SUPPORT:
    Community: https://bigbluebutton.org/support
         Docs: https://github.com/bigbluebutton/bbb-install

HERE
}

main() {
  export DEBIAN_FRONTEND=noninteractive
  PACKAGE_REPOSITORY=ubuntu.bigbluebutton.org
  LETS_ENCRYPT_OPTIONS="--webroot --non-interactive"
  SOURCES_FETCHED=false

  need_x64

  while builtin getopts "hs:r:c:v:e:p:m:lxgadw" opt "${@}"; do

    case $opt in
      h)
        usage
        exit 0
        ;;

      s)
        HOST=$OPTARG
        if [ "$HOST" == "bbb.example.com" ]; then 
          err "You must specify a valid hostname (not the hostname given in the docs)."
        fi
        ;;
      r)
        PACKAGE_REPOSITORY=$OPTARG
        ;;
      e)
        EMAIL=$OPTARG
        if [ "$EMAIL" == "info@example.com" ]; then 
          err "You must specify a valid email address (not the email in the docs)."
        fi
        ;;
      x)
        LETS_ENCRYPT_OPTIONS="--manual --preferred-challenges dns"
        ;;
      c)
        COTURN=$OPTARG
        check_coturn "$COTURN"
        ;;
      v)
        VERSION=$OPTARG
        ;;

      p)
        PROXY=$OPTARG
        if [ -n "$PROXY" ]; then
          echo "Acquire::http::Proxy \"http://$PROXY:3142\";"  > /etc/apt/apt.conf.d/01proxy
        fi
        ;;

      l)
        LETS_ENCRYPT_ONLY=true
        ;;
      g)
        GREENLIGHT=true
        ;;
      a)
        API_DEMOS=true
        ;;
      m)
        LINK_PATH=$OPTARG
        ;;
      d)
        PROVIDED_CERTIFICATE=true
        ;;
      w)
        SSH_PORT=$(grep Port /etc/ssh/ssh_config | grep -v \# | sed 's/[^0-9]*//g')
        if [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]]; then
          err "Detected sshd not listening to standard port 22 -- unable to install default UFW firewall rules.  See https://docs.bigbluebutton.org/2.2/customize.html#secure-your-system--restrict-access-to-specific-ports"
        fi
        UFW=true
        ;;

      :)
        err "Missing option argument for -$OPTARG"
        exit 1
        ;;

      \?)
        err "Invalid option: -$OPTARG" >&2
        usage
        ;;
    esac
  done

  if [ -n "$HOST" ]; then
    check_host "$HOST"
  fi

  if [ -n "$VERSION" ]; then
    check_version "$VERSION"
  fi

  check_apache2

  # Check if we're installing coturn (need an e-mail address for Let's Encrypt)
  if [ -z "$VERSION" ] && [ -n "$COTURN" ]; then
    if [ -z "$EMAIL" ]; then err "Installing coturn needs an e-mail address for Let's Encrypt"; fi
    check_ubuntu 20.04

    install_coturn
    exit 0
  fi

  if [ -z "$VERSION" ]; then
    usage
    exit 0
  fi

  # We're installing BigBlueButton
  env

  if [ "$DISTRO" == "focal" ]; then 
    check_ubuntu 20.04
    TOMCAT_USER=tomcat9
  fi
  check_mem

  need_pkg software-properties-common  # needed for add-apt-repository
  sudo add-apt-repository universe
  need_pkg wget curl gpg-agent dirmngr

  # need_pkg xmlstarlet
  get_IP "$HOST"

  if [ "$DISTRO" == "focal" ]; then
    need_pkg ca-certificates

    # yq version 3 is provided by ppa:bigbluebutton/support
    # Uncomment the following to enable yq 4 after bigbluebutton/bigbluebutton#14511 is resolved
    #need_ppa rmescandon-ubuntu-yq-bionic.list         ppa:rmescandon/yq          CC86BB64 # Edit yaml files with yq

    #need_ppa libreoffice-ubuntu-ppa-focal.list       ppa:libreoffice/ppa        1378B444 # Latest version of libreoffice
    need_ppa bigbluebutton-ubuntu-support-focal.list ppa:bigbluebutton/support  E95B94BC # Needed for libopusenc0
    if ! apt-key list 5AFA7A83 | grep -q -E "1024|4096"; then   # Add Kurento package
      sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5AFA7A83
    fi

    rm -rf /etc/apt/sources.list.d/kurento.list     # Kurento 6.15 now packaged with 2.3

    if grep -q 12 /etc/apt/sources.list.d/nodesource.list ; then # Node 12 might be installed, previously used in BigBlueButton
      sudo apt-get purge nodejs
      sudo rm -r /etc/apt/sources.list.d/nodesource.list
    fi
    if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
      curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    fi
    if ! apt-cache madison nodejs | grep -q node_16; then
      err "Did not detect nodejs 16.x candidate for installation"
    fi
    if ! apt-key list MongoDB | grep -q 4.4; then
      wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    fi
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    rm -f /etc/apt/sources.list.d/mongodb-org-4.2.list

    touch /root/.rnd
    MONGODB=mongodb-org
    install_docker		                     # needed for bbb-libreoffice-docker
    docker pull openjdk:11-jre-buster      # fix issue 413
    docker tag openjdk:11-jre-buster openjdk:11-jre
    need_pkg ruby

    BBB_WEB_ETC_CONFIG=/etc/bigbluebutton/bbb-web.properties            # Override file for local settings 

    need_pkg openjdk-11-jre java-common
    update-java-alternatives -s java-1.11.0-openjdk-amd64
  fi

  apt-get update
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade

  need_pkg nodejs $MONGODB apt-transport-https haveged
  need_pkg bigbluebutton
  need_pkg bbb-html5

  if [ -f /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties ]; then
    SERVLET_DIR=/usr/share/bbb-web
    TURN_XML=$SERVLET_DIR/WEB-INF/classes/spring/turn-stun-servers.xml
  fi

  while [ ! -f $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties ]; do sleep 1; echo -n '.'; done

  check_lxc
  check_nat
  check_LimitNOFILE

  configure_HTML5 

  if [ -n "$API_DEMOS" ]; then
    need_pkg bbb-demo
    while [ ! -f /var/lib/$TOMCAT_USER/webapps/demo/bbb_api_conf.jsp ]; do sleep 1; echo -n '.'; done
  fi

  if [ -n "$LINK_PATH" ]; then
    ln -s "$LINK_PATH" "/var/bigbluebutton"
  fi

  if [ -n "$PROVIDED_CERTIFICATE" ] ; then
    install_ssl
  elif [ -n "$HOST" ] && [ -n "$EMAIL" ] ; then
    install_ssl
  fi

  if [ -n "$GREENLIGHT" ]; then
    install_greenlight
  fi

  if [ -n "$COTURN" ]; then
    configure_coturn
  fi

  apt-get auto-remove -y

  if systemctl status freeswitch.service | grep -q SETSCHEDULER; then
    sed -i "s/^CPUSchedulingPolicy=rr/#CPUSchedulingPolicy=rr/g" /lib/systemd/system/freeswitch.service
    systemctl daemon-reload
  fi

  systemctl restart systemd-journald

  if [ -n "$UFW" ]; then
    setup_ufw 
  fi

  if [ -n "$HOST" ]; then
    bbb-conf --setip "$HOST"
  else
    bbb-conf --setip "$IP"
  fi

  if ! systemctl show-environment | grep LANG= | grep -q UTF-8; then
    sudo systemctl set-environment LANG=C.UTF-8
  fi

  bbb-conf --check
}

say() {
  echo "bbb-install: $1"
}

err() {
  say "$1" >&2
  exit 1
}

check_root() {
  if [ $EUID != 0 ]; then err "You must run this command as root."; fi
}

check_mem() {
  if awk '$1~/MemTotal/ {exit !($2<3940000)}' /proc/meminfo; then
    err "Your server needs to have (at least) 4G of memory."
  fi
}

check_ubuntu(){
  RELEASE=$(lsb_release -r | sed 's/^[^0-9]*//g')
  if [ "$RELEASE" != "$1" ]; then err "You must run this command on Ubuntu $1 server."; fi
}

need_x64() {
  UNAME=`uname -m`
  if [ "$UNAME" != "x86_64" ]; then err "You must run this command on a 64-bit server."; fi
}

wait_443() {
  echo "Waiting for port 443 to clear "
  # ss fields 4 and 6 are Local Address and State
  while ss -ant | awk '{print $4, $6}' | grep TIME_WAIT | grep -q ":443"; do sleep 1; echo -n '.'; done
  echo
}

get_IP() {
  if [ -n "$IP" ]; then return 0; fi

  # Determine local IP
  if [ -e "/sys/class/net/venet0:0" ]; then
    # IP detection for OpenVZ environment
    _dev="venet0:0"
  else
    _dev=$(awk '$2 == 00000000 { print $1 }' /proc/net/route | head -1)
  fi
  _ips=$(LANG=C ip -4 -br address show dev "$_dev" | awk '{ $1=$2=""; print $0 }')
  _ips=${_ips/127.0.0.1\/8/}
  read -r IP _ <<< "$_ips"
  IP=${IP/\/*} # strip subnet provided by ip address
  if [ -z "$IP" ]; then
    read -r IP _ <<< "$(hostname -I)"
  fi


  # Determine external IP 
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ] && [ "$(head -c 3 /sys/devices/virtual/dmi/id/product_uuid)" == "EC2" ]; then
    # EC2
    local external_ip=$(wget -qO- http://169.254.169.254/latest/meta-data/public-ipv4)
  elif [ -f /var/lib/dhcp/dhclient.eth0.leases ] && grep -q unknown-245 /var/lib/dhcp/dhclient.eth0.leases; then
    # Azure
    local external_ip=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text")
  elif [ -f /run/scw-metadata.cache ]; then
    # Scaleway
    local external_ip=$(grep "PUBLIC_IP_ADDRESS" /run/scw-metadata.cache | cut -d '=' -f 2)
  elif which dmidecode > /dev/null && dmidecode -s bios-vendor | grep -q Google; then
    # Google Compute Cloud
    local external_ip=$(wget -O - -q "http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" --header 'Metadata-Flavor: Google')
  elif [ -n "$1" ]; then
    # Try and determine the external IP from the given hostname
    need_pkg dnsutils
    local external_ip=$(dig +short "$1" @resolver1.opendns.com | grep '^[.0-9]*$' | tail -n1)
  fi

  # Check if the external IP reaches the internal IP
  if [ -n "$external_ip" ] && [ "$IP" != "$external_ip" ]; then
    if which nginx; then
      systemctl stop nginx
    fi

    need_pkg netcat-openbsd

    wait_443

    nc -l -p 443 > /dev/null 2>&1 &
    nc_PID=$!
    sleep 1
    
     # Check if we can reach the server through it's external IP address
     if nc -zvw3 "$external_ip" 443  > /dev/null 2>&1; then
       INTERNAL_IP=$IP
       IP=$external_ip
       echo 
       echo "  Detected this server has an internal/external IP address."
       echo 
       echo "      INTERNAL_IP: $INTERNAL_IP"
       echo "    (external) IP: $IP"
       echo 
     fi

    kill $nc_PID  > /dev/null 2>&1;

    if which nginx; then
      systemctl start nginx
    fi
  fi

  if [ -z "$IP" ]; then err "Unable to determine local IP address."; fi
}

need_pkg() {
  check_root
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo "Sleeping for 1 second because of dpkg lock"; sleep 1; done

  if [ ! "$SOURCES_FETCHED" = true ]; then
    apt-get update
    SOURCES_FETCHED=true
  fi

  if ! dpkg -s ${@:1} >/dev/null 2>&1; then
    LC_CTYPE=C.UTF-8 apt-get install -yq ${@:1}
  fi
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo "Sleeping for 1 second because of dpkg lock"; sleep 1; done
}

need_ppa() {
  need_pkg software-properties-common 
  if [ ! -f "/etc/apt/sources.list.d/$1" ]; then
    LC_CTYPE=C.UTF-8 add-apt-repository -y "$2"
  fi
  if ! apt-key list "$3" | grep -q -E "1024|4096"; then  # Let's try it a second time
    LC_CTYPE=C.UTF-8 add-apt-repository "$2" -y
    if ! apt-key list "$3" | grep -q -E "1024|4096"; then
      err "Unable to setup PPA for $2"
    fi
  fi
}

check_version() {
  if ! echo "$1" | grep -Eq "focal"; then err "This script can only install BigBlueButton 2.5 (or later) and is meant to be run on Ubuntu 20.04 (focal) server."; fi
  DISTRO=$(echo "$1" | sed 's/-.*//g')
  if ! wget -qS --spider "https://$PACKAGE_REPOSITORY/$1/dists/bigbluebutton-$DISTRO/Release.gpg" > /dev/null 2>&1; then
    err "Unable to locate packages for $1 at $PACKAGE_REPOSITORY."
  fi
  check_root
  need_pkg apt-transport-https
  if ! apt-key list | grep -q "BigBlueButton apt-get"; then
    wget "https://$PACKAGE_REPOSITORY/repo/bigbluebutton.asc" -O- | apt-key add -
  fi

  echo "deb https://$PACKAGE_REPOSITORY/$VERSION bigbluebutton-$DISTRO main" > /etc/apt/sources.list.d/bigbluebutton.list
}

check_host() {
  if [ -z "$PROVIDED_CERTIFICATE" ] && [ -z "$HOST" ]; then
    need_pkg dnsutils apt-transport-https
    DIG_IP=$(dig +short "$1" | grep '^[.0-9]*$' | tail -n1)
    if [ -z "$DIG_IP" ]; then err "Unable to resolve $1 to an IP address using DNS lookup.";  fi
    get_IP "$1"
    if [ "$DIG_IP" != "$IP" ]; then err "DNS lookup for $1 resolved to $DIG_IP but didn't match local $IP."; fi
  fi
}

check_coturn() {
  if ! echo "$1" | grep -q ':'; then err "Option for coturn must be <hostname>:<secret>"; fi

  COTURN_HOST=$(echo "$OPTARG" | cut -d':' -f1)
  COTURN_SECRET=$(echo "$OPTARG" | cut -d':' -f2)

  if [ -z "$COTURN_HOST" ];   then err "-c option must contain <hostname>"; fi
  if [ -z "$COTURN_SECRET" ]; then err "-c option must contain <secret>"; fi

  if [ "$COTURN_HOST" == "turn.example.com" ]; then 
    err "You must specify a valid hostname (not the example given in the docs)"
  fi
  if [ "$COTURN_SECRET" == "1234abcd" ]; then 
    err "You must specify a new password (not the example given in the docs)."
  fi

  check_host "$COTURN_HOST"
}

check_apache2() {
  if dpkg -l | grep -q apache2-bin; then err "You must uninstall the Apache2 server first"; fi
}

# If running under LXC, then modify the FreeSWITCH systemctl service so it does not use realtime scheduler
check_lxc() {
  if grep -qa container=lxc /proc/1/environ; then
    if grep IOSchedulingClass /lib/systemd/system/freeswitch.service > /dev/null; then
      cat > /lib/systemd/system/freeswitch.service << HERE
[Unit]
Description=freeswitch
After=syslog.target network.target local-fs.target

[Service]
Type=forking
PIDFile=/opt/freeswitch/var/run/freeswitch/freeswitch.pid
Environment="DAEMON_OPTS=-nonat"
EnvironmentFile=-/etc/default/freeswitch
ExecStart=/opt/freeswitch/bin/freeswitch -u freeswitch -g daemon -ncwait \$DAEMON_OPTS
TimeoutSec=45s
Restart=always
WorkingDirectory=/opt/freeswitch
User=freeswitch
Group=daemon

LimitCORE=infinity
LimitNOFILE=100000
LimitNPROC=60000
LimitSTACK=250000
LimitRTPRIO=infinity
LimitRTTIME=7000000
#IOSchedulingClass=realtime
#IOSchedulingPriority=2
#CPUSchedulingPolicy=rr
#CPUSchedulingPriority=89

[Install]
WantedBy=multi-user.target
HERE

    systemctl daemon-reload
  fi
fi
}

# Check if running externally with internal/external IP addresses
check_nat() {
  xmlstarlet edit --inplace --update '//X-PRE-PROCESS[@cmd="set" and starts-with(@data, "external_rtp_ip=")]/@data' --value "external_rtp_ip=$IP" /opt/freeswitch/conf/vars.xml
  xmlstarlet edit --inplace --update '//X-PRE-PROCESS[@cmd="set" and starts-with(@data, "external_sip_ip=")]/@data' --value "external_sip_ip=$IP" /opt/freeswitch/conf/vars.xml

  if [ -n "$INTERNAL_IP" ]; then
    xmlstarlet edit --inplace --update '//param[@name="ext-rtp-ip"]/@value' --value "\$\${external_rtp_ip}" /opt/freeswitch/conf/sip_profiles/external.xml
    xmlstarlet edit --inplace --update '//param[@name="ext-sip-ip"]/@value' --value "\$\${external_sip_ip}" /opt/freeswitch/conf/sip_profiles/external.xml

    sed -i "s/$INTERNAL_IP:/$IP:/g" /usr/share/bigbluebutton/nginx/sip.nginx
    ip addr add "$IP" dev lo

    # If dummy NIC is not in dummy-nic.service (or the file does not exist), update/create it
    if ! grep -q "$IP" /lib/systemd/system/dummy-nic.service > /dev/null 2>&1; then
      if [ -f /lib/systemd/system/dummy-nic.service ]; then 
        DAEMON_RELOAD=true; 
      fi

      cat > /lib/systemd/system/dummy-nic.service << HERE
[Unit]
Description=Configure dummy NIC for FreeSWITCH
Before=freeswitch.service
After=network.target

[Service]
ExecStart=/sbin/ip addr add $IP dev lo

[Install]
WantedBy=multi-user.target
HERE

      if [ "$DAEMON_RELOAD" == "true" ]; then
        systemctl daemon-reload
        systemctl restart dummy-nic
      else
        systemctl enable dummy-nic
        systemctl start dummy-nic
      fi
    fi
  fi
}

check_LimitNOFILE() {
  CPU=$(nproc --all)

  if [ "$CPU" -ge 8 ]; then
    if [ -f /lib/systemd/system/bbb-web.service ]; then
      # Let's create an override file to increase the number of LimitNOFILE 
      mkdir -p /etc/systemd/system/bbb-web.service.d/
      cat > /etc/systemd/system/bbb-web.service.d/override.conf << HERE
[Service]
LimitNOFILE=8192
HERE
      systemctl daemon-reload
    fi
  fi
}

configure_HTML5() {
  # Use Google's default STUN server
  if [ -n "$INTERNAL_IP" ]; then
   sed -i "s/[;]*externalIPv4=.*/externalIPv4=$IP/g"                   /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
   sed -i "s/[;]*iceTcp=.*/iceTcp=0/g"                                 /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
  fi
}

install_greenlight(){
  install_docker

  # Purge older docker compose
  if dpkg -l | grep -q docker-compose; then
    apt-get purge -y docker-compose
  fi

  if [ ! -x /usr/local/bin/docker-compose ]; then
    curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi

  if [ ! -d ~/greenlight ]; then
    mkdir -p ~/greenlight
  fi

  # This will trigger the download of Greenlight docker image (if needed)
  SECRET_KEY_BASE=$(docker run --rm bigbluebutton/greenlight:v2 bundle exec rake secret)

  if [ ! -f ~/greenlight/.env ]; then
    docker run --rm bigbluebutton/greenlight:v2 cat ./sample.env > ~/greenlight/.env
  fi

  BIGBLUEBUTTON_URL=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties $BBB_WEB_ETC_CONFIG | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}' | tail -n 1 )/bigbluebutton/
  BIGBLUEBUTTON_SECRET=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties $BBB_WEB_ETC_CONFIG | grep -v '#' | grep ^securitySalt | tail -n 1  | cut -d= -f2)
  SAFE_HOSTS=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties $BBB_WEB_ETC_CONFIG | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}' | tail -n 1 | sed 's/https\?:\/\///')

  # Update Greenlight configuration file in ~/greenlight/env
  sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|"                   ~/greenlight/.env
  sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" ~/greenlight/.env
  sed -i "s|.*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTON_SECRET|"  ~/greenlight/.env
  sed -i "s|SAFE_HOSTS=.*|SAFE_HOSTS=$SAFE_HOSTS|"                                  ~/greenlight/.env

  # need_pkg bbb-webhooks

  if [ ! -f /usr/share/bigbluebutton/nginx/greenlight.nginx ]; then
    docker run --rm bigbluebutton/greenlight:v2 cat ./greenlight.nginx | tee /usr/share/bigbluebutton/nginx/greenlight.nginx
    cat > /usr/share/bigbluebutton/nginx/greenlight-redirect.nginx << HERE
location = / {
  return 307 /b;
}
HERE
    systemctl restart nginx
  fi

  if ! gem list | grep -q java_properties; then
    gem install jwt java_properties
  fi

  if [ ! -f ~/greenlight/docker-compose.yml ]; then
    docker run --rm bigbluebutton/greenlight:v2 cat ./docker-compose.yml > ~/greenlight/docker-compose.yml
  fi

  # change the default passwords
  PGPASSWORD=$(openssl rand -base64 24)
  sed -i "s,^\([ \t-]*POSTGRES_PASSWORD\)\(=password\),\1=$PGPASSWORD,g" ~/greenlight/docker-compose.yml
  sed -i "s,^\([ \t]*DB_PASSWORD\)\(=password\),\1=$PGPASSWORD,g" ~/greenlight/.env

  # Remove old containers
  if docker ps | grep -q greenlight_db_1; then
    docker rm -f greenlight_db_1
  fi
  if docker ps | grep -q greenlight-v2; then
    docker rm -f greenlight-v2
  fi

  if ! docker ps | grep -q greenlight; then
    docker-compose -f ~/greenlight/docker-compose.yml up -d
    sleep 5
  fi
}


install_docker() {
  need_pkg apt-transport-https ca-certificates curl gnupg-agent software-properties-common openssl

  # Install Docker
  if ! apt-key list | grep -q Docker; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  fi

  if ! dpkg -l | grep -q docker-ce; then
    add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

    apt-get update
    need_pkg docker-ce docker-ce-cli containerd.io
  fi
  if ! which docker; then err "Docker did not install"; fi

  # Remove Docker Compose
  if dpkg -l | grep -q docker-compose; then
    apt-get purge -y docker-compose
  fi
}


install_ssl() {
  if ! grep -q "$HOST" /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml; then
    bbb-conf --setip "$HOST"
  fi

  mkdir -p /etc/nginx/ssl

  if [ -z "$PROVIDED_CERTIFICATE" ]; then
    add-apt-repository universe
    apt-get update
    need_pkg certbot
  fi

  if [ ! -f /etc/nginx/ssl/dhp-4096.pem ]; then
    openssl dhparam -dsaparam  -out /etc/nginx/ssl/dhp-4096.pem 4096
  fi

  if [ ! -f "/etc/letsencrypt/live/$HOST/fullchain.pem" ]; then
    rm -f /tmp/bigbluebutton.bak
    if ! grep -q "$HOST" /etc/nginx/sites-available/bigbluebutton; then  # make sure we can do the challenge
      if [ -f /etc/nginx/sites-available/bigbluebutton ]; then
        cp /etc/nginx/sites-available/bigbluebutton /tmp/bigbluebutton.bak
      fi
      cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server_tokens off;
server {
  listen 80;
  listen [::]:80;
  server_name $HOST;

  access_log  /var/log/nginx/bigbluebutton.access.log;

  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default;
    index  index.html index.htm;
    expires 1m;
  }
}
HERE
      systemctl restart nginx
    fi

    if [ -z "$PROVIDED_CERTIFICATE" ]; then
      if ! certbot --email "$EMAIL" --agree-tos --rsa-key-size 4096 -w /var/www/bigbluebutton-default/ \
           -d "$HOST" --deploy-hook "systemctl reload nginx" $LETS_ENCRYPT_OPTIONS certonly; then
        systemctl restart nginx
        err "Let's Encrypt SSL request for $HOST did not succeed - exiting"
      fi
    else
      # Place your fullchain.pem and privkey.pem files in /local/certs/ and bbb-install-2.5.sh will deal with the rest.
      mkdir -p "/etc/letsencrypt/live/$HOST/"
      ln -s /local/certs/fullchain.pem "/etc/letsencrypt/live/$HOST/fullchain.pem"
      ln -s /local/certs/privkey.pem "/etc/letsencrypt/live/$HOST/privkey.pem"
    fi
  fi

  cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server_tokens off;

server {
  listen 80;
  listen [::]:80;
  server_name $HOST;
  
  return 301 https://\$server_name\$request_uri; #redirect HTTP to HTTPS

}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name $HOST;

    ssl_certificate /etc/letsencrypt/live/$HOST/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOST/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_dhparam /etc/nginx/ssl/dhp-4096.pem;
    
    # HSTS (comment out to enable)
    #add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

  access_log  /var/log/nginx/bigbluebutton.access.log;

  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default;
    index  index.html index.htm;
    expires 1m;
  }

  # Include specific rules for record and playback
  include /usr/share/bigbluebutton/nginx/*.nginx;
  include /etc/bigbluebutton/nginx/*.nginx; # possible overrides
}
HERE

  # Configure rest of BigBlueButton Configuration for SSL
  xmlstarlet edit --inplace --update '//param[@name="wss-binding"]/@value' --value "$IP:7443" /opt/freeswitch/conf/sip_profiles/external.xml
 
  source /etc/bigbluebutton/bigbluebutton-release
  if [ -n "$(echo "$BIGBLUEBUTTON_RELEASE" | grep '2.2')" ] && [ "$(echo "$BIGBLUEBUTTON_RELEASE" | cut -d\. -f3)" -lt 29 ]; then
    sed -i "s/proxy_pass .*/proxy_pass https:\/\/$IP:7443;/g" /usr/share/bigbluebutton/nginx/sip.nginx
  else
    # Use nginx as proxy for WSS -> WS (see https://github.com/bigbluebutton/bigbluebutton/issues/9667)
    yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.media.sipjsHackViaWs true
    sed -i "s/proxy_pass .*/proxy_pass http:\/\/$IP:5066;/g" /usr/share/bigbluebutton/nginx/sip.nginx
    xmlstarlet edit --inplace --update '//param[@name="ws-binding"]/@value' --value "$IP:5066" /opt/freeswitch/conf/sip_profiles/external.xml
  fi

  sed -i 's/^bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties
  if [ -f $BBB_WEB_ETC_CONFIG ]; then
    sed -i 's/^bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' $BBB_WEB_ETC_CONFIG
  fi

  yq w -i /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml playback_protocol https
  chmod 644 /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml 

  if [ -f /var/lib/$TOMCAT_USER/webapps/demo/bbb_api_conf.jsp ]; then
    sed -i 's/String BigBlueButtonURL = "http:/String BigBlueButtonURL = "https:/g' /var/lib/$TOMCAT_USER/webapps/demo/bbb_api_conf.jsp
  fi

  if [ -f /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml ]; then
    yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.note.url "https://$HOST/pad"
  fi

  # Update Greenlight (if installed) to use SSL
  if [ -f ~/greenlight/.env ]; then
    if ! grep ^BIGBLUEBUTTON_ENDPOINT ~/greenlight/.env | grep -q https; then
      BIGBLUEBUTTON_URL=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties $BBB_WEB_ETC_CONFIG | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}' | tail -n 1 )/bigbluebutton/
      sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" ~/greenlight/.env
      docker-compose -f ~/greenlight/docker-compose.yml down
      docker-compose -f ~/greenlight/docker-compose.yml up -d
    fi
  fi

  TARGET=/usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml
  if [ -f $TARGET ]; then
    if grep -q kurentoIp $TARGET; then
      # 2.0
      yq w -i $TARGET kurentoIp "$IP"
    else
      # 2.2
      yq w -i $TARGET kurento[0].ip "$IP"
      yq w -i $TARGET freeswitch.ip "$IP"

      if [ -n "$(echo "$BIGBLUEBUTTON_RELEASE" | grep '2.2')" ] && [ "$(echo "$BIGBLUEBUTTON_RELEASE" | cut -d\. -f3)" -lt 29 ]; then
        if [ -n "$INTERNAL_IP" ]; then
          yq w -i $TARGET freeswitch.sip_ip "$INTERNAL_IP"
        else
          yq w -i $TARGET freeswitch.sip_ip "$IP"
        fi
      else
        # Use nginx as proxy for WSS -> WS (see https://github.com/bigbluebutton/bigbluebutton/issues/9667)
        yq w -i $TARGET freeswitch.sip_ip "$IP"
      fi
    fi
    chown bigbluebutton:bigbluebutton $TARGET
    chmod 644 $TARGET
  fi

  mkdir -p /etc/bigbluebutton/bbb-webrtc-sfu
  TARGET=/etc/bigbluebutton/bbb-webrtc-sfu/production.yml
  touch $TARGET

  # Configure mediasoup IPs, reference: https://raw.githubusercontent.com/bigbluebutton/bbb-webrtc-sfu/v2.7.2/docs/mediasoup.md
  # mediasoup IPs: WebRTC
  yq w -i "$TARGET" mediasoup.webrtc.listenIps[0].ip "0.0.0.0"
  yq w -i "$TARGET" mediasoup.webrtc.listenIps[0].announcedIp "$IP"

  # mediasoup IPs: plain RTP (internal comms, FS <-> mediasoup)
  yq w -i "$TARGET" mediasoup.plainRtp.listenIp.ip "0.0.0.0"
  yq w -i "$TARGET" mediasoup.plainRtp.listenIp.announcedIp "$IP"
}

configure_coturn() {
  cat <<HERE > $TURN_XML
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.springframework.org/schema/beans
        http://www.springframework.org/schema/beans/spring-beans-2.5.xsd">

    <bean id="stun0" class="org.bigbluebutton.web.services.turn.StunServer">
        <constructor-arg index="0" value="stun:$COTURN_HOST"/>
    </bean>


    <bean id="turn0" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="$COTURN_SECRET"/>
        <constructor-arg index="1" value="turns:$COTURN_HOST:443?transport=tcp"/>
        <constructor-arg index="2" value="86400"/>
    </bean>
    
    <bean id="turn1" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="$COTURN_SECRET"/>
        <constructor-arg index="1" value="turn:$COTURN_HOST:443?transport=tcp"/>
        <constructor-arg index="2" value="86400"/>
    </bean>

    <bean id="stunTurnService"
            class="org.bigbluebutton.web.services.turn.StunTurnService">
        <property name="stunServers">
            <set>
                <ref bean="stun0"/>
            </set>
        </property>
        <property name="turnServers">
            <set>
                <ref bean="turn0"/>
                <ref bean="turn1"/>
            </set>
        </property>
    </bean>
</beans>
HERE
}


install_coturn() {
  apt-get update
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade

  need_pkg software-properties-common

  if ! certbot certonly --standalone --non-interactive --preferred-challenges http \
         -d "$COTURN_HOST" --email "$EMAIL" --agree-tos -n ; then
     err "Let's Encrypt SSL request for $COTURN_HOST did not succeed - exiting"
  fi

  need_pkg coturn

  if [ -n "$INTERNAL_IP" ]; then
    EXTERNAL_IP="external-ip=$IP/$INTERNAL_IP"
  fi

  cat <<HERE > /etc/turnserver.conf
listening-port=3478
tls-listening-port=443

listening-ip=$IP
relay-ip=$IP
$EXTERNAL_IP

min-port=32769
max-port=65535
verbose

fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=$COTURN_SECRET
realm=$(echo "$COTURN_HOST" | cut -d'.' -f2-)

cert=/etc/turnserver/fullchain.pem
pkey=/etc/turnserver/privkey.pem
# From https://ssl-config.mozilla.org/ Intermediate, openssl 1.1.0g, 2020-01
cipher-list="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"
dh-file=/etc/turnserver/dhp.pem

keep-address-family

no-cli
no-tlsv1
no-tlsv1_1
HERE

  mkdir -p /etc/turnserver
  if [ ! -f /etc/turnserver/dhp.pem ]; then
    openssl dhparam -dsaparam  -out /etc/turnserver/dhp.pem 2048
  fi

  mkdir -p /var/log/turnserver
  chown turnserver:turnserver /var/log/turnserver

  cat <<HERE > /etc/logrotate.d/coturn
/var/log/turnserver/*.log
{
	rotate 7
	daily
	missingok
	notifempty
	compress
	postrotate
		/bin/systemctl kill -s HUP coturn.service
	endscript
}
HERE

  # Eanble coturn to bind to port 443 with CAP_NET_BIND_SERVICE
  mkdir -p /etc/systemd/system/coturn.service.d
  rm -rf /etc/systemd/system/coturn.service.d/ansible.conf      # Remove previous file 
  cat > /etc/systemd/system/coturn.service.d/override.conf <<HERE
[Service]
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=
ExecStart=/usr/bin/turnserver --daemon -c /etc/turnserver.conf --pidfile /run/turnserver/turnserver.pid --no-stdout-log --simple-log --log-file /var/log/turnserver/turnserver.log
Restart=always
HERE

  # Since coturn runs as user turnserver, copy certs so they can be read
  mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat > /etc/letsencrypt/renewal-hooks/deploy/coturn <<HERE
#!/bin/bash -e

for certfile in fullchain.pem privkey.pem ; do
	cp -L /etc/letsencrypt/live/$COTURN_HOST/"\${certfile}" /etc/turnserver/"\${certfile}".new
	chown turnserver:turnserver /etc/turnserver/"\${certfile}".new
	mv /etc/turnserver/"\${certfile}".new /etc/turnserver/"\${certfile}"
done

systemctl kill -sUSR2 coturn.service
HERE
  chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/coturn
  /etc/letsencrypt/renewal-hooks/deploy/coturn

  systemctl daemon-reload
  systemctl stop coturn
  wait_443
  systemctl start coturn
}


setup_ufw() {
  if [ ! -f /etc/bigbluebutton/bbb-conf/apply-config.sh ]; then
    cat > /etc/bigbluebutton/bbb-conf/apply-config.sh << HERE
#!/bin/bash

# Pull in the helper functions for configuring BigBlueButton
source /etc/bigbluebutton/bbb-conf/apply-lib.sh

enableUFWRules
HERE
  chmod +x /etc/bigbluebutton/bbb-conf/apply-config.sh
  fi
}

main "$@" || exit 1

