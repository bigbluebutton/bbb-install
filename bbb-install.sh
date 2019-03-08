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

# BlueButton is an open source conferencing system.  For more informaiton see
#    http://www.bigbluebutton.org/.
#
# This bbb-install.sh scrip automates many of the instrallation and configuration
# steps at
#    http://docs.bigbluebutton.org/install/install.html
#
#
#  Examples
#
#  Install BigBlueButton and configure using server's external IP address
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200
#
#
#  Install BigBlueButton and configure using hostname bbb.example.com
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com
#
#
#  Install BigBlueButton with a SSL certificate from Let's Encrypt using e-mail info@example.com:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com
#
#
#  Install BigBlueButton with SSL + latest build of HTML5 client
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t
#
#
#  Install BigBlueButton with SSL + GreenLight
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -g
#
#
#  All of the above
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t -g
#

usage() {
    cat 1>&2 <<HERE
Installer script for setting up a BigBlueButton 2.0 server.  

This script also supports installation of a separate coturn (TURN) server on a separate server.

USAGE:
    bbb-install.sh [OPTIONS]

OPTIONS (install BigBlueButton):

  -v <version>           Install given version of BigBlueButton (e.g. 'xenial-200') (required)

  -s <hostname>          Configure server with <hostname>
  -e <email>             Email for Let's Encrypt certbot
  -c <hostname>:<secret> Configure with coturn server at <hostname> using <secret>

  -t                     Install HTML5 client (currently under development)
  -g                     Install GreenLight

  -p <host>              Use apt-get proxy at <host>

  -h                     Print help

OPTIONS (install coturn):

  -c <hostname>:<secret> Configure coturn with <hostname> and <secret> (required)
  -e <email>             E-mail for Let's Encrypt certbot (required)


EXAMPLES

Setup a BigBlueButton server

    ./bbb-install.sh -v xenial-200
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com -t -g
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com -t -g -c turn.example.com:1234324

Setup a coturn server

    ./bbb-install.sh -c turn.example.com:1234324 -e info@example.com

SUPPORT:
     Source: https://github.com/bigbluebutton/bbb-install
   Commnity: https://bigbluebutton.org/support

HERE
}

main() {
  export DEBIAN_FRONTEND=noninteractive

  need_x64

  while builtin getopts "hs:c:v:e:p:gt" opt "${@}"; do
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
      c)
        COTURN=$OPTARG
        check_coturn $COTURN
        ;;
      v)
        VERSION=$OPTARG
        check_version $VERSION
        ;;
      e)
        EMAIL=$OPTARG
        if [ "$EMAIL" == "info@example.com" ]; then 
          err "You must specify a valid email address (not the email in the docs)."

        fi
        ;;
      p)
        PROXY=$OPTARG
        ;;

      g)
        GREENLIGHT=true
        ;;
      t)
        HTML5=true
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

  # Check if we're installing coturn (need an e-mail address for Let's Encerypt)
  if [ -z "$VERSION" ] && [ ! -z $COTURN ]; then
    if [ -z $EMAIL ]; then err "Installing coturn needs an e-mail address for Let's Encrypt"; fi
    need_ubuntu 18.04

    install_coturn
    exit 0
  fi

  if [ -z "$VERSION" ]; then
    usage
    exit 0
  fi

  # We're installing BigBlueButton
  need_ubuntu 16.04
  need_mem
  check_apache2

  if [ ! -z "$GREENLIGHT" ]; then
    if [ -z "$HOST" ] || [ -z $EMAIL ]; then err "The -g option requires both the -s and -e options"; fi
  fi
  if [ ! -z "$HTML5" ]; then
    if [ -z "$HOST" ] || [ -z $EMAIL ]; then err "The -t option requires both the -s and -e options"; fi
  fi

  get_IP
  if [ -z "$IP" ]; then err "Unable to determine local IP address."; fi

  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

  need_ppa jonathonf-ubuntu-ffmpeg-4-xenial.list ppa:jonathonf/ffmpeg-4 F06FC659 F06FC659	# Latest version of ffmpeg
  need_ppa rmescandon-ubuntu-yq-xenial.list ppa:rmescandon/yq CC86BB64 CC86BB64			# Edit yaml files with yq

  if [ ! -z "$PROXY" ]; then
    echo "Acquire::http::Proxy \"http://$PROXY:3142\";"  > /etc/apt/apt.conf.d/01proxy
  fi

  apt-get update
  apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install grub-pc update-notifier-common
  apt-get dist-upgrade -yq

  need_pkg curl
  need_pkg haveged
  need_pkg build-essential
  need_pkg yq

  need_pkg bigbluebutton

  if [ -f /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties ]; then
    SERVLET_DIR=/usr/share/bbb-web
    TURN_XML=$SERVLET_DIR/WEB-INF/classes/spring/turn-stun-servers.xml
  else
    SERVLET_DIR=/var/lib/tomcat7/webapps/bigbluebutton
    TURN_XML=$SERVLET_DIR/WEB-INF/spring/turn-stun-servers.xml
  fi

  while [ ! -f $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties ]; do sleep 1; echo -n '.'; done

  check_lxc
  check_nat

  need_pkg bbb-demo
  while [ ! -f /var/lib/tomcat7/webapps/demo/bbb_api_conf.jsp ]; do sleep 1; echo -n '.'; done

  if [ ! -z "$HTML5" ]; then
    install_HTML5
  fi

  if [ ! -z "$HOST" ] && [ ! -z "$EMAIL" ]; then
    install_ssl_letsencrypt
  fi

  if [ ! -z "$GREENLIGHT" ]; then
    install_greenlight
  fi

  if [ ! -z "$COTURN" ]; then
    configure_coturn
  fi

  apt-get auto-remove -y

  if [ ! -z "$HOST" ]; then
    bbb-conf --setip $HOST
  else
    bbb-conf --setip $IP
  fi

  if systemctl status freeswitch.service | grep -q SETSCHEDULER; then
    sed -i "s/^CPUSchedulingPolicy=rr/#CPUSchedulingPolicy=rr/g" /lib/systemd/system/freeswitch.service
    systemctl daemon-reload
    systemctl restart freeswitch
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

need_root() {
  if [ $EUID != 0 ]; then err "You must run this command as root."; fi
}

need_mem() {
  MEM=`grep MemTotal /proc/meminfo | awk '{print $2}'`
  MEM=$((MEM/1000))
  if (( $MEM < 3940 )); then err "Your server needs to have (at least) 4G of memory."; fi
}

need_ubuntu(){
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
    local external_ip=$(wget -qO- http://169.254.169.254/latest/meta-data/public-ipv4)
  elif [ -r /sys/firmware/dmi/tables/smbios_entry_point ] && which dmidecode > /dev/null && dmidecode -s bios-vendor | grep -q Google; then
    # Google Compute Cloud
    local external_ip=$(wget -O - -q "http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" --header 'Metadata-Flavor: Google')
  else
    # Try and determine the external IP
    need_pkg dnsutils
    local external_ip=$(dig +short $HOST @resolver1.opendns.com | grep '^[.0-9]*$' | tail -n1)
  fi

  # Check if the external IP reaches the internal IP
  if [ ! -z "$external_ip" ] && [ "$IP" != "$external_ip" ]; then
    need_pkg nginx
    if [ ! -L /etc/nginx/sites-enabled/default ]; then
      err "The default symbolic link for nginx does not exist."
    fi

    if [ -L /etc/nginx/sites-enabled/bigbluebutton ]; then
      rm -f /etc/nginx/sites-enabled/bigbluebutton
      systemctl restart nginx
    fi
      # Test if we can we reach this server from the external IP
      cd /var/www/html
      local tmp_file="$(mktemp XXXXXX.html)"
      chown www-data:www-data $tmp_file
      if timeout 5 wget -qS --spider "http://$external_ip/$tmp_file" > /dev/null 2>&1; then
        INTERNAL_IP=$IP
        IP=$external_ip
      fi
      rm -f $tmp_file

    if [ -f /etc/nginx/sites-available/bigbluebutton ]; then
      ln -s /etc/nginx/sites-available/bigbluebutton /etc/nginx/sites-enabled/bigbluebutton
      systemctl restart nginx
    fi
  fi
}

need_apt-get-update() {
  # On some EC2 instanced apt-get is not run, so we'll do it 
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ] && [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
    apt-get update
  elif [ -z "$ran_apt_get_update" ]; then 
    apt-get update 
  fi
  ran_apt_get_update="true"
}

need_pkg() {
  need_root
  need_apt-get-update
  if ! apt-cache search --names-only $1 | grep -q $1; then err "Unable to locate package: $1"; fi
  if ! dpkg -s $1 > /dev/null 2>&1; then apt-get install -yq $1; fi
}

need_ppa() {
  need_pkg software-properties-common
  if [ ! -f /etc/apt/sources.list.d/$1 ]; then
    add-apt-repository -y $2 
  fi
  if ! apt-key list $3 | grep -q $4; then
    add-apt-repository $2 -y
    if ! apt-key list $3 | grep -q $4; then
      err "Unable to setup PPA for $2"
    fi
  fi
}

check_version() {
  if ! echo $1 | grep -q xenial; then err "This script can only install BigBlueButton 2.0 (or later)"; fi
  DISTRO=$(echo $1 | sed 's/-.*//g')
  if ! wget -qS --spider "https://ubuntu.bigbluebutton.org/$1/dists/bigbluebutton-$DISTRO/Release.gpg" > /dev/null 2>&1; then
    err "Unable to locate packages for $1."
  fi
  need_root
  need_pkg apt-transport-https
  if ! apt-key list | grep -q BigBlueButton; then
    wget https://ubuntu.bigbluebutton.org/repo/bigbluebutton.asc -O- | apt-key add -
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

  echo "deb https://ubuntu.bigbluebutton.org/$VERSION bigbluebutton-$DISTRO main" > /etc/apt/sources.list.d/bigbluebutton.list
}

check_host() {
  need_pkg dnsutils
  DIG_IP=$(dig +short $1 | grep '^[.0-9]*$' | tail -n1)
  if [ -z "$DIG_IP" ]; then err "Unable to resolve $1 to an IP address using DNS lookup."; fi
  get_IP
  if [ "$DIG_IP" != "$IP" ]; then err "DNS lookup for $1 resolved to $DIG_IP but didn't match local $IP."; fi
}

check_coturn() {
  if ! echo $1 | grep -q ':'; then err "Option for coturn must be <hostname>:<secret>"; fi
  COTURN_HOST=$(echo $OPTARG | cut -d':' -f1)
  COTURN_SECRET=$(echo $OPTARG | cut -d':' -f2)

  if [ -z "$COTURN_HOST" ];   then err "-c option must contain <hostname>"; fi
  if [ -z "$COTURN_SECRET" ]; then err "-c option must contain <secret>"; fi

  if [ "$COTURN_HOST" == "turn.example.com" ]; then 
    err "You must specify a valid hostname (not the one given in the docs"
  fi
  if [ "$COTURN_SECRET" == "1234abcd" ]; then 
    err "You must specify a new password (not the one given in the docs as an example)."
  fi

  need_pkg dnsutils
  DIG_IP=$(dig +short $COTURN_HOST | grep '^[.0-9]*$' | tail -n1)
  if [ -z "$DIG_IP" ]; then err "Unable to resolve $COTURN_HOST to an external IP address using DNS lookup."; fi
}

check_apache2() {
  if dpkg -l | grep -q apache2; then err "You must unisntall apache2 first"; fi
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
    sed -i "s/<param name=\"ws-binding\".*/<param name=\"ws-binding\"  value=\"$IP:5066\"\/>/g" /opt/freeswitch/conf/sip_profiles/external.xml
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

install_HTML5() {
  if ! apt-key list | grep -q MongoDB; then
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
  fi

  echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  apt-get update

  need_pkg mongodb-org
  service mongod start

  if dpkg -s nodejs | grep Version | grep -q 4.2.6; then
    apt-get purge -y nodejs
  fi

  if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
  fi

  if ! apt-cache madison nodejs | grep -q node_8; then
    err "Did not detect nodejs 8.x candidate for installation"
  fi

  need_pkg nodejs
  need_pkg bbb-html5
  apt-get install -yq bbb-webrtc-sfu
  apt-get purge -yq kms-core-6.0 kms-elements-6.0 kurento-media-server-6.0 > /dev/null 2>&1  # Remove older packages

  if [ ! -z "$INTERNAL_IP" ]; then
   sed -i 's/.*stunServerAddress.*/stunServerAddress=64.233.177.127/g' /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
   sed -i 's/.*stunServerPort.*/stunServerPort=19302/g' /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
  fi

  sed -i 's/offerWebRTC="false"/offerWebRTC="true"/g' /var/www/bigbluebutton/client/conf/config.xml
}

install_greenlight(){
  need_pkg software-properties-common

  if ! dpkg -l | grep -q linux-image-extra-virtual; then
    apt-get install -y \
      linux-image-extra-$(uname -r) \
      linux-image-extra-virtual
  fi

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

  mkdir -p ~/greenlight

  if [ ! -f /var/tmp/secret ]; then
    # This will trigger the download of GreenLight docker image (if needed)
    echo "SECRET_KEY_BASE=$(docker run --rm bigbluebutton/greenlight:v2 bundle exec rake secret)" > /var/tmp/secret
  fi
  if [ ! -s /var/tmp/secret ]; then err "Invalid secret file in /var/tmp/secret for GreenLight"; fi
  source /var/tmp/secret

  if [ ! -f ~/greenlight/env ]; then
    docker run --rm bigbluebutton/greenlight:v2 cat ./sample.env > ~/greenlight/env
  fi

  BIGBLUEBUTTONENDPOINT=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
  BIGBLUEBUTTONSECRET=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | grep securitySalt | cut -d= -f2)

  # Update GreenLight configuration file in ~/greenlight/env
  sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|"                       ~/greenlight/env
  sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTONENDPOINT|" ~/greenlight/env
  sed -i "s|.*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTONSECRET|"       ~/greenlight/env

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

  # Greenlight 2.0 currently does not support recording notifications.
  #if [ ! -f /usr/local/bigbluebutton/core/scripts/post_publish/greenlight_recording_notify.rb ]; then
  #  docker run --rm bigbluebutton/greenlight cat ./scripts/greenlight_recording_notify.rb > /usr/local/bigbluebutton/core/scripts/post_publish/greenlight_recording_notify.rb
  #fi

  if ! docker ps | grep -q greenlight; then
    docker run -d -p 5000:80 --restart=unless-stopped \
      -v ~/greenlight/db/production:/usr/src/app/db/production \
      --env-file ~/greenlight/env \
      --name greenlight-v2 bigbluebutton/greenlight:v2
      sleep 5
  fi
}


install_ssl_letsencrypt() {
  sed -i 's/tryWebRTCFirst="false"/tryWebRTCFirst="true"/g' /var/www/bigbluebutton/client/conf/config.xml

  if ! grep -q $HOST /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml; then
    bbb-conf --setip $HOST
  fi

  mkdir -p /etc/nginx/ssl

  need_pkg letsencrypt

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

    if ! letsencrypt --email $EMAIL --agree-tos --rsa-key-size 4096 --webroot -w /var/www/bigbluebutton-default/ -d $HOST certonly; then
      cp /tmp/bigbluebutton.bak /etc/nginx/sites-available/bigbluebutton
      systemctl restart nginx
      err "Let's Encrypt SSL request for $HOST did not succeed - exiting"
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

  if [ -f /etc/cron.d/renew-letsencrypt ]; then 
    rm /etc/cron.d/renew-letsencrypt
  fi

  if [ ! -f /etc/cron.daily/renew-letsencrypt ]; then
    cat <<HERE > /etc/cron.daily/renew-letsencrypt
#!/bin/bash
/usr/bin/letsencrypt renew >> /var/log/letsencrypt-renew.log
/bin/systemctl reload nginx
HERE
  fi
  chmod 644 /etc/cron.daily/renew-letsencrypt

  # Setup rest of BigBlueButton Configuration for SSL
  sed -i "s/<param name=\"wss-binding\"  value=\"[^\"]*\"\/>/<param name=\"wss-binding\"  value=\"$IP:7443\"\/>/g" /opt/freeswitch/conf/sip_profiles/external.xml

  sed -i 's/http:/https:/g' /etc/bigbluebutton/nginx/sip.nginx
  sed -i 's/5066/7443/g'    /etc/bigbluebutton/nginx/sip.nginx

  sed -i 's/bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties

  sed -i 's/jnlpUrl=http/jnlpUrl=https/g'   /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties
  sed -i 's/jnlpFile=http/jnlpFile=https/g' /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties

  sed -i 's|http://|https://|g' /var/www/bigbluebutton/client/conf/config.xml

  yq w -i /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml playback_protocol https
  chmod 644 /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml 

  if [ -f /var/lib/tomcat7/webapps/demo/bbb_api_conf.jsp ]; then
    sed -i 's/String BigBlueButtonURL = "http:/String BigBlueButtonURL = "https:/g' /var/lib/tomcat7/webapps/demo/bbb_api_conf.jsp
  fi

  if [ -f /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml ]; then
    yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.note.url https://$HOST/pad
  fi

  # Update GreenLight (if installed) to use SSL
  if [ -f ~/greenlight/env ]; then
    BIGBLUEBUTTONENDPOINT=$(cat $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
    sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTONENDPOINT|" ~/greenlight/env
    docker stop greenlight-v2
    docker rm greenlight-v2
    docker run -d -p 5000:80 --restart=unless-stopped -v ~/greenlight/db/production:/usr/src/app/db/production --env-file ~/greenlight/env --name greenlight-v2 bigbluebutton/greenlight:v2
  fi

  # Update HTML5 client (if installed) to use SSL
  if [ -f  /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json ]; then
    sed -i "s|\"wsUrl.*|\"wsUrl\": \"wss://$HOST/bbb-webrtc-sfu\",|g" \
      /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json
  fi

  TARGET=/usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml
  if [ -f $TARGET ]; then
    if grep -q kurentoIp $TARGET; then
      yq w -i $TARGET kurentoIp "$IP"
    else
      yq w -i $TARGET kurento[0].ip "$IP"
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
            </set>
        </property>
    </bean>
</beans>
HERE
}

install_coturn() {
  IP=$(hostname -I | cut -f1 -d' ')
  if [ "$DIG_IP" != "$IP" ]; then err "DNS lookup for $COTURN_HOST resolved to $DIG_IP but didn't match local IP of $IP."; fi

  apt-get update
  apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install grub-pc update-notifier-common
  apt-get dist-upgrade -yq
  need_pkg coturn

  need_pkg software-properties-common 
  need_ppa certbot-ubuntu-certbot-bionic.list ppa:certbot/certbot 75BCA694 7BF5
  apt-get -y install certbot

  certbot certonly --standalone --preferred-challenges http \
    --deploy-hook "systemctl restart coturn" \
    -d $COTURN_HOST --email $EMAIL --agree-tos -n

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
#external-ip=172.17.19.120
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
