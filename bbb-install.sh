#!/bin/bash -ex

# Copyright (c) 2018 BigBlueButton Inc.
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

# BigBlueButton is an open source conferencing system.  For more information see
#    http://www.bigbluebutton.org/.
#
# This bbb-install.sh script automates many of the installation and configuration
# steps at
#    http://docs.bigbluebutton.org/install/install.html
#
#
#  Examples
#
#  Install BigBlueButton and configure using server's external IP address
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220
#
#
#  Install BigBlueButton and configure using hostname bbb.example.com
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220 -s bbb.example.com
#
#
#  Install BigBlueButton with a SSL certificate from Let's Encrypt using e-mail info@example.com:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220 -s bbb.example.com -e info@example.com
#
#
#  Install BigBlueButton with SSL + Greenlight
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220 -s bbb.example.com -e info@example.com -g
#

usage() {
    set +x
    cat 1>&2 <<HERE

Script for installing a BigBlueButton 2.2 (or later) server in about 15 minutes.

This script also supports installation of a coturn (TURN) server on a separate server.

USAGE:
    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- [OPTIONS]

OPTIONS (install BigBlueButton):

  -v <version>           Install given version of BigBlueButton (e.g. 'xenial-220') (required)

  -s <hostname>          Configure server with <hostname>
  -e <email>             Email for Let's Encrypt certbot
  -x                     Use Let's Encrypt certbot with manual dns challenges
  -a                     Install BBB API demos
  -g                     Install Greenlight
  -c <hostname>:<secret> Configure with coturn server at <hostname> using <secret>

  -m <link_path>         Create a Symbolic link from /var/bigbluebutton to <link_path> 

  -p <host>              Use apt-get proxy at <host>
  -r <host>              Use alternative apt repository (such as packages-eu.bigbluebutton.org)

  -d                     Skip SSL certificates request (use provided certificates from mounted volume)

  -h                     Print help

OPTIONS (install coturn only):

  -c <hostname>:<secret> Setup a coturn server with <hostname> and <secret> (required)
  -e <email>             Configure email for Let's Encrypt certbot (required)

OPTIONS (install Let's Encrypt certificate only):

  -s <hostname>          Configure server with <hostname> (required)
  -e <email>             Configure email for Let's Encrypt certbot (required)
  -l                     Install Let's Encrypt certificate (required)
  -x                     Use Let's Encrypt certbot with manual dns challenges (optional)


EXAMPLES:

Sample options for setup a BigBlueButton server

    -v xenial-220
    -v xenial-220 -s bbb.example.com -e info@example.com
    -v xenial-220 -s bbb.example.com -e info@example.com -g
    -v xenial-220 -s bbb.example.com -e info@example.com -g -c turn.example.com:1234324

Sample options for setup of a coturn server (on a different server)

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

  need_x64

  while builtin getopts "hs:r:c:v:e:p:m:lxgtad" opt "${@}"; do

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
        check_host $HOST
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
        check_coturn $COTURN
        ;;
      v)
        VERSION=$OPTARG
        check_version $VERSION
        ;;

      p)
        PROXY=$OPTARG
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

  check_apache2

  if [ ! -z "$PROXY" ]; then
    echo "Acquire::http::Proxy \"http://$PROXY:3142\";"  > /etc/apt/apt.conf.d/01proxy
  fi

  # Check if we're installing coturn (need an e-mail address for Let's Encrypt)
  if [ -z "$VERSION" ] && [ ! -z "$LETS_ENCRYPT_ONLY" ]; then
    if [ -z "$EMAIL" ]; then err "Installing certificate needs an e-mail address for Let's Encrypt"; fi
    check_ubuntu 18.04

    install_certificate
    exit 0
  fi

  # Check if we're installing coturn (need an e-mail address for Let's Encrypt)
  if [ -z "$VERSION" ] && [ ! -z "$COTURN" ]; then
    if [ -z "$EMAIL" ]; then err "Installing coturn needs an e-mail address for Let's Encrypt"; fi
    check_ubuntu 18.04

    install_coturn
    exit 0
  fi

  if [ -z "$VERSION" ]; then
    usage
    exit 0
  fi

  # We're installing BigBlueButton
  env
  if [ "$DISTRO" == "xenial" ]; then 
    check_ubuntu 16.04
    TOMCAT_USER=tomcat7
  fi
  if [ "$DISTRO" == "bionic" ]; then 
    check_ubuntu 18.04
    TOMCAT_USER=tomcat8
  fi
  check_mem

  get_IP

  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

  need_pkg curl

  if [ "$DISTRO" == "xenial" ]; then 
    rm -rf /etc/apt/sources.list.d/jonathonf-ubuntu-ffmpeg-4-xenial.list 
    need_ppa bigbluebutton-ubuntu-support-xenial.list ppa:bigbluebutton/support E95B94BC # Latest version of ffmpeg
    need_ppa rmescandon-ubuntu-yq-xenial.list ppa:rmescandon/yq                 CC86BB64 # Edit yaml files with yq
    apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install grub-pc update-notifier-common

    # Remove default version of nodejs for Ubuntu 16.04 if installed
    if dpkg -s nodejs | grep Version | grep -q 4.2.6; then
      apt-get purge -y nodejs > /dev/null 2>&1
    fi
    apt-get purge -yq kms-core-6.0 kms-elements-6.0 kurento-media-server-6.0 > /dev/null 2>&1  # Remove older packages

    if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
      curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    fi
    if ! apt-cache madison nodejs | grep -q node_8; then
      err "Did not detect nodejs 8.x candidate for installation"
    fi

    if ! apt-key list A15703C6 | grep -q A15703C6; then
      wget -qO - https://www.mongodb.org/static/pgp/server-3.4.asc | sudo apt-key add -
    fi
    if apt-key list A15703C6 | grep -q expired; then 
      wget -qO - https://www.mongodb.org/static/pgp/server-3.4.asc | sudo apt-key add -
    fi
    rm -rf /etc/apt/sources.list.d/mongodb-org-4.0.list
    echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
    MONGODB=mongodb-org
    need_pkg openjdk-8-jre
  fi

  if [ "$DISTRO" == "bionic" ]; then
    need_ppa rmescandon-ubuntu-yq-bionic.list         ppa:rmescandon/yq          CC86BB64 # Edit yaml files with yq
    need_ppa libreoffice-ubuntu-ppa-bionic.list       ppa:libreoffice/ppa        1378B444 # Latest version of libreoffice
    need_ppa bigbluebutton-ubuntu-support-bionic.list ppa:bigbluebutton/support  E95B94BC # Latest version of ffmpeg
    if ! apt-key list 5AFA7A83 | grep -q -E "1024|4096"; then   # Add Kurento package
      sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5AFA7A83
      sudo tee "/etc/apt/sources.list.d/kurento.list" >/dev/null <<HERE
# Kurento Media Server - Release packages
deb [arch=amd64] http://ubuntu.openvidu.io/6.13.0 $DISTRO kms6
HERE
    fi

    if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
      curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
    fi
    if ! apt-cache madison nodejs | grep -q node_12; then
      err "Did not detect nodejs 12.x candidate for installation"
    fi
    if ! apt-key list | grep -q MongoDB; then
      wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | sudo apt-key add -
    fi
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
    MONGODB=mongodb-org
  fi

  apt-get update
  apt-get dist-upgrade -yq

  need_pkg nodejs $MONGODB apt-transport-https haveged build-essential yq # default-jre
  need_pkg bigbluebutton
  need_pkg bbb-html5

  if [ -f /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties ]; then
    # 2.2
    SERVLET_DIR=/usr/share/bbb-web
    TURN_XML=$SERVLET_DIR/WEB-INF/classes/spring/turn-stun-servers.xml
  else
    # 2.0
    SERVLET_DIR=/var/lib/tomcat7/webapps/bigbluebutton
    TURN_XML=$SERVLET_DIR/WEB-INF/spring/turn-stun-servers.xml
  fi

  while [ ! -f $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties ]; do sleep 1; echo -n '.'; done

  check_lxc
  check_nat
  check_LimitNOFILE

  configure_HTML5 

  if [ ! -z "$API_DEMOS" ]; then
    need_pkg bbb-demo
    while [ ! -f /var/lib/$TOMCAT_USER/webapps/demo/bbb_api_conf.jsp ]; do sleep 1; echo -n '.'; done
  fi

  if [ ! -z "$LINK_PATH" ]; then
    ln -s "$LINK_PATH" "/var/bigbluebutton"
  fi

  if [ ! -z "$PROVIDED_CERTIFICATE" ] ; then
    install_ssl
  elif [ ! -z "$HOST" ] && [ ! -z "$EMAIL" ] ; then
    install_ssl
  fi

  if [ ! -z "$GREENLIGHT" ]; then
    install_greenlight
  fi

  if [ ! -z "$COTURN" ]; then
    configure_coturn
  fi

  apt-get auto-remove -y

  if systemctl status freeswitch.service | grep -q SETSCHEDULER; then
    sed -i "s/^CPUSchedulingPolicy=rr/#CPUSchedulingPolicy=rr/g" /lib/systemd/system/freeswitch.service
    systemctl daemon-reload
  fi

  if [ ! -z "$HOST" ]; then
    bbb-conf --setip $HOST
  else
    bbb-conf --setip $IP
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
  MEM=`grep MemTotal /proc/meminfo | awk '{print $2}'`
  MEM=$((MEM/1000))
  if (( $MEM < 3940 )); then err "Your server needs to have (at least) 4G of memory."; fi
}

check_ubuntu(){
  RELEASE=$(lsb_release -r | sed 's/^[^0-9]*//g')
  if [ "$RELEASE" != $1 ]; then err "You must run this command on Ubuntu $1 server."; fi
}

need_x64() {
  UNAME=`uname -m`
  if [ "$UNAME" != "x86_64" ]; then err "You must run this command on a 64-bit server."; fi
}

get_IP() {
  if [ ! -z "$IP" ]; then return 0; fi

  # Determine local IP
  if LANG=c ifconfig | grep -q 'venet0:0'; then
    IP=$(ifconfig | grep -v '127.0.0.1' | grep -E "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | tail -1 | cut -d: -f2 | awk '{ print $1}')
  else
    IP=$(hostname -I | cut -f1 -d' ')
  fi

  # Determine external IP 
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ] && [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
    # Ec2
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
  elif [ ! -z "$1" ]; then
    # Try and determine the external IP from the given hostname
    need_pkg dnsutils
    local external_ip=$(dig +short $1 @resolver1.opendns.com | grep '^[.0-9]*$' | tail -n1)
  fi

  # Check if the external IP reaches the internal IP
  if [ ! -z "$external_ip" ] && [ "$IP" != "$external_ip" ]; then
    if which nginx; then
      systemctl stop nginx
    fi

    need_pkg netcat-openbsd
    nc -l -p 443 > /dev/null 2>&1 &
    nc_PID=$!
    
     # Check if we can reach the server through it's external IP address
     if nc -zvw3 $external_ip 443  > /dev/null 2>&1; then
       INTERNAL_IP=$IP
       IP=$external_ip
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

  if ! dpkg -s ${@:1} >/dev/null 2>&1; then
    LC_CTYPE=C.UTF-8 apt-get install -yq ${@:1}
  fi
}

need_ppa() {
  need_pkg software-properties-common 
  if [ ! -f /etc/apt/sources.list.d/$1 ]; then
    LC_CTYPE=C.UTF-8 add-apt-repository -y $2 
  fi
  if ! apt-key list $3 | grep -q -E "1024|4096"; then  # Let's try it a second time
    LC_CTYPE=C.UTF-8 add-apt-repository $2 -y
    if ! apt-key list $3 | grep -q -E "1024|4096"; then
      err "Unable to setup PPA for $2"
    fi
  fi
}

check_version() {
  if ! echo $1 | egrep -q "xenial|bionic"; then err "This script can only install BigBlueButton 2.0 (or later)"; fi
  DISTRO=$(echo $1 | sed 's/-.*//g')
  if ! wget -qS --spider "https://$PACKAGE_REPOSITORY/$1/dists/bigbluebutton-$DISTRO/Release.gpg" > /dev/null 2>&1; then
    err "Unable to locate packages for $1 at $PACKAGE_REPOSITORY."
  fi
  check_root
  need_pkg apt-transport-https
  if ! apt-key list | grep -q "BigBlueButton apt-get"; then
    wget https://$PACKAGE_REPOSITORY/repo/bigbluebutton.asc -O- | apt-key add -
  fi

  # Check if were upgrading from 2.0 (the ownership of /etc/bigbluebutton/nginx/web has changed from bbb-client to bbb-web)
  if [ -f /etc/apt/sources.list.d/bigbluebutton.list ]; then
    if grep -q xenial-200 /etc/apt/sources.list.d/bigbluebutton.list; then
      if echo $VERSION | grep -q xenial-220; then
        if dpkg -l | grep -q bbb-client; then
          apt-get purge -y bbb-client
        fi
      fi
    fi
  fi

  echo "deb https://$PACKAGE_REPOSITORY/$VERSION bigbluebutton-$DISTRO main" > /etc/apt/sources.list.d/bigbluebutton.list
}

check_host() {
  if [ -z "$PROVIDED_CERTIFICATE" ]; then
    need_pkg dnsutils apt-transport-https net-tools
    DIG_IP=$(dig +short $1 | grep '^[.0-9]*$' | tail -n1)
    if [ -z "$DIG_IP" ]; then err "Unable to resolve $1 to an IP address using DNS lookup.";  fi
    get_IP $1
    if [ "$DIG_IP" != "$IP" ]; then err "DNS lookup for $1 resolved to $DIG_IP but didn't match local $IP."; fi
  fi
}

check_coturn() {
  if ! echo $1 | grep -q ':'; then err "Option for coturn must be <hostname>:<secret>"; fi

  COTURN_HOST=$(echo $OPTARG | cut -d':' -f1)
  COTURN_SECRET=$(echo $OPTARG | cut -d':' -f2)

  if [ -z "$COTURN_HOST" ];   then err "-c option must contain <hostname>"; fi
  if [ -z "$COTURN_SECRET" ]; then err "-c option must contain <secret>"; fi

  if [ "$COTURN_HOST" == "turn.example.com" ]; then 
    err "You must specify a valid hostname (not the example given in the docs)"
  fi
  if [ "$COTURN_SECRET" == "1234abcd" ]; then 
    err "You must specify a new password (not the example given in the docs)."
  fi
}

check_apache2() {
  if dpkg -l | grep -q apache2-bin; then err "You must unisntall the Apache2 server first"; fi
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
  if [ ! -z "$INTERNAL_IP" ]; then
    sed -i "s/stun:stun.freeswitch.org/$IP/g" /opt/freeswitch/etc/freeswitch/vars.xml
    sed -i "s/ext-rtp-ip\" value=\"\$\${local_ip_v4/ext-rtp-ip\" value=\"\$\${external_rtp_ip/g" /opt/freeswitch/conf/sip_profiles/external.xml
    sed -i "s/ext-sip-ip\" value=\"\$\${local_ip_v4/ext-sip-ip\" value=\"\$\${external_sip_ip/g" /opt/freeswitch/conf/sip_profiles/external.xml
    sed -i "s/$INTERNAL_IP:/$IP:/g" /etc/bigbluebutton/nginx/sip.nginx
    ip addr add $IP dev lo

    # If dummy NIC is not in dummy-nic.service (or the file does not exist), update/create it
    if ! grep -q $IP /lib/systemd/system/dummy-nic.service > /dev/null 2>&1; then
      if [ -f /lib/systemd/system/dummy-nic.service ]; then 
        DAEMON_RELOAD=true; 
      fi

      cat > /lib/systemd/system/dummy-nic.service << HERE
[Unit]
Description=Configure dummy NIC for FreeSWITCH
After=network.target

[Service]
ExecStart=/sbin/ip addr add $IP dev lo

[Install]
WantedBy=multi-user.target
HERE

      if [ "$DAEMON_RELOAD" == "true" ]; then
        systemctl dameon-reload
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

  if [ "$CPU" -gt 36 ]; then
    if [ -f /lib/systemd/system/bbb-web.service ]; then
      # Let's create an override file to increase the number of LimitNOFILE 
      mkdir -p /etc/systemd/system/bbb-web.service.d/
      cat > /etc/systemd/system/bbb-web.service.d/override.conf << HERE
[Service]
LimitNOFILE=
LimitNOFILE=8192
HERE
      systemctl daemon-reload
    fi
  fi
}

configure_HTML5() {
  # Use Google's default STUN server
  if [ ! -z "$INTERNAL_IP" ]; then
   sed -i 's/;stunServerAddress.*/stunServerAddress=64.233.177.127/g' /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
   sed -i 's/;stunServerPort.*/stunServerPort=19302/g'                /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
  fi

  if [ -f /var/www/bigbluebutton/client/conf/config.xml ]; then
    sed -i 's/offerWebRTC="false"/offerWebRTC="true"/g' /var/www/bigbluebutton/client/conf/config.xml
  fi

  # Make the HTML5 client default
  sed -i 's/^attendeesJoinViaHTML5Client=.*/attendeesJoinViaHTML5Client=true/'   $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties
  sed -i 's/^moderatorsJoinViaHTML5Client=.*/moderatorsJoinViaHTML5Client=true/' $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties

  sed -n 's/swfSlidesRequired=true/swfSlidesRequired=false/g'                    $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties
}

install_greenlight(){
  need_pkg software-properties-common openssl

  if ! dpkg -l | grep -q linux-image-extra-virtual; then
    apt-get install -y \
      linux-image-extra-$(uname -r) \
      linux-image-extra-virtual
  fi

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
    need_pkg docker-ce
  fi
  if ! which docker; then err "Docker did not install"; fi

  # Install Docker Compose
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

  BIGBLUEBUTTON_URL=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
  BIGBLUEBUTTON_SECRET=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties   | grep -v '#' | grep securitySalt | cut -d= -f2)

  # Update Greenlight configuration file in ~/greenlight/env
  sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|"                   ~/greenlight/.env
  sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" ~/greenlight/.env
  sed -i "s|.*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTON_SECRET|"  ~/greenlight/.env

  # need_pkg bbb-webhooks

  if [ ! -f /etc/bigbluebutton/nginx/greenlight.nginx ]; then
    docker run --rm bigbluebutton/greenlight:v2 cat ./greenlight.nginx | tee /etc/bigbluebutton/nginx/greenlight.nginx
    cat > /etc/bigbluebutton/nginx/greenlight-redirect.nginx << HERE
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
  PGPASSWORD=$(openssl rand -hex 8)
  sed -i "s/POSTGRES_PASSWORD=password/POSTGRES_PASSWORD=$PGPASSWORD/g" ~/greenlight/docker-compose.yml
  sed -i "s/DB_PASSWORD=password/DB_PASSWORD=$PGPASSWORD/g" ~/greenlight/.env

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


install_ssl() {
  if [ -f /var/www/bigbluebutton/client/conf/config.xml ]; then
    sed -i 's/tryWebRTCFirst="false"/tryWebRTCFirst="true"/g' /var/www/bigbluebutton/client/conf/config.xml
  fi

  if ! grep -q $HOST /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml; then
    bbb-conf --setip $HOST
  fi

  mkdir -p /etc/nginx/ssl

  if [ -z "$PROVIDED_CERTIFICATE" ]; then
    add-apt-repository universe
    need_ppa certbot-ubuntu-certbot-xenial.list ppa:certbot/certbot 75BCA694
    apt-get update
    need_pkg certbot
  fi

  if [ ! -f /etc/nginx/ssl/dhp-4096.pem ]; then
    openssl dhparam -dsaparam  -out /etc/nginx/ssl/dhp-4096.pem 4096
  fi

  if [ ! -f /etc/letsencrypt/live/$HOST/fullchain.pem ]; then
    rm -f /tmp/bigbluebutton.bak
    if ! grep -q $HOST /etc/nginx/sites-available/bigbluebutton; then  # make sure we can do the challenge
      cp /etc/nginx/sites-available/bigbluebutton /tmp/bigbluebutton.bak
      cat <<HERE > /etc/nginx/sites-available/bigbluebutton
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

  # Redirect server error pages to the static page /50x.html
  #
  error_page   500 502 503 504  /50x.html;
  location = /50x.html {
    root   /var/www/nginx-default;
  }
}
HERE
      systemctl restart nginx
    fi

    if [ -z "$PROVIDED_CERTIFICATE" ]; then
      if ! certbot --email $EMAIL --agree-tos --rsa-key-size 4096 -w /var/www/bigbluebutton-default/ \
           -d $HOST --deploy-hook "systemctl restart nginx" $LETS_ENCRYPT_OPTIONS certonly; then
        cp /tmp/bigbluebutton.bak /etc/nginx/sites-available/bigbluebutton
        systemctl restart nginx
        err "Let's Encrypt SSL request for $HOST did not succeed - exiting"
      fi
    else
      mkdir -p /etc/letsencrypt/live/$HOST/
      ln -s /local/certs/fullchain.pem /etc/letsencrypt/live/$HOST/fullchain.pem
      ln -s /local/certs/privkey.pem /etc/letsencrypt/live/$HOST/privkey.pem
    fi
  fi

  cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server {
  listen 80;
  listen [::]:80;
  server_name $HOST;

  listen 443 ssl;
  listen [::]:443 ssl;

    ssl_certificate /etc/letsencrypt/live/$HOST/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOST/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers "ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS:!AES256";
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/nginx/ssl/dhp-4096.pem;

  access_log  /var/log/nginx/bigbluebutton.access.log;

   # Handle RTMPT (RTMP Tunneling).  Forwards requests
   # to Red5 on port 5080
  location ~ (/open/|/close/|/idle/|/send/|/fcs/) {
    proxy_pass         http://127.0.0.1:5080;
    proxy_redirect     off;
    proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;

    client_max_body_size       10m;
    client_body_buffer_size    128k;

    proxy_connect_timeout      90;
    proxy_send_timeout         90;
    proxy_read_timeout         90;

    proxy_buffering            off;
    keepalive_requests         1000000000;
  }

  # Handle desktop sharing tunneling.  Forwards
  # requests to Red5 on port 5080.
  location /deskshare {
     proxy_pass         http://127.0.0.1:5080;
     proxy_redirect     default;
     proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
     client_max_body_size       10m;
     client_body_buffer_size    128k;
     proxy_connect_timeout      90;
     proxy_send_timeout         90;
     proxy_read_timeout         90;
     proxy_buffer_size          4k;
     proxy_buffers              4 32k;
     proxy_busy_buffers_size    64k;
     proxy_temp_file_write_size 64k;
     include    fastcgi_params;
  }

  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default;
    index  index.html index.htm;
    expires 1m;
  }

  # Include specific rules for record and playback
  include /etc/bigbluebutton/nginx/*.nginx;

  #error_page  404  /404.html;

  # Redirect server error pages to the static page /50x.html
  #
  error_page   500 502 503 504  /50x.html;
  location = /50x.html {
    root   /var/www/nginx-default;
  }
}
HERE

  # Configure rest of BigBlueButton Configuration for SSL
  sed -i "s/<param name=\"wss-binding\"  value=\"[^\"]*\"\/>/<param name=\"wss-binding\"  value=\"$IP:7443\"\/>/g" /opt/freeswitch/conf/sip_profiles/external.xml

  sed -i 's/http:/https:/g' /etc/bigbluebutton/nginx/sip.nginx
  sed -i 's/5066/7443/g'    /etc/bigbluebutton/nginx/sip.nginx

  sed -i 's/bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties

  if [ -f /var/www/bigbluebutton/client/conf/config.xml ]; then
    sed -i 's|http://|https://|g' /var/www/bigbluebutton/client/conf/config.xml
    sed -i 's/jnlpUrl=http/jnlpUrl=https/g'   /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties
    sed -i 's/jnlpFile=http/jnlpFile=https/g' /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties
  fi

  yq w -i /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml playback_protocol https
  chmod 644 /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml 

  if [ -f /var/lib/$TOMCAT_USER/webapps/demo/bbb_api_conf.jsp ]; then
    sed -i 's/String BigBlueButtonURL = "http:/String BigBlueButtonURL = "https:/g' /var/lib/$TOMCAT_USER/webapps/demo/bbb_api_conf.jsp
  fi

  if [ -f /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml ]; then
    yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.note.url https://$HOST/pad
  fi

  # Update Greenlight (if installed) to use SSL
  if [ -f ~/greenlight/.env ]; then
    BIGBLUEBUTTON_URL=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
    sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" ~/greenlight/.env
    docker-compose -f ~/greenlight/docker-compose.yml down
    docker-compose -f ~/greenlight/docker-compose.yml up -d
  fi

  # Update HTML5 client (if installed) to use SSL
  if [ -f  /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json ]; then
    sed -i "s|\"wsUrl.*|\"wsUrl\": \"wss://$HOST/bbb-webrtc-sfu\",|g" \
      /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json
  fi

  TARGET=/usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml
  if [ -f $TARGET ]; then
    if grep -q kurentoIp $TARGET; then
      # 2.0
      yq w -i $TARGET kurentoIp "$IP"
    else
      # 2.2
      yq w -i $TARGET kurento[0].ip "$IP"
      yq w -i $TARGET freeswitch.sip_ip "$IP"
    fi
    chown bigbluebutton:bigbluebutton $TARGET
    chmod 644 $TARGET
  fi
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

install_certificate() {
  apt-get update
  apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install grub-pc update-notifier-common
  apt-get dist-upgrade -yq
  need_pkg coturn

  need_pkg software-properties-common
  need_ppa certbot-ubuntu-certbot-bionic.list ppa:certbot/certbot 75BCA694 7BF5
  apt-get -y install certbot

  certbot certonly --standalone --non-interactive --preferred-challenges http \
    --deploy-hook "systemctl restart coturn" \
    -d $HOST --email $EMAIL --agree-tos -n
}

install_coturn() {
  check_host $COTURN_HOST

  apt-get update
  apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install grub-pc update-notifier-common
  apt-get dist-upgrade -yq
  need_pkg coturn

  need_pkg software-properties-common 
  need_ppa certbot-ubuntu-certbot-bionic.list ppa:certbot/certbot 75BCA694 7BF5
  apt-get -y install certbot

  certbot certonly --standalone --non-interactive --preferred-challenges http \
    --deploy-hook "systemctl restart coturn" \
    -d $COTURN_HOST --email $EMAIL --agree-tos -n

  COTURN_REALM=$(echo $COTURN_HOST | cut -d'.' -f2-)

  cat <<HERE > /etc/turnserver.conf
# Example coturn configuration for BigBlueButton

# These are the two network ports used by the TURN server which the client
# may connect to. We enable the standard unencrypted port 3478 for STUN,
# as well as port 443 for TURN over TLS, which can bypass firewalls.
listening-port=3478
tls-listening-port=443

# If the server has multiple IP addresses, you may wish to limit which
# addresses coturn is using. Do that by setting this option (it can be
# specified multiple times). The default is to listen on all addresses.
# You do not normally need to set this option.
#listening-ip=172.17.19.101

# If the server is behind NAT, you need to specify the external IP address.
# If there is only one external address, specify it like this:
external-ip=$IP

# If you have multiple external addresses, you have to specify which
# internal address each corresponds to, like this. The first address is the
# external ip, and the second address is the corresponding internal IP.
#external-ip=172.17.19.131/10.0.0.11
#external-ip=172.17.18.132/10.0.0.12

# Fingerprints in TURN messages are required for WebRTC
fingerprint

# The long-term credential mechanism is required for WebRTC
lt-cred-mech

# Configure coturn to use the "TURN REST API" method for validating time-
# limited credentials. BigBlueButton will generate credentials in this
# format. Note that the static-auth-secret value specified here must match
# the configuration in BigBlueButton's turn-stun-servers.xml
# You can generate a new random value by running the command:
#   openssl rand -hex 16
use-auth-secret
static-auth-secret=$COTURN_SECRET

# If the realm value is unspecified, it defaults to the TURN server hostname.
# You probably want to configure it to a domain name that you control to
# improve log output. There is no functional impact.
# realm=example.com
realm=$COTURN_REALM

# Configure TLS support.
# Adjust these paths to match the locations of your certificate files
cert=/etc/letsencrypt/live/$COTURN_HOST/fullchain.pem
pkey=/etc/letsencrypt/live/$COTURN_HOST/privkey.pem

# Limit the allowed ciphers to improve security
# Based on https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
cipher-list="ECDH+AESGCM:ECDH+CHACHA20:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS"

# Enable longer DH TLS key to improve security
dh2066

# All WebRTC-compatible web browsers support TLS 1.2 or later, so disable
# older protocols
no-tlsv1
no-tlsv1_1

# Log to a single filename (rather than new log files each startup). You'll
# want to install a logrotate configuration (see below)
log-file=/var/log/coturn.log
simple-log
HERE

  cat <<HERE > /etc/logrotate.d/coturn
/var/log/coturn.log
{
    rotate 30
    daily
    missingok
    notifempty
    delaycompress
    compress
    postrotate
    systemctl kill -sHUP coturn.service
    endscript
}
HERE

  sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/g' /etc/default/coturn
  systemctl restart coturn

  cat 1>&2 <<HERE

#
# This TURN server is ready.  To configure your BigBlueButton server to use this TURN server, 
# add the option
#
#  -c $COTURN_HOST:$COTURN_SECRET
#
# the the bbb-install.sh command.
#
HERE
}

main "$@" || exit 1

