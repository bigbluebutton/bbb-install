#!/bin/bash -e

# BlueButton open source conferencing system - http://www.bigbluebutton.org/   
#
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

#
# Install script for setting up BigBlueButton 2.0 with SSL (via LetsEncrypt)

#
#  Examples
#  
#  To install BigBlueButton with server's external IP address:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 
#  
#  To install BigBlueButton and configure the server with the hostname bbb.example.com:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com 
#  
#  To install BigBlueButton with a SSL certificate from Let's Encrypt using e-mail info@example.com:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com
#
#  To install latest build of HTML5 client 
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -t
#
#  To install GreenLight (requires previous install of SSL certificate):
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -g
#
#  To do all of the above with a single command:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t -g
#

usage() {
    cat 1>&2 <<HERE
BigBlueButon 2.0-beta (or later) install script

USAGE:
    bbb-install.sh [OPTIONS]

OPTIONS:

  -v <version>     Install given version of BigBlueButton (e.g. 'xenial-200') (required)

  -s <hostname>    Configure server with <hostname> 
  -e <email>       Install SSL certificate from Let's Encrypt using <email>

  -t               Install HTML5 client (currently under development)
  -g               Install GreenLight 

  -p <host>        Use apt-get proxy at <host>

  -h               Print help

EXAMPLES:
  
    ./bbb-install.sh -v xenial-200
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com -t -g

SUPPORT:
     Source: https://github.com/bigbluebutton/bbb-install
   Commnity: https://bigbluebutton.org/support 

HERE
}

main() {
  export DEBIAN_FRONTEND=noninteractive

  need_root
  need_mem
  need_ubuntu
  need_x64
  check_apache2

  while builtin getopts "hs:v:e:p:gt" opt "${@}"; do
    case $opt in
      h) 
        usage
        exit 0
        ;;

      s)
        HOST=$OPTARG
        check_host $HOST
        ;;
      v)
        VERSION=$OPTARG
        check_version $VERSION
        ;;
      e)
        EMAIL=$OPTARG
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

  if [ -z "$VERSION" ]; then
    usage
    exit 0
  fi

  if [ ! -z "$GREENLIGHT" ]; then
    if [ -z "$HOST" ] || [ -z $EMAIL ]; then err "The -g option requires both the -s and -e options"; fi
  fi
  if [ ! -z "$HTML5" ]; then
    if [ -z "$HOST" ] || [ -z $EMAIL ]; then err "The -t option requires both the -s and -e options"; fi
  fi
  
  get_IP
  if [ -z "$IP" ]; then err "Unable to determine local IP address."; fi  

  install_bigbluebutton_apt-get-key
  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

  if [ ! -f jonathonf-ubuntu-ffmpeg-4-xenial.list ]; then  # Use ffmpeg 4.0
    add-apt-repository ppa:jonathonf/ffmpeg-4 -y
  fi

  if [ ! -z "$PROXY" ]; then
    echo "Acquire::http::Proxy \"http://$PROXY:3142\";"  > /etc/apt/apt.conf.d/01proxy
  fi

  apt-get update 
  apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install grub-pc
  apt-get dist-upgrade -yq 

  need_pkg curl
  need_pkg haveged
  need_pkg build-essential

  need_pkg bigbluebutton
  while [ ! -f /var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties ]; do sleep 1; echo -n '.'; done

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

  apt-get auto-remove -y

  if [ ! -z "$HOST" ]; then
    bbb-conf --setip $HOST
  else
    bbb-conf --setip $IP
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
  if [ "$RELEASE" != "16.04" ]; then err "You must run this command on Ubuntu 16.04 server."; fi
}

need_x64() {
  UNAME=`uname -m`
  if [ "$UNAME" != "x86_64" ]; then err "You must run this command on a 64-bit server."; fi  
}

get_IP() {
  if [ ! -z "$IP" ]; then return 0; fi

  if LANG=c ifconfig | grep -q 'venet0:0'; then
    IP=$(ifconfig | grep -v '127.0.0.1' | grep -E "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | tail -1 | cut -d: -f2 | awk '{ print $1}')
  else
    IP=$(echo "$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^et.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^en.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^wl.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^bo.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^em.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^p.p.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')"  | head -n1)
  fi

  if [ -r /sys/devices/virtual/dmi/id/product_uuid ] && [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
    # EC2
    local external_ip=$(wget -qO- http://169.254.169.254/latest/meta-data/public-ipv4)
  elif [ -r /sys/firmware/dmi/tables/smbios_entry_point ] && which dmidecode > /dev/null && dmidecode -s bios-vendor | grep -q Google; then
    # Google Compute Cloud
    local external_ip=$(wget -O - -q "http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" --header 'Metadata-Flavor: Google')
  else
    # Try and determine the external IP
    need_pkg dnsutils
    local external_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
  fi

  if [ ! -z "$external_ip" ] && [ "$ip" != "$external_ip" ]; then
    need_pkg nginx

    if [ -L /etc/nginx/sites-enabled/bigbluebutton ]; then
      rm -f /etc/nginx/sites-enabled/bigbluebutton 
      systemctl restart nginx
    fi
      # Test if we can we reach this server from the external IP
      cd /var/www/html
      local tmp_file="$(mktemp XXXXXX.html)"
      chown www-data:www-data $tmp_file
      if wget -qS --spider "http://$external_ip/$tmp_file" > /dev/null 2>&1; then
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

need_pkg() {
  if [ ! -f /var/cache/apt/pkgcache.bin ]; then apt-get update; fi
  if ! apt-cache search --names-only $1 | grep -q $1; then err "Unable to locate package: $1"; fi
  if ! dpkg -s $1 > /dev/null 2>&1; then apt-get install -yq $1; fi
}

check_version() {
  if ! echo $1 | grep -q xenial; then err "This script can only install BigBlueButton 2.0 (or later)"; fi
  DISTRO=$(echo $1 | sed 's/-.*//g')
  if ! wget -qS --spider "https://ubuntu.bigbluebutton.org/$1/dists/bigbluebutton-$DISTRO/Release.gpg" > /dev/null 2>&1; then
    err "Unable to locate packages for $1."
  fi
  echo "deb https://ubuntu.bigbluebutton.org/$VERSION bigbluebutton-$DISTRO main" > /etc/apt/sources.list.d/bigbluebutton.list
}

check_host() {
  need_pkg dnsutils
  DIG_IP=$(dig +short $1)
  if [ -z "$DIG_IP" ]; then err "Unable to resolve $1 to an IP address using DNS lookup."; fi
  get_IP
  if [ "$DIG_IP" != "$IP" ]; then err "DNS lookup for $1 resolved to $DIG_IP but didn't match local $IP."; fi
}

check_apache2() {
  if dpkg -l | grep -q apache2; then err "You must unisntall apache2 first"; fi
}

install_bigbluebutton_apt-get-key() {
 need_pkg apt-transport-https
 if ! apt-key list | grep -q BigBlueButton; then
    wget https://ubuntu.bigbluebutton.org/repo/bigbluebutton.asc -O- | apt-key add -
  fi
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

    if [ -f /lib/systemd/system/dummy-nic.service ]; then RELOAD=true; fi
    if ! grep -q $IP /lib/systemd/system/dummy-nic.service > /dev/null 2>&1; then
      cat > /lib/systemd/system/dummy-nic.service << HERE
[Unit]
Description=Configure dummy NIC for FreeSWITCH
After=network.target

[Service]
ExecStart=/sbin/ip addr add $IP dev lo

[Install]
WantedBy=multi-user.target
HERE
      if [ "$RELOAD" == "true" ]; then
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

  need_pkg nodejs
  need_pkg bbb-html5
  apt-get install -yq bbb-webrtc-sfu
  apt-get purge -yq kms-core-6.0 kms-elements-6.0 kurento-media-server-6.0	# Remove older packages

  if [ ! -z "$INTERNAL_IP" ]; then
   sed -i 's/.*stunServerAddress.*/stunServerAddress=64.233.177.127/g' /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
   sed -i 's/.*stunServerPort.*/stunServerPort=19302/g' /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
  fi
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
    echo "SECRET_KEY_BASE=$(docker run --rm bigbluebutton/greenlight rake secret)" > /var/tmp/secret
  fi
  if [ ! -s /var/tmp/secret ]; then err "Invalid secret file in /var/tmp/secret for GreenLight"; fi
  source /var/tmp/secret

  if [ ! -f ~/greenlight/env ]; then
    docker run --rm bigbluebutton/greenlight cat ./sample.env > ~/greenlight/env
  fi
  
  BIGBLUEBUTTONENDPOINT=$(cat /var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
  BIGBLUEBUTTONSECRET=$(cat /var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | grep securitySalt | cut -d= -f2)

  # Update GreenLight configuration file in ~/greenlight/env
  sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|"                       ~/greenlight/env
  sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTONENDPOINT|" ~/greenlight/env
  sed -i "s|.*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTONSECRET|"       ~/greenlight/env

  need_pkg bbb-webhooks

  if [ ! -f /etc/bigbluebutton/nginx/greenlight.nginx ]; then
    docker run --rm bigbluebutton/greenlight cat ./scripts/greenlight.nginx | tee /etc/bigbluebutton/nginx/greenlight.nginx
    cat > /etc/bigbluebutton/nginx/greenlight-redirect.nginx << HERE
location = / {
  return 301 /b;
}     
HERE
    systemctl restart nginx
  fi

  if ! gem list | grep -q java_properties; then
    gem install jwt java_properties
  fi

  if [ ! -f /usr/local/bigbluebutton/core/scripts/post_publish/greenlight_recording_notify.rb ]; then
    docker run --rm bigbluebutton/greenlight cat ./scripts/greenlight_recording_notify.rb > /usr/local/bigbluebutton/core/scripts/post_publish/greenlight_recording_notify.rb
  fi

  if ! docker ps | grep -q greenlight; then
    docker run -d -p 5000:80 --restart=unless-stopped \
      -v ~/greenlight/db/production:/usr/src/app/db/production -v ~/greenlight/assets:/usr/src/app/public/system \
      --env-file ~/greenlight/env \
      --name greenlight bigbluebutton/greenlight
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
  listen [::]:443;

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

  if [ ! -f /etc/cron.daily/renew-letsencrupt ]; then
    cat <<HERE > /etc/cron.d/renew-letsencrypt
30 2 * * 1 /usr/bin/letsencrypt renew >> /var/log/letsencrypt-renew.log
35 2 * * 1 /bin/systemctl reload nginx
HERE
  fi

  # Setup rest of BigBlueButton Configuration for SSL
  sed -i "s/<param name=\"ws[s]*-binding\"  value=\"[^\"]*\"\/>/<param name=\"wss-binding\"  value=\"$IP:7443\"\/>/g" /opt/freeswitch/conf/sip_profiles/external.xml

  sed -i 's/http:/https:/g' /etc/bigbluebutton/nginx/sip.nginx
  sed -i 's/5066/7443/g'    /etc/bigbluebutton/nginx/sip.nginx

  sed -i 's/bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' /var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties

  sed -i 's/jnlpUrl=http/jnlpUrl=https/g'   /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties
  sed -i 's/jnlpFile=http/jnlpFile=https/g' /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties

  sed -i 's|http://|https://|g' /var/www/bigbluebutton/client/conf/config.xml

  sed -i 's/playback_protocol: http$/playback_protocol: https/g' /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml

  if [ -f /var/lib/tomcat7/webapps/demo/bbb_api_conf.jsp ]; then 
    sed -i 's/String BigBlueButtonURL = "http:/String BigBlueButtonURL = "https:/g' /var/lib/tomcat7/webapps/demo/bbb_api_conf.jsp
  fi  

  # Update GreenLight (if installed) to use SSL
  if [ -f ~/greenlight/env ]; then
    BIGBLUEBUTTONENDPOINT=$(cat /var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
    sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTONENDPOINT|" ~/greenlight/env
    docker stop greenlight
    docker rm greenlight
    docker run -d -p 5000:80 --restart=unless-stopped -v ~/greenlight/db/production:/usr/src/app/db/production -v ~/greenlight/assets:/usr/src/app/public/system --env-file ~/greenlight/env --name greenlight bigbluebutton/greenlight
  fi

  # Update HTML5 client (if installed) to use SSL
  if [ -f  /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json ]; then
    sed -i "s|\"wsUrl.*|\"wsUrl\": \"wss://$HOST/bbb-webrtc-sfu\",|g" \
      /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json
  fi
}


main "$@" || exit 1
