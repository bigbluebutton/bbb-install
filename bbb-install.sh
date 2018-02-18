#!/bin/bash -ex

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
#  To install BigBlueButton and configure the server with the hostname bbb.my-server.com:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com 
#  
#  To install BigBlueButton with a SSL certificate from Let's Encrypt using e-mail info@my-server.com:
#
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com -e info@my-server.com
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
#    wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com -e info@my-server.com -t -g
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
    ./bbb-install.sh -v xenial-200 -s bbb.my-server.com -e info@my-server.com
    ./bbb-install.sh -v xenial-200 -s bbb.my-server.com -e info@my-server.com -t -g

ADDITIONAL HELP:
     Source: https://github.com/bigbluebutton/bbb-install
    Support: https://bigbluebutton.org/support 
HERE
}

main() {
  need_root
  need_mem
  need_ubuntu
  need_x64
  check_apache2
  
  IP=$(get_IP)
  if [ -z "$IP" ]; then err "Unable to determine local IP address."; fi  

  while builtin getopts "hs:v:e:p:gt" opt "${@}"; do
    case $opt in
      h) 
        usage
        exit 0
        ;;

      s)
        HOST=$OPTARG
        ;;
      v)
        VERSION=$OPTARG
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

  check_version $VERSION
  install_apt-get-key

  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

  if [ ! -z "$PROXY" ]; then
    echo "Acquire::http::Proxy \"http://$PROXY:3142\";"  > /etc/apt/apt.conf.d/01proxy
  fi

  sudo apt-get update && sudo apt-get dist-upgrade -y

  need_pkg curl
  need_pkg haveged
  need_pkg build-essential

  need_pkg bigbluebutton
  check_lxc

  need_pkg bbb-demo

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
    bbb-conf --check
  else
    bbb-conf --restart
  fi
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
  if LANG=c ifconfig | grep -q 'venet0:0'; then
    local ip=$(ifconfig | grep -v '127.0.0.1' | grep -E "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | tail -1 | cut -d: -f2 | awk '{ print $1}')
  else
    local ip=$(echo "$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^et.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^en.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^wl.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')$(LANG=c ifconfig  | awk -v RS="" '{gsub (/\n[ ]*inet /," ")}1' | grep ^bo.* | grep addr: | head -n1 | sed 's/.*addr://g' | sed 's/ .*//g')"  | head -n1)
  fi
  echo $ip
}

need_pkg() {
  if ! dpkg -l | grep -q $1; then sudo apt-get install -y $1; fi
}

check_version() {
  DISTRO=$(echo $1 | sed 's/-.*//g')
  if ! wget -qS --spider "https://ubuntu.bigbluebutton.org/$1/dists/bigbluebutton-$DISTRO/Release.gpg" > /dev/null 2>&1; then
    err "Unable to locate packages for $1."
  fi
  echo "deb https://ubuntu.bigbluebutton.org/$VERSION bigbluebutton-$DISTRO main" > /etc/apt/sources.list.d/bigbluebutton.list
}

check_apache2() {
  if dpkg -l | grep -q apache2; then err "You must unisntall apache2 first"; fi
}

install_apt-get-key() {
 need_pkg apt-transport-https
 if ! apt-key list | grep -q BigBlueButton; then
    wget https://ubuntu.bigbluebutton.org/repo/bigbluebutton.asc -O- | apt-key add -
  fi
}
  

# If running under LXC, then modify the FreeSWITCH systemctl service so it does not use realtime scheduler
check_lxc() {
  if sudo grep -qa container=lxc /proc/1/environ; then
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


install_HTML5() {
  if ! apt-key list | grep -q MongoDB; then
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
  fi

  echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  apt-get update

  need_pkg mongodb-org
  service mongod start

  if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then 
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
  fi

  need_pkg nodejs
  need_pkg bbb-html5
}

install_greenlight(){
  need_pkg software-properties-common

  if ! dpkg -l | grep -q linux-image-extra-virtual; then
    apt-get install -y \
      linux-image-extra-$(uname -r) \
      linux-image-extra-virtual
  fi

  if ! apt-key list | grep -q Docker; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  fi

  if ! dpkg -l | grep -q docker-ce; then
    add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

    apt-get update
    need_pkg docker-ce
  fi

  mkdir -p ~/greenlight

  if [ ! -f /var/tmp/secret ]; then
    # This will trigger the download of GreenLight docker image (if needed)
    echo "SECRET_KEY_BASE=$(docker run --rm bigbluebutton/greenlight rake secret)" > /var/tmp/secret
  fi
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
  fi
}


install_ssl_letsencrypt() {
  sed -i 's/tryWebRTCFirst="false"/tryWebRTCFirst="true"/g' /var/www/bigbluebutton/client/conf/config.xml

  while [ ! -f /var/lib/tomcat7/webapps/demo/bbb_api_conf.jsp ]; do sleep 1; done
  while [ ! -f /var/lib/tomcat7/webapps/bigbluebutton/WEB-INF/classes/bigbluebutton.properties ]; do sleep 1; done

  if ! grep -q $HOST /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml; then
    bbb-conf --setip $HOST
  fi

  mkdir -p /etc/nginx/ssl

  need_pkg letsencrypt

  if [ ! -f /etc/nginx/ssl/dhp-2048.pem ]; then
    openssl dhparam -out /etc/nginx/ssl/dhp-2048.pem 2048
  fi

  if [ ! -f /etc/letsencrypt/live/$HOST/fullchain.pem ]; then
    letsencrypt --email $EMAIL --agree-tos --webroot -w /var/www/bigbluebutton-default/ -d $HOST certonly
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
    ssl_dhparam /etc/nginx/ssl/dhp-2048.pem;

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
    echo <<HERE > /etc/cron.daily/renew-letsencrupt
30 2 * * 1 /usr/bin/letsencrypt renew >> /var/log/le-renew.log
35 2 * * 1 /bin/systemctl reload nginx
HERE
  fi

  # Setup rest of BigBlueButton Configuration for SSL
  if ! grep -q wss-binding /opt/freeswitch/conf/sip_profiles/external.xml; then
    sed -i 's/<param name="ws-binding"  value=":5066"\/>/<param name="wss-binding"  value=":7443"\/>/g' /opt/freeswitch/conf/sip_profiles/external.xml
  fi

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
