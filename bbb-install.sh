#!/bin/bash -e

# Copyright (c) 2023 BigBlueButton Inc.
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
# This bbb-install.sh script automates many of the installation and configuration
# steps at https://docs.bigbluebutton.org/2.7/administration/install
#
#
#  Examples
#
#  Install BigBlueButton 2.7.x with a SSL certificate from Let's Encrypt using hostname bbb.example.com
#  and email address info@example.com and apply a basic firewall
#
#    wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -w -v focal-270 -s bbb.example.com -e info@example.com
#
#  Install BigBlueButton with SSL + Greenlight
#
#    wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -w -v focal-270 -s bbb.example.com -e info@example.com -g
#

usage() {
    set +x
    cat 1>&2 <<HERE

Script for installing a BigBlueButton 2.7 server in under 30 minutes. It also supports upgrading a BigBlueButton server to version 2.7 (from version 2.6.0+ or an earlier 2.7.x version)

This script also checks if your server supports https://docs.bigbluebutton.org/administration/install/#minimum-server-requirements

USAGE:
    wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- [OPTIONS]

OPTIONS (install BigBlueButton):

  -v <version>           Install given version of BigBlueButton (e.g. 'focal-270') (required)

  -s <hostname>          Configure server with <hostname>
  -e <email>             Email for Let's Encrypt certbot

  -x                     Use Let's Encrypt certbot with manual DNS challenges

  -g                     Install Greenlight version 3
  -k                     Install Keycloak version 20

  -t <key>:<secret>      Install BigBlueButton LTI framework tools and add/update LTI consumer credentials <key>:<secret>

  -c <hostname>:<secret> Configure with external coturn server at <hostname> using <secret> (instead of built-in TURN server)

  -m <link_path>         Create a Symbolic link from /var/bigbluebutton to <link_path> 

  -p <host>[:<port>]     Use apt-get proxy at <host> (default port 3142)
  -r <host>              Use alternative apt repository (such as packages-eu.bigbluebutton.org)

  -d                     Skip SSL certificates request (use provided certificates from mounted volume) in /local/certs/
  -w                     Install UFW firewall (recommended)

  -j                     Allows the installation of BigBlueButton to proceed even if not all requirements [for production use] are met.
                         Note that not all requirements can be ignored. This is useful in development / testing / ci scenarios.

  -i                     Allows the installation of BigBlueButton to proceed even if Apache webserver is installed.

  -h                     Print help

OPTIONS (install Let's Encrypt certificate only):

  -s <hostname>          Configure server with <hostname> (required)
  -e <email>             Configure email for Let's Encrypt certbot (required)
  -l                     Only install Let's Encrypt certificate (not BigBlueButton)
  -x                     Use Let's Encrypt certbot with manual dns challenges (optional)

OPTIONS (install Greenlight only):

  -g                     Install Greenlight version 3 (required)
  -k                     Install Keycloak version 20 (optional)

OPTIONS (install BigBlueButton LTI framework only):

  -t <key>:<secret>      Install BigBlueButton LTI framework tools and add/update LTI consumer credentials <key>:<secret> (required)

VARIABLES (configure Greenlight only):
  GL_PATH                Configure Greenlight relative URL root path (Optional)
                          * Use this when deploying Greenlight behind a reverse proxy on a path other than the default '/' e.g. '/gl'.


EXAMPLES:

Sample options for setup a BigBlueButton 2.7 server

    -v focal-270 -s bbb.example.com -e info@example.com

Sample options for setup a BigBlueButton 2.7 server with Greenlight 3 and optionally Keycloak

    -v focal-270 -s bbb.example.com -e info@example.com -g [-k]

Sample options for setup a BigBlueButton 2.7 server with LTI framework while managing LTI consumer credentials MY_KEY:MY_SECRET 

    -v focal-270 -s bbb.example.com -e info@example.com -t MY_KEY:MY_SECRET

SUPPORT:
    Community: https://bigbluebutton.org/support
         Docs: https://github.com/bigbluebutton/bbb-install
               https://docs.bigbluebutton.org/administration/install/#minimum-server-requirements

HERE
}

main() {
  export DEBIAN_FRONTEND=noninteractive
  PACKAGE_REPOSITORY=ubuntu.bigbluebutton.org
  LETS_ENCRYPT_OPTIONS=(--webroot --non-interactive)
  SOURCES_FETCHED=false
  GL3_DIR=~/greenlight-v3
  LTI_DIR=~/bbb-lti
  NGINX_FILES_DEST=/usr/share/bigbluebutton/nginx
  CR_TMPFILE=$(mktemp /tmp/carriage-return.XXXXXX)
  printf '\n' > "$CR_TMPFILE"

  need_x64

  while builtin getopts "hs:r:c:v:e:p:m:t:xgadwjik" opt "${@}"; do

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
        LETS_ENCRYPT_OPTIONS=(--manual --preferred-challenges dns)
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
          if [[ "$PROXY" =~ : ]]; then
            echo "Acquire::http::Proxy \"http://$PROXY\";"  > /etc/apt/apt.conf.d/01proxy
          else
            echo "Acquire::http::Proxy \"http://$PROXY:3142\";"  > /etc/apt/apt.conf.d/01proxy
          fi
        fi
        ;;

      g)
        GREENLIGHT=true
        GL_DEFAULT_PATH=/

        if [ -n "$GL_PATH"  ] && [ "$GL_PATH" != "$GL_DEFAULT_PATH" ]; then
          if [[ ! $GL_PATH =~ ^/.*[^/]$ ]]; then
            err "\$GL_PATH ENV is set to '$GL_PATH' which is invalid, Greenlight relative URL root path must start but not end with '/'."
          fi
        fi
        ;;
      k)
        INSTALL_KC=true
        ;;
      t)
        LTI_CREDS_STR=$OPTARG

        if [ "$LTI_CREDS_STR" == "MY_KEY:MY_SECRET" ]; then
          err "You must use a valid complex credentials for your LTI setup (not the ones in the example)."
        fi

        if [[ ! $LTI_CREDS_STR == *:* ]]; then
          err "You must respect the format <key>:<secret> when specifying your LTI credentials."
        fi

        # Making LTI_CREDS an array, first element is the LTI TC key and the second is the LTI TC secret.
        IFS=: read -ra LTI_CREDS <<<"${LTI_CREDS_STR}"
        ;;
      a)
        err "Error: bbb-demo (API demos, '-a' option) were deprecated in BigBlueButton 2.6. Please use Greenlight or API MATE"
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
      j)
        SKIP_MIN_SERVER_REQUIREMENTS_CHECK=true
        ;;
      i)
        SKIP_APACHE_INSTALLED_CHECK=true
        ;;
      :)
        err "Missing option argument for -$OPTARG"
        ;;

      \?)
        usage_err "Invalid option: -$OPTARG" >&2
        ;;
    esac
  done

  if [ -n "$HOST" ]; then
    check_host "$HOST"
  fi

  if [ -n "$VERSION" ]; then
    check_version "$VERSION"
  fi

  if [ "$SKIP_APACHE_INSTALLED_CHECK" != true ]; then
    check_apache2
  fi

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

  if [ -n "$INSTALL_KC" ] && [ -z "$GREENLIGHT" ]; then
    err "Keycloak cannot be installed without Greenlight."
  fi

  # We're installing BigBlueButton
  env

  check_mem
  check_cpus
  check_ipv6

  need_pkg software-properties-common  # needed for add-apt-repository
  sudo add-apt-repository universe
  need_pkg wget curl gpg-agent dirmngr apparmor-utils

  # need_pkg xmlstarlet
  get_IP "$HOST"

  if [ "$DISTRO" == "focal" ]; then
    need_pkg ca-certificates

    # yq version 3 is provided by ppa:bigbluebutton/support
    # Uncomment the following to enable yq 4 after bigbluebutton/bigbluebutton#14511 is resolved
    #need_ppa rmescandon-ubuntu-yq-bionic.list         ppa:rmescandon/yq          CC86BB64 # Edit yaml files with yq

    #need_ppa libreoffice-ubuntu-ppa-focal.list       ppa:libreoffice/ppa        1378B444 # Latest version of libreoffice
    need_ppa bigbluebutton-ubuntu-support-focal.list ppa:bigbluebutton/support  2E1B01D0E95B94BC    # Needed for libopusenc0
    need_ppa martin-uni-mainz-ubuntu-coturn-focal.list ppa:martin-uni-mainz/coturn  4B77C2225D3BBDB3 # Coturn

    if ! apt-key list 5AFA7A83 | grep -q -E "1024|4096"; then   # Add Kurento package
      sudo apt-key adv --keyserver https://keyserver.ubuntu.com --recv-keys 5AFA7A83
    fi

    rm -rf /etc/apt/sources.list.d/kurento.list     # Kurento 6.15 now packaged with 2.3

    if [ -f /etc/apt/sources.list.d/nodesource.list ] &&  grep -q 16 /etc/apt/sources.list.d/nodesource.list; then
      # Node 16 might be installed, previously used in BigBlueButton
      # Remove the repository config. This will cause the repository to get
      # re-added using the current nodejs version, and nodejs will be upgraded.
      sudo rm -r /etc/apt/sources.list.d/nodesource.list
    fi
    if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
      NODE_MAJOR=18
      echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    fi
    if ! apt-key list MongoDB | grep -q 4.4; then
      wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    fi
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    rm -f /etc/apt/sources.list.d/mongodb-org-4.2.list

    touch /root/.rnd
    MONGODB=mongodb-org
    install_docker		                     # needed for bbb-libreoffice-docker
    need_pkg ruby

    BBB_WEB_ETC_CONFIG=/etc/bigbluebutton/bbb-web.properties            # Override file for local settings 

    need_pkg openjdk-17-jre
    update-java-alternatives -s java-1.17.0-openjdk-amd64

    # Remove old bbb-demo if installed from a previous 2.5 setup
    if dpkg -s bbb-demo > /dev/null 2>&1; then
      apt purge -y bbb-demo tomcat9
      rm -rf /var/lib/tomcat9
    fi
  fi

  apt-get update
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade

  need_pkg nodejs "$MONGODB" apt-transport-https haveged
  need_pkg bigbluebutton
  need_pkg bbb-html5

  if [ -f /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties ]; then
    SERVLET_DIR=/usr/share/bbb-web
  fi

  while [ ! -f "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties" ]; do sleep 1; echo -n '.'; done

  check_cap_sys_nice
  check_nat
  check_LimitNOFILE

  configure_HTML5 

  if [ -n "$LINK_PATH" ]; then
    ln -s "$LINK_PATH" "/var/bigbluebutton"
  fi

  if [ -n "$PROVIDED_CERTIFICATE" ] ; then
    install_ssl
  elif [ -n "$HOST" ] && [ -n "$EMAIL" ] ; then
    install_ssl
  fi

  if [ -n "$COTURN" ]; then
    configure_coturn

    if systemctl is-active --quiet haproxy.service; then
      systemctl disable --now haproxy.service
    fi
  else
    install_coturn
    install_haproxy
    systemctl enable --now haproxy.service  # In case we had previously disabled (see above)

    # The turn server will always try to connect to the BBB server's public IP address,
    # so if NAT is in use, add an iptables rule to adjust the destination IP address
    # of UDP packets sent from the turn server to FreeSWITCH.
    if [ -n "$INTERNAL_IP" ]; then
      need_pkg iptables-persistent
      iptables -t nat -A OUTPUT -p udp -s "$INTERNAL_IP" -d "$IP" -j DNAT --to-destination "$INTERNAL_IP"
      netfilter-persistent save
    fi
  fi

  apt-get auto-remove -y

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

  # BBB ecosystem apps:
  if [[ ${#LTI_CREDS[*]} -eq 2 ]]; then
    install_lti
  fi

  if [ -n "$GREENLIGHT" ]; then
    install_greenlight_v3
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

usage_err() {
  say "$1" >&2
  usage
  exit 1
}

check_root() {
  if [ $EUID != 0 ]; then err "You must run this command as root."; fi
}

check_mem() {
  if awk '$1~/MemTotal/ {exit !($2<3940000)}' /proc/meminfo; then
    echo "Your server should have (at least) 4 GB of memory."
    if [ "$SKIP_MIN_SERVER_REQUIREMENTS_CHECK" != true ]; then
      exit 1
    fi
  fi
}

check_ipv6() {
  if [ ! -f /proc/net/if_inet6 ]; then
    echo "Your server does not support IPv6"
    if [ "$SKIP_MIN_SERVER_REQUIREMENTS_CHECK" != true ]; then
      exit 1
    fi
  fi
}

check_cpus() {
  if [ "$(nproc --all)" -lt 4 ]; then
    echo "Your server needs to have (at least) 4 CPU cores (8 CPU cores recommended for production)."
    if [ "$SKIP_MIN_SERVER_REQUIREMENTS_CHECK" != true ]; then
      exit 1
    fi
  fi
}

check_ubuntu(){
  RELEASE=$(lsb_release -r | sed 's/^[^0-9]*//g')
  if [ "$RELEASE" != "$1" ]; then err "You must run this command on Ubuntu $1 server."; fi
}

need_x64() {
  UNAME=$(uname -m)
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


  local external_ip
  # Determine external IP 
  if grep -sqi ^ec2 /sys/devices/virtual/dmi/id/product_uuid; then
    # EC2
    external_ip=$(wget -qO- http://169.254.169.254/latest/meta-data/public-ipv4)
  elif [ -f /var/lib/dhcp/dhclient.eth0.leases ] && grep -q unknown-245 /var/lib/dhcp/dhclient.eth0.leases; then
    # Azure
    external_ip=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text")
  elif [ -f /run/scw-metadata.cache ]; then
    # Scaleway
    external_ip=$(grep "PUBLIC_IP_ADDRESS" /run/scw-metadata.cache | cut -d '=' -f 2)
  elif which dmidecode > /dev/null && dmidecode -s bios-vendor | grep -q Google; then
    # Google Compute Cloud
    external_ip=$(wget -O - -q "http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" --header 'Metadata-Flavor: Google')
  elif [ -n "$1" ]; then
    # Try and determine the external IP from the given hostname
    need_pkg dnsutils
    external_ip=$(dig +short "$1" @resolver1.opendns.com | grep '^[.0-9]*$' | tail -n1)
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

  if ! dpkg -s "${@}" >/dev/null 2>&1; then
    LC_CTYPE=C.UTF-8 apt-get install -yq "${@}"
  fi
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo "Sleeping for 1 second because of dpkg/lock is in use"; sleep 1; done
  while lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo "Sleeping for 1 second because dpkg/lock-frontend in use"; sleep 1; done
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
  if ! echo "$1" | grep -Eq "focal-27"; then err "This script can only install BigBlueButton 2.7 and is meant to be run on Ubuntu 20.04 (focal) server."; fi
  DISTRO=${1%%-*}
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
  if dpkg -l | grep -q apache2-bin; then 
    echo "You must uninstall the Apache2 server first"
    if [ "$SKIP_APACHE_INSTALLED_CHECK" != true ]; then
      exit 1
    fi
  fi
}

# If CAP_SYS_NICE is not available, then the FreeSWITCH systemctl service
# will fail to start, with an error message like "status=214/SETSCHEDULER".
# In this case we need to modify this service so that it does not require a realtime scheduler.
# A similar modification needs to be done to a couple of other services as well,
# like: bbb-html5-frontend@.service, bbb-html5-backend@.service and bbb-webrtc-sfu.service
check_cap_sys_nice() {
  # if we don't detect a SETSCHEDULER error message in the status of the service,
  # then there is nothing to be modified/customized
  { systemctl status freeswitch | grep -q SETSCHEDULER; } || return

  # override /lib/systemd/system/freeswitch.service so that it does not use realtime scheduler
  mkdir -p /etc/systemd/system/freeswitch.service.d
  cat <<HERE > /etc/systemd/system/freeswitch.service.d/override.conf
[Service]
IOSchedulingClass=
IOSchedulingPriority=
CPUSchedulingPolicy=
CPUSchedulingPriority=
HERE

  # override /usr/lib/systemd/system/bbb-html5-frontend@.service
  mkdir -p /etc/systemd/system/bbb-html5-frontend@.service.d
  cat <<HERE > /etc/systemd/system/bbb-html5-frontend@.service.d/override.conf
[Service]
CPUSchedulingPolicy=
HERE

  # override /usr/lib/systemd/system/bbb-html5-backend@.service
  mkdir -p /etc/systemd/system/bbb-html5-backend@.service.d
  cat <<HERE > /etc/systemd/system/bbb-html5-backend@.service.d/override.conf
[Service]
CPUSchedulingPolicy=
HERE

  # override /usr/lib/systemd/system/bbb-webrtc-sfu.service
  mkdir -p /etc/systemd/system/bbb-webrtc-sfu.service.d
  cat <<HERE > /etc/systemd/system/bbb-webrtc-sfu.service.d/override.conf
[Service]
CPUSchedulingPolicy=
HERE

  systemctl daemon-reload
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

install_haproxy() {
  need_pkg haproxy
  if [ -n "$INTERNAL_IP" ]; then
    TURN_IP="$INTERNAL_IP"
  else
    TURN_IP="$IP"
  fi
  HAPROXY_CFG=/etc/haproxy/haproxy.cfg
  cat > "$HAPROXY_CFG" <<END
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
	# An alternative list with additional directives can be obtained from
	#  https://mozilla.github.io/server-side-tls/ssl-config-generator/?server=haproxy
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
	ssl-default-bind-options ssl-min-ver TLSv1.2
	tune.ssl.default-dh-param 2048

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http


frontend nginx_or_turn
  bind *:443,:::443 ssl crt /etc/haproxy/certbundle.pem ssl-min-ver TLSv1.2 alpn h2,http/1.1,stun.turn
  mode tcp
  option tcplog
  tcp-request content capture req.payload(0,1) len 1
  log-format "%ci:%cp [%t] %ft %b/%s %Tw/%Tc/%Tt %B %ts %ac/%fc/%bc/%sc/%rc %sq/%bq captured_user:%{+X}[capture.req.hdr(0)]"
  tcp-request inspect-delay 30s
  # We terminate SSL on haproxy. HTTP2 is a binary protocol. haproxy has to
  # decide which protocol is spoken. This is negotiated by ALPN.
  #
  # Depending on the ALPN value traffic is redirected to either port 82 (HTTP2,
  # ALPN value h2) or 81 (HTTP 1.0 or HTTP 1.1, ALPN value http/1.1 or no value)
  # If no ALPN value is set, the first byte is inspected and depending on the
  # value traffic is sent to either port 81 or coturn.
  use_backend nginx-http2 if { ssl_fc_alpn h2 }
  use_backend nginx if { ssl_fc_alpn http/1.1 }
  use_backend turn if { ssl_fc_alpn stun.turn }
  use_backend %[capture.req.hdr(0),map_str(/etc/haproxy/protocolmap,turn)]
  default_backend turn

backend turn
  mode tcp
  server localhost $TURN_IP:3478

backend nginx
  mode tcp
  server localhost 127.0.0.1:81 send-proxy check

backend nginx-http2
  mode tcp
  server localhost 127.0.0.1:82 send-proxy check
END
  chown root:haproxy "$HAPROXY_CFG"
  chmod 640 "$HAPROXY_CFG"
  for l in {a..z} {A..Z}; do echo "$l" nginx ; done > /etc/haproxy/protocolmap
  chmod 0644 /etc/haproxy/protocolmap

  # cert renewal
  mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat > /etc/letsencrypt/renewal-hooks/deploy/haproxy <<HERE
#!/bin/bash -e

touch /etc/haproxy/certbundle.pem.new
chmod 0640 /etc/haproxy/certbundle.pem.new

{ cat /etc/letsencrypt/live/$HOST/fullchain.pem; echo; cat /etc/letsencrypt/live/$HOST/privkey.pem; } > /etc/haproxy/certbundle.pem.new
chown root:haproxy /etc/haproxy/certbundle.pem.new
mv /etc/haproxy/certbundle.pem.new /etc/haproxy/certbundle.pem
systemctl reload haproxy
HERE
  chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/haproxy
  /etc/letsencrypt/renewal-hooks/deploy/haproxy
}

# This function will install the latest official version of greenlight-v3 and set it as the hosting BigBlueButton default frontend or update greenlight-v3 if installed.
# Greenlight is a simple to use BigBlueButton room manager that offers a set of features useful to online workloads especially virtual schooling.
# https://docs.bigbluebutton.org/greenlight/gl-overview.html
install_greenlight_v3(){
  # This function depends on the following files existing on their expected location so an eager check is done asserting that.
  if [[ -z $SERVLET_DIR  || ! -f $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties || ! -f $CR_TMPFILE || ! -f $BBB_WEB_ETC_CONFIG ]]; then
    err "greenlight-v3 failed to install/update due to unmet requirements, have you followed the recommended steps to install BigBlueButton?"
  fi

  check_root
  install_docker

  # Preparing and checking the environment.
  say "preparing and checking the environment to install/update greenlight-v3..."

  if [ ! -d $GL3_DIR ]; then
    mkdir -p $GL3_DIR && say "created $GL3_DIR"
  fi

  local GL_IMG_REPO=bigbluebutton/greenlight:v3

  say "pulling latest $GL_IMG_REPO image..."
  docker pull $GL_IMG_REPO

  if [ ! -s $GL3_DIR/docker-compose.yml ]; then
    docker run --rm --entrypoint sh $GL_IMG_REPO -c 'cat docker-compose.yml' > $GL3_DIR/docker-compose.yml

    if [ ! -s $GL3_DIR/docker-compose.yml ]; then
      err "failed to create docker compose file - is docker running?"
    fi

    say "greenlight-v3 docker compose file was created"
  fi

  # Configuring Greenlight v3.
  say "checking the configuration of greenlight-v3..."

  local ROOT_URL BIGBLUEBUTTON_URL BIGBLUEBUTTON_SECRET
  ROOT_URL=$(cat "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties" "$CR_TMPFILE" "$BBB_WEB_ETC_CONFIG" | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}' | tail -n 1 )
  BIGBLUEBUTTON_URL=$ROOT_URL/bigbluebutton/
  BIGBLUEBUTTON_SECRET=$(cat "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties" "$CR_TMPFILE" "$BBB_WEB_ETC_CONFIG" | grep -v '#' | grep ^securitySalt | tail -n 1  | cut -d= -f2)

  # Configuring Greenlight v3 docker-compose.yml (if configured no side effect will happen).
  sed -i "s|^\([ \t-]*POSTGRES_PASSWORD\)\(=[ \t]*\)$|\1=$(openssl rand -hex 24)|g" $GL3_DIR/docker-compose.yml # Do not overwrite the value if not empty.

  local PGUSER=postgres # Postgres db user to be used by greenlight-v3.
  local PGTXADDR=postgres:5432 # Postgres DB transport address (pair of (@ip:@port)).
  local RSTXADDR=redis:6379 # Redis DB transport address (pair of (@ip:@port)).
  local PGPASSWORD
  PGPASSWORD=$(sed -ne "s/^\([ \t-]*POSTGRES_PASSWORD=\)\(.*\)$/\2/p" $GL3_DIR/docker-compose.yml) # Extract generated Postgres password.

  if [ -z "$PGPASSWORD" ]; then
    err "failed to retrieve greenlight-v3 DB password - retry to resolve."
  fi

  local DATABASE_URL_ROOT="postgres://$PGUSER:$PGPASSWORD@$PGTXADDR"
  local REDIS_URL_ROOT="redis://$RSTXADDR"

  local PGDBNAME=greenlight-v3-production
  local SECRET_KEY_BASE
  SECRET_KEY_BASE=$(docker run --rm --entrypoint bundle $GL_IMG_REPO exec rails secret)

  if [ -z "$SECRET_KEY_BASE" ]; then
    err "failed to generate greenlight-v3 secret key base - is docker running?"
  fi

  if [ ! -s $GL3_DIR/.env ]; then
    docker run --rm --entrypoint sh $GL_IMG_REPO -c 'cat sample.env' > $GL3_DIR/.env

    if [ ! -s $GL3_DIR/.env ]; then
      err "failed to create greenlight-v3 .env file - is docker running?"
    fi
 
    say "greenlight-v3 .env file was created"
  fi

  # Note for Future Maintainers:
  #   - The configuration steps below are idempotent. They affect the system (configuration) only on the first run.
  #   - Repeating these steps is safe and expected, ensuring a smooth installation and upgrade process for Greenlight v3.
  #   - Caution: Even minor changes might disrupt the idempotent nature, potentially affecting upgrade functionality or system stability.

  # Configuring Greenlight v3 .env file (if already configured this will only update the BBB endpoint and secret).
  cp -v $GL3_DIR/.env $GL3_DIR/.env.old && say "old .env file can be retrieved at $GL3_DIR/.env.old" #Backup

  sed -i "s|^[# \t]*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" $GL3_DIR/.env
  sed -i "s|^[# \t]*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTON_SECRET|"  $GL3_DIR/.env
  sed -i "s|^[# \t]*SECRET_KEY_BASE=[ \t]*$|SECRET_KEY_BASE=$SECRET_KEY_BASE|" $GL3_DIR/.env # Do not overwrite the value if not empty.
  sed -i "s|^[# \t]*DATABASE_URL=[ \t]*$|DATABASE_URL=$DATABASE_URL_ROOT/$PGDBNAME|" $GL3_DIR/.env # Do not overwrite the value if not empty.
  sed -i "s|^[# \t]*REDIS_URL=[ \t]*$|REDIS_URL=$REDIS_URL_ROOT/|" $GL3_DIR/.env # Do not overwrite the value if not empty.

  # Placing greenlight-v3 nginx file, this will enable greenlight-v3 as your BigBlueButton frontend (bbb-fe).
  cp -v $NGINX_FILES_DEST/greenlight-v3.nginx $NGINX_FILES_DEST/greenlight-v3.nginx.old && say "old greenlight-v3 nginx config can be retrieved at $NGINX_FILES_DEST/greenlight-v3.nginx.old" #Backup
  docker run --rm --entrypoint sh $GL_IMG_REPO -c 'cat greenlight-v3.nginx' > $NGINX_FILES_DEST/greenlight-v3.nginx && say "added greenlight-v3 nginx file"

  # For backward compatibility with deployments running greenlight-v2 and haven't picked the patch from COMMIT (583f868).
  # Move any nginx files from greenlight-v2 to the expected location.
  if [ -s /etc/bigbluebutton/nginx/greenlight.nginx ]; then
    mv /etc/bigbluebutton/nginx/greenlight.nginx $NGINX_FILES_DEST/greenlight.nginx && say "found /etc/bigbluebutton/nginx/greenlight.nginx and moved to expected location."
  fi

  if [ -s /etc/bigbluebutton/nginx/greenlight-redirect.nginx ]; then
    mv /etc/bigbluebutton/nginx/greenlight-redirect.nginx $NGINX_FILES_DEST/greenlight-redirect.nginx && say "found /etc/bigbluebutton/nginx/greenlight-redirect.nginx and moved to expected location."
  fi

  if [ -z "$COTURN" ]; then
    # When NGINX is the frontend reverse proxy, 'X-Forwarded-Proto' proxy header will dynamically match the $scheme of the received client request.
    # In case a builtin turn server is installed, then HAPROXY is introduced and it becomes the frontend reverse proxy.
    # NGINX will then act as a backend reverse proxy residing behind of it.
    # HTTPS traffic from the client then is terminated at HAPROXY and plain HTTP traffic is proxied to NGINX.
    # Therefore the 'X-Forwarded-Proto' proxy header needs to correctly indicate that HTTPS traffic was proxied in such scenario.
    # shellcheck disable=SC2016
    sed -i '/X-Forwarded-Proto/s/$scheme/"https"/' $NGINX_FILES_DEST/greenlight-v3.nginx

    if [ -s $NGINX_FILES_DEST/greenlight.nginx ]; then
      # For backward compatibility with deployments running greenlight-v2 and haven't picked the patch from PR (#579).
      # shellcheck disable=SC2016
      sed -i '/X-Forwarded-Proto/s/$scheme/"https"/' $NGINX_FILES_DEST/greenlight.nginx
    fi
  fi

  # For backward compatibility, any already installed greenlight-v2 application will remain but it will not be the default frontend for BigBlueButton.
  # To access greenlight-v2 an explicit /b relative root needs to be indicated, otherwise greenlight-v3 will be served by default.

  # Disabling the greenlight-v2 redirection rule.
  disable_nginx_site greenlight-redirect.nginx && say "found greenlight-v2 redirection rule and disabled it!"

  # Disabling the BigBlueButton default Welcome page frontend.
  disable_nginx_site default-fe.nginx && say "found default bbb-fe 'Welcome' and disabled it!"

  # Adding Keycloak
  if [ -n "$INSTALL_KC" ]; then
      # When attempting to install/update Keycloak let us attempt to create the database to resolve any issues caused by postgres false negatives.
      docker-compose -f $GL3_DIR/docker-compose.yml up -d postgres && say "started postgres"
      wait_postgres_start
      docker-compose -f $GL3_DIR/docker-compose.yml exec -T postgres psql -U postgres -c 'CREATE DATABASE keycloakdb;'
  fi

  if ! grep -q 'keycloak:' $GL3_DIR/docker-compose.yml; then
    # The following logic is expected to run only once when adding Keycloak.
    # Keycloak isn't installed
    if [ -n "$INSTALL_KC" ]; then
      # Add Keycloak
      say "Adding Keycloak..."

      docker-compose -f $GL3_DIR/docker-compose.yml down
      cp -v $GL3_DIR/docker-compose.yml $GL3_DIR/docker-compose.base.yml # Persist working base compose file for admins as a Backup.

      docker run --rm --entrypoint sh $GL_IMG_REPO -c 'cat docker-compose.kc.yml' >> $GL3_DIR/docker-compose.yml

      if ! grep -q 'keycloak:' $GL3_DIR/docker-compose.yml; then
        err "failed to add Keycloak service to greenlight-v3 compose file - is docker running?"
      fi
      say "added Keycloak to compose file"

      KCPASSWORD=$(openssl rand -hex 12) # Keycloak admin password.
      sed -i "s|^\([ \t-]*KEYCLOAK_ADMIN_PASSWORD\)\(=[ \t]*\)$|\1=$KCPASSWORD|g" $GL3_DIR/docker-compose.yml # Do not overwrite the value if not empty.
      sed -i "s|^\([ \t-]*KC_DB_PASSWORD\)\(=[ \t]*\)$|\1=$PGPASSWORD|g" $GL3_DIR/docker-compose.yml # Do not overwrite the value if not empty.

      # Updating Keycloak nginx file.
      cp -v $NGINX_FILES_DEST/keycloak.nginx $NGINX_FILES_DEST/keycloak.nginx.old && say "old Keycloak nginx config can be retrieved at $NGINX_FILES_DEST/keycloak.nginx.old"
      docker run --rm --entrypoint sh $GL_IMG_REPO -c 'cat keycloak.nginx' > $NGINX_FILES_DEST/keycloak.nginx && say "added Keycloak nginx file"
    fi

  else
    # Update Keycloak nginx file only.
    cp -v $NGINX_FILES_DEST/keycloak.nginx $NGINX_FILES_DEST/keycloak.nginx.old && say "old Keycloak nginx config can be retrieved at $NGINX_FILES_DEST/keycloak.nginx.old"
    docker run --rm --entrypoint sh $GL_IMG_REPO -c 'cat keycloak.nginx' > $NGINX_FILES_DEST/keycloak.nginx && say "added Keycloak nginx file"
  fi

  if [ -z "$COTURN" ] && [ -s $NGINX_FILES_DEST/keycloak.nginx ]; then
    # shellcheck disable=SC2016
    sed -i '/X-Forwarded-Proto/s/$scheme/"https"/' $NGINX_FILES_DEST/keycloak.nginx
  fi

  # Update .env file catching new configurations:
  if ! grep -q 'RELATIVE_URL_ROOT=' $GL3_DIR/.env; then
      cat <<HERE >> $GL3_DIR/.env
#RELATIVE_URL_ROOT=/gl

HERE
  fi

  if [ -n "$GL_PATH" ]; then
    sed -i "s|^[# \t]*RELATIVE_URL_ROOT=.*|RELATIVE_URL_ROOT=$GL_PATH|" $GL3_DIR/.env
  fi

  local GL_RELATIVE_URL_ROOT
  GL_RELATIVE_URL_ROOT=$(sed -ne "s/^\([ \t]*RELATIVE_URL_ROOT=\)\(.*\)$/\2/p" $GL3_DIR/.env) # Extract relative URL root path.
  say "Deploying Greenlight on the '${GL_RELATIVE_URL_ROOT:-$GL_DEFAULT_PATH}' path..."

  if [ -n "$GL_RELATIVE_URL_ROOT" ] && [ "$GL_RELATIVE_URL_ROOT" != "$GL_DEFAULT_PATH" ]; then
    sed -i "s|^\([ \t]*location\)[ \t]*\(.*/cable\)[ \t]*\({\)$|\1 $GL_RELATIVE_URL_ROOT/cable \3|" $NGINX_FILES_DEST/greenlight-v3.nginx
    sed -i "s|^\([ \t]*location\)[ \t]*\(@bbb-fe\)[ \t]*\({\)$|\1 $GL_RELATIVE_URL_ROOT \3|" $NGINX_FILES_DEST/greenlight-v3.nginx
  fi

  nginx -qt || err 'greenlight-v3 failed to install/update due to nginx tests failing to pass - if using the official image then please contact the maintainers.'
  nginx -qs reload && say 'greenlight-v3 was successfully configured'

  # Eager pulling images.
  say "pulling latest greenlight-v3 services images..."
  docker-compose -f $GL3_DIR/docker-compose.yml pull

  if check_container_running greenlight-v3; then
    # Restarting Greenlight-v3 services after updates.
    say "greenlight-v3 is updating..."
    say "shutting down greenlight-v3..."
    docker-compose -f $GL3_DIR/docker-compose.yml down
  fi

  say "starting greenlight-v3..."
  docker-compose -f $GL3_DIR/docker-compose.yml up -d
  sleep 5
  say "greenlight-v3 is now installed and accessible on: https://$HOST${GL_RELATIVE_URL_ROOT:-$GL_DEFAULT_PATH}"
  say "To create Greenlight administrator account, see: https://docs.bigbluebutton.org/greenlight/v3/install#creating-an-admin-account"


  if grep -q 'keycloak:' $GL3_DIR/docker-compose.yml; then
    say "Keycloak is installed, up to date and accessible for configuration on: https://$HOST/keycloak/"
    if [ -n "$KCPASSWORD" ];then
      say "Use the following credentials when accessing the admin console:"
      say "   admin"
      say "   $KCPASSWORD"
    fi

    say "To complete the configuration of Keycloak, see: https://docs.bigbluebutton.org/greenlight/v3/external-authentication#configuring-keycloak"
  fi

  return 0;
}

# This function will install and update to the latest official version of BigBlueButton LTI framework.
# BigBlueButton LTI tools framework provides a simple interface to integrate BigBlueButton features into any LTI certified LMS.
install_lti(){
  # This function depends on the following files existing on their expected location so an eager check is done asserting that.
  if [[ -z $SERVLET_DIR  || ! -f $SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties || ! -f $CR_TMPFILE || ! -f $BBB_WEB_ETC_CONFIG ]]; then
    err "BBB LTI framework failed to install/update due to unmet requirements, have you followed the recommended steps to install BigBlueButton?"
  fi

  check_root
  install_docker

  # Preparing and checking the environment.
  say "preparing and checking the environment to install/update BBB LTI framework..."

  if [ ! -d $LTI_DIR ]; then
    mkdir -p $LTI_DIR && say "created $LTI_DIR"
  fi

  BROKER_IMG_REPO=bigbluebutton/bbb-lti-broker

  # Installing/Updating the LTI broker.
  say "pulling latest $BROKER_IMG_REPO image..."
  docker pull $BROKER_IMG_REPO

  if [ ! -s $LTI_DIR/docker-compose.yml ]; then
    docker run --rm --entrypoint sh $BROKER_IMG_REPO -c 'cat docker-compose.yml' > $LTI_DIR/docker-compose.yml

    if [ ! -s $LTI_DIR/docker-compose.yml ]; then
      err "failed to create docker compose file - is docker running?"
    fi

    say "LTI framework docker compose file was created"
  fi

  # Configuring BBB LTI.
  say "prepping the configuration of BBB LTI framework..."

  local ROOT_URL
  ROOT_URL=$(cat "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties" "$CR_TMPFILE" "$BBB_WEB_ETC_CONFIG" | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}' | tail -n 1 )
  BIGBLUEBUTTON_URL=$ROOT_URL/bigbluebutton/
  BIGBLUEBUTTON_SECRET=$(cat "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties" "$CR_TMPFILE" "$BBB_WEB_ETC_CONFIG" | grep -v '#' | grep ^securitySalt | tail -n 1  | cut -d= -f2)

  # Configuring BBB LTI docker-compose.yml (if configured no side effect will happen).
  sed -i "s|^\([ \t-]*POSTGRES_PASSWORD\)\(=[ \t]*\)$|\1=$(openssl rand -hex 24)|g" $LTI_DIR/docker-compose.yml # Do not overwrite the value if not empty.

  say "installing/updating BBB LTI framework Broker and applications..."
  local PGUSER=postgres # Postgres db user to be used by bbb-lti.
  local PGTXADDR=postgres:5432 # Postgres DB transport address (pair of (@ip:@port)).
  local RSTXADDR=redis:6379 # Redis DB transport address (pair of (@ip:@port)).
  local PGPASSWORD
  PGPASSWORD=$(sed -ne "s/^\([ \t-]*POSTGRES_PASSWORD=\)\(.*\)$/\2/p" $LTI_DIR/docker-compose.yml) # Extract generated Postgres password.

  if [ -z "$PGPASSWORD" ]; then
    err "failed to retrieve the LTI framework DB password - retry to resolve."
  fi

  DATABASE_URL_ROOT="postgres://$PGUSER:$PGPASSWORD@$PGTXADDR" # Must be global - expected by install_lti_tool.
  REDIS_URL_ROOT="redis://$RSTXADDR" # Must be global - expected by install_lti_tool.
  BROKER_RELATIVE_URL_ROOT=lti # Must be global - expected by install_lti_tools, will be dynamic in the future.
  APPS_RELATIVE_URL_ROOT=apps # Must be global - expected by install_lti_tools, will be dynamic in the future.

  install_lti_tools || err "BBB LTI framework failed to install/update tools!"

  # Updating BBB LTI framework images.
  say "pulling latest BBB LTI framework services images..."
  docker-compose -f $LTI_DIR/docker-compose.yml pull

  if check_container_running broker; then
    # Restarting BBB LTI framework services after updates.
    say "BBB LTI framework is updating..."
    say "shutting down BBB LTI framework services..."
    docker-compose -f $LTI_DIR/docker-compose.yml down
  fi

  say "starting BBB LTI framework services..."
  docker-compose -f $LTI_DIR/docker-compose.yml up -d

  wait_lti_broker_start

  local LTI_KEY=${LTI_CREDS[0]}
  local LTI_SECRET=${LTI_CREDS[1]}

  say "Setting/updating LTI credentials for LTI KEY: $LTI_KEY..."

  if ! docker-compose -f $LTI_DIR/docker-compose.yml exec -T broker bundle exec rake db:keys:update["$LTI_KEY","$LTI_SECRET"] \
    2> /dev/null 1>&2; then
    docker-compose -f $LTI_DIR/docker-compose.yml exec -T broker bundle exec rake db:keys:add["$LTI_KEY","$LTI_SECRET"] \
      2> /dev/null 1>&2 || err "failed to set LTI credentials $LTI_KEY:$LTI_SECRET."

      say "New LTI credentials for LTI KEY: $LTI_KEY were added!"
  else
    say "LTI credentials for LTI KEY: $LTI_KEY were updated!"
  fi

  say "BBB LTI framework is installed, up to date and accessible on: https://$HOST/$BROKER_RELATIVE_URL_ROOT"
  say "You can refer to your LMS documentation on how to add a LTI application."
  say "The LTI launch links for all of the installed BBB LTI framework applications can be found in https://$HOST/$BROKER_RELATIVE_URL_ROOT."

  return 0;
}

install_lti_tools() {
  # BBB LTI FRAMEWORK COMPONENTS
  if [[ -z $BROKER_IMG_REPO || -z $DATABASE_URL_ROOT || -z $REDIS_URL_ROOT || -z $BROKER_RELATIVE_URL_ROOT || -z $APPS_RELATIVE_URL_ROOT ]]; then
    err "BBB LTI tools installation/update failed due to unmet requirements!"
  fi

  # BBB LTI BROKER setup ↓
  say "installing/updating BBB LTI framework broker..."
  LTI_APP_DIR=$LTI_DIR/broker APP_IMG_REPO=$BROKER_IMG_REPO LOG_NAME='LTI Broker' RELATIVE_URL_ROOT=$BROKER_RELATIVE_URL_ROOT \
  NGINX_NAME=bbb-lti-broker PGDBNAME=bbb_lti_broker install_lti_tool || return 1

  say "BBB LTI Broker is installed, configured and up to date!"
  # BBB LTI TOOLS setup ↓
  say "installing/updating BBB LTI framework apps..."
  LTI_APP_DIR=$LTI_DIR/rooms APP_IMG_REPO=bigbluebutton/bbb-app-rooms LOG_NAME='LTI Rooms' RELATIVE_URL_ROOT=$APPS_RELATIVE_URL_ROOT \
  NGINX_NAME=bbb-app-rooms PGDBNAME=bbb_app_rooms install_lti_tool || return 1

  say "All BBB LTI apps are installed, configured and up to date!"
  # BBB LTI TOOLS registration ↓
  register_lti_tools || return 1

  say "All BBB LTI apps are registered to the LTI framework!"

  return 0;
}

install_lti_tool() {
 # Preparing and checking the environment.
  if [[ -z $LTI_APP_DIR || -z $APP_IMG_REPO || -z $LOG_NAME || -z $RELATIVE_URL_ROOT || -z $NGINX_NAME || -z $PGDBNAME ]]; then
    err "$LOG_NAME installation/update failed due to unmet requirements!"
  fi

  say "preparing and checking the environment to install/update $LOG_NAME..."

  if [ ! -d "$LTI_APP_DIR" ]; then
    mkdir -p "$LTI_APP_DIR" && say "created $LTI_APP_DIR"
  fi

  # Installing/Updating the LTI broker.
  say "pulling latest $APP_IMG_REPO image..."
  docker pull "$APP_IMG_REPO"

  # Configuring BBB LTI.
  say "checking/updating the configuration of $LOG_NAME..."

  local SECRET_KEY_BASE
  SECRET_KEY_BASE=$(docker run --rm --entrypoint bundle "$APP_IMG_REPO" exec rake secret)

  if [ -z "$SECRET_KEY_BASE" ]; then
    err "failed to generate $LOG_NAME secret key base - is docker running?"
  fi

  if [ ! -s "$LTI_APP_DIR"/.env ]; then
    docker run --rm --entrypoint sh "$APP_IMG_REPO" -c 'cat dotenv' > "$LTI_APP_DIR"/.env

    if [ ! -s "$LTI_APP_DIR"/.env ]; then
      err "failed to create $LOG_NAME .env file - is docker running?"
    fi

    say "$LOG_NAME .env file was created"
  fi

  # Note for Future Maintainers:
  #   - The configuration steps below are designed to be idempotent. This means executing these actions will only configure the system once, regardless of how many times they are run.
  #   - Repeating these steps is both safe and expected, ensuring a smooth installation and upgrade process for the BBB LTI framework.
  #   - Caution: Minor changes might alter this idempotent behavior, potentially affecting the upgrade functionality or the stability of the running system.

  # Configuring BBB LTI .env file (if already configured this will only update some expected or safe to change variables).
  cp -v "$LTI_APP_DIR"/.env "$LTI_APP_DIR"/.env.old && say "old $LOG_NAME .env file can be retrieved at $LTI_APP_DIR/.env.old" #Backup

  sed -i "s|^[# \t]*SECRET_KEY_BASE=[ \t]*$|SECRET_KEY_BASE=$SECRET_KEY_BASE|" "$LTI_APP_DIR"/.env # Do not overwrite the value if not empty.
  sed -i "s|^[# \t]*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" "$LTI_APP_DIR"/.env
  sed -i "s|^[# \t]*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTON_SECRET|"  "$LTI_APP_DIR"/.env
  sed -i "s|^[# \t]*URL_HOST=.*$|URL_HOST=$HOST|" "$LTI_APP_DIR"/.env
  sed -i "s|^[# \t]*RELATIVE_URL_ROOT=.*$|RELATIVE_URL_ROOT=$RELATIVE_URL_ROOT|" "$LTI_APP_DIR"/.env
  sed -i "s|^[# \t]*DATABASE_URL=.*myuser:mypass@localhost.*$|DATABASE_URL=$DATABASE_URL_ROOT/$PGDBNAME|" "$LTI_APP_DIR"/.env # Do not overwrite the value if not a default.
  sed -i "s|^[# \t]*DATABASE_URL=[ \t]*$|DATABASE_URL=$DATABASE_URL_ROOT/$PGDBNAME|" "$LTI_APP_DIR"/.env # Do not overwrite the value if not empty.
  sed -i "s|^[# \t]*REDIS_URL=.*myuser:mypass@localhost.*$|REDIS_URL=$REDIS_URL_ROOT/|" "$LTI_APP_DIR"/.env # Do not overwrite the value if not a default.
  sed -i "s|^[# \t]*REDIS_URL=[ \t]*$|REDIS_URL=$REDIS_URL_ROOT/|" "$LTI_APP_DIR"/.env # Do not overwrite the value if not empty.
  sed -i "s|^[# \t]*OMNIAUTH_BBBLTIBROKER_SITE=.*|OMNIAUTH_BBBLTIBROKER_SITE=https://$HOST|" "$LTI_APP_DIR"/.env
  sed -i "s|^[# \t]*OMNIAUTH_BBBLTIBROKER_ROOT=.*|OMNIAUTH_BBBLTIBROKER_ROOT=$BROKER_RELATIVE_URL_ROOT|" "$LTI_APP_DIR"/.env
  sed -i "s|^[# \t]*OMNIAUTH_BBBLTIBROKER_KEY=.*|OMNIAUTH_BBBLTIBROKER_KEY=$(openssl rand -hex 24)|" "$LTI_APP_DIR"/.env # Credentials are rotated on update.
  sed -i "s|^[# \t]*OMNIAUTH_BBBLTIBROKER_SECRET=.*|OMNIAUTH_BBBLTIBROKER_SECRET=$(openssl rand -hex 24)|" "$LTI_APP_DIR"/.env # Credentials are rotated on update.

  # Placing application nginx file.
  say "configuring nginx for $LOG_NAME..."

  cp -v $NGINX_FILES_DEST/"$NGINX_NAME.nginx" $NGINX_FILES_DEST/"$NGINX_NAME.nginx.old" && say "old $LOG_NAME nginx config can be retrieved at $NGINX_FILES_DEST/$NGINX_NAME.nginx.old" # Backup.
  docker run --rm --entrypoint sh "$APP_IMG_REPO" -c 'cat config.nginx' > $NGINX_FILES_DEST/"$NGINX_NAME.nginx" && say "added $LOG_NAME nginx file"

  if [ -z "$COTURN" ]; then
    # When NGINX is the frontend reverse proxy, 'X-Forwarded-Proto' proxy header will dynamically match the $scheme of the received client request.
    # In case a builtin turn server is installed, then HAPROXY is introduced and it becomes the frontend reverse proxy.
    # NGINX will then act as a backend reverse proxy residing behind of it.
    # HTTPS traffic from the client then is terminated at HAPROXY and plain HTTP traffic is proxied to NGINX.
    # Therefore the 'X-Forwarded-Proto' proxy header needs to correctly indicate that HTTPS traffic was proxied in such scenario.
    # shellcheck disable=SC2016
    sed -i '/X-Forwarded-Proto/s/$scheme/"https"/' $NGINX_FILES_DEST/"$NGINX_NAME.nginx"
  fi

  nginx -qt || return 1
  nginx -qs reload && say "$LOG_NAME was successfully configured"

  return 0;
}


register_lti_tools() {
  # Registering/Updating LTI apps.
  wait_lti_broker_start

  # BBB LTI TOOLS registration ↓
  say "Registering All BBB LTI framework apps..."
  LTI_APP_DIR=$LTI_DIR/rooms LOG_NAME='LTI Rooms' APP_NAME=rooms register_lti_tool || return 1

  return 0;
}

wait_lti_broker_start() {
  say "Waiting for the LTI broker to start..."
  docker-compose -f $LTI_DIR/docker-compose.yml up -d broker || err "failed to register LTI framework apps due to LTI broker failling to start - retry to resolve"

  local tries=0
  while ! docker-compose -f $LTI_DIR/docker-compose.yml exec -T broker bundle exec rake db:version 2> /dev/null 1>&2; do
    echo -n .
    sleep 3
    if (( ++tries == 3 )); then
      err "failed to register LTI framework apps due to reaching LTI broker waiting timeout - retry to resolve" 
    fi
  done

  sleep 3 # Optimistically wait for LTI Broker to become ready.

  say "LTI broker is ready!"

  return 0;
}

wait_postgres_start() {
  say "Waiting for the Postgres DB to start..."
  docker-compose -f $GL3_DIR/docker-compose.yml up -d postgres || err "failed to start Postgres service - retry to resolve"

  local tries=0
  while ! docker-compose -f $GL3_DIR/docker-compose.yml exec -T postgres pg_isready 2> /dev/null 1>&2; do
    echo -n .
    sleep 3
    if (( ++tries == 3 )); then
      err "failed to start Postgres due to reaching waiting timeout - retry to resolve" 
    fi
  done

  say "Postgres is ready!"

  return 0;
}

register_lti_tool() {
 # Preparing and checking the environment.
  if [[ -z $LTI_APP_DIR || -z $APP_NAME || -z $LOG_NAME ]]; then
    err "$LOG_NAME registration failed due to unmet requirements!"
  fi

  say "Registering $LOG_NAME..."

  local OAUTH_KEY OAUTH_SECRET RELATIVE_URL_ROOT
  OAUTH_KEY=$(sed -ne "s/^\([ \t]*OMNIAUTH_BBBLTIBROKER_KEY=\)\(.*\)$/\2/p" "$LTI_APP_DIR"/.env) # Extract the LTI app OAUTH key.
  OAUTH_SECRET=$(sed -ne "s/^\([ \t]*OMNIAUTH_BBBLTIBROKER_SECRET=\)\(.*\)$/\2/p" "$LTI_APP_DIR"/.env) # Extract LTI app OAUTH secret.
  RELATIVE_URL_ROOT=$(sed -ne "s/^\([ \t]*RELATIVE_URL_ROOT=\)\(.*\)$/\2/p" "$LTI_APP_DIR"/.env) # Extract LTI app relative URL root path.

  if [ -z "$OAUTH_KEY" ] || [ -z "$OAUTH_SECRET" ] ; then
    err "failed to retrieve the $LOG_NAME OAUTH credentials - retry to resolve."
  fi

  local CALLBACK_URI_SUFFIX=auth/bbbltibroker/callback
  local CALLBACK_URI=https://$HOST/$RELATIVE_URL_ROOT/$APP_NAME/$CALLBACK_URI_SUFFIX

  if ! check_container_running broker; then
    err "failed to register $LOG_NAME due to LTI broker not running - retry to resolve."
  fi

  if ! docker-compose -f $LTI_DIR/docker-compose.yml exec -T broker bundle exec rake db:apps:show["$APP_NAME"] \
    2> /dev/null 1>&2; then
    docker-compose -f $LTI_DIR/docker-compose.yml exec -T broker bundle exec rake db:apps:add["$APP_NAME","$CALLBACK_URI","$OAUTH_KEY","$OAUTH_SECRET"] \
      2> /dev/null 1>&2 && say "$LOG_NAME was successfully registered."
  else
    docker-compose -f $LTI_DIR/docker-compose.yml exec -T broker bundle exec rake db:apps:update["$APP_NAME","$CALLBACK_URI","$OAUTH_KEY","$OAUTH_SECRET"] \
      2> /dev/null 1>&2 && say "$LOG_NAME was successfully updated."
  fi

  return 0;
}

# Given a container name as $1, this function will check if there's a match for that name in the list of running docker containers on the system.
# The result will be bound to $?.
check_container_running() {
  docker ps | grep -q "$1" || return 1;

  return 0;
}

# Given a filename as $1, if file exists under $sites_dir then the file will be suffixed with '.disabled'.
# sites_dir points to BigBlueButton nginx sites, when suffixed with '.disabled' nginx will not include the site on reload/restart thus disabling it.
disable_nginx_site() {
  local site_path="$1"

  if [ -z "$site_path" ]; then
    return 1;
  fi

  if [ -f $NGINX_FILES_DEST/"$site_path" ]; then
    mv $NGINX_FILES_DEST/"$site_path" $NGINX_FILES_DEST/"$site_path.disabled" && return 0;
  fi

  return 1;
}

install_docker() {
  need_pkg apt-transport-https ca-certificates curl gnupg-agent software-properties-common openssl

  # Install Docker
  if ! apt-key list | grep -q Docker; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  fi

  if ! dpkg -l | grep -q docker-ce; then
    echo "deb [ arch=amd64 ] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    
    add-apt-repository --remove\
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

    apt-get update
    need_pkg docker-ce docker-ce-cli containerd.io
  fi
  if ! which docker; then err "Docker did not install"; fi

  # Purge older docker compose if exists.
  if dpkg -l | grep -q docker-compose; then
    apt-get purge -y docker-compose
  fi

  if [ ! -x /usr/local/bin/docker-compose ]; then
    curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi

  # Ensuring docker is running
  if ! docker version > /dev/null ; then
    # Attempting to auto resolve by restarting docker socket and engine.
    systemctl restart docker.socket docker.service
    sleep 5

    docker version > /dev/null || err "docker is failing to restart, something is wrong retry to resolve - exiting"
    say "docker is running!"
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

    if [[ -f "/etc/letsencrypt/live/$HOST/fullchain.pem" ]] && [[ -f "/etc/letsencrypt/renewal/$HOST.conf" ]] \
        && ! grep -q '/var/www/bigbluebutton-default/assets' "/etc/letsencrypt/renewal/$HOST.conf"; then
      sed -i -e 's#/var/www/bigbluebutton-default#/var/www/bigbluebutton-default/assets#' "/etc/letsencrypt/renewal/$HOST.conf"
      if ! certbot renew; then
        err "Let's Encrypt SSL renewal request for $HOST did not succeed - exiting"
      fi
    fi
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
    root   /var/www/bigbluebutton-default/assets;
    try_files \$uri @bbb-fe;
  }
}
HERE
      systemctl restart nginx
    fi

    if [ -z "$PROVIDED_CERTIFICATE" ]; then
      if ! certbot --email "$EMAIL" --agree-tos --rsa-key-size 4096 -w /var/www/bigbluebutton-default/assets/ \
           -d "$HOST" --deploy-hook "systemctl reload nginx" "${LETS_ENCRYPT_OPTIONS[@]}" certonly; then
        systemctl restart nginx
        err "Let's Encrypt SSL request for $HOST did not succeed - exiting"
      fi
    else
      # Place your fullchain.pem and privkey.pem files in /local/certs/ and bbb-install.sh will deal with the rest.
      mkdir -p "/etc/letsencrypt/live/$HOST/"
      ln -s /local/certs/fullchain.pem "/etc/letsencrypt/live/$HOST/fullchain.pem"
      ln -s /local/certs/privkey.pem "/etc/letsencrypt/live/$HOST/privkey.pem"
    fi
  fi

  if [ -z "$COTURN" ]; then
    # No COTURN credentials provided, setup a local TURN server
  cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server_tokens off;

server {
  listen 80;
  listen [::]:80;
  server_name $HOST;

  location ^~ / {
    return 301 https://\$server_name\$request_uri; #redirect HTTP to HTTPS
  }

  location ^~ /.well-known/acme-challenge/ {
    allow all;
    default_type "text/plain";
    root /var/www/bigbluebutton-default/assets;
  }

  location = /.well-known/acme-challenge/ {
    return 404;
  }
}

set_real_ip_from 127.0.0.1;
real_ip_header proxy_protocol;
real_ip_recursive on;
server {
  # this double listening is intended. We terminate SSL on haproxy. HTTP2 is a
  # binary protocol. haproxy has to decide which protocol is spoken. This is
  # negotiated by ALPN.
  #
  # Depending on the ALPN value traffic is redirected to either port 82 (HTTP2,
  # ALPN value h2) or 81 (HTTP 1.0 or HTTP 1.1, ALPN value http/1.1 or no value)

  listen 127.0.0.1:82 http2 proxy_protocol;
  listen [::1]:82 http2;
  listen 127.0.0.1:81 proxy_protocol;
  listen [::1]:81;
  server_name $HOST;

  # nginx does not know its external port/protocol behind haproxy, so use relative redirects.
  absolute_redirect off;
    
  # HSTS (uncomment to enable)
  #add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

  access_log  /var/log/nginx/bigbluebutton.access.log;

  # This variable is used instead of \$scheme by bigbluebutton nginx include
  # files, so \$scheme can be overridden in reverse-proxy configurations.
  set \$real_scheme "https";

  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default/assets;
    try_files \$uri @bbb-fe;
  }

  # Include specific rules for record and playback
  include /etc/bigbluebutton/nginx/*.nginx;
}
HERE
  else
    # We've been given COTURN credentials, so HAPROXY is not installed for local TURN server
  cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server_tokens off;

server {
  listen 80;
  listen [::]:80;
  server_name $HOST;

  location ^~ / {
    return 301 https://\$server_name\$request_uri; #redirect HTTP to HTTPS
  }

  location ^~ /.well-known/acme-challenge/ {
    allow all;
    default_type "text/plain";
    root /var/www/bigbluebutton-default/assets;
  }

  location = /.well-known/acme-challenge/ {
    return 404;
  }
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
    ssl_dhparam /etc/nginx/ssl/ffdhe2048.pem;
    
    # HSTS (comment out to enable)
    #add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

  access_log  /var/log/nginx/bigbluebutton.access.log;

  # This variable is used instead of \$scheme by bigbluebutton nginx include
  # files, so \$scheme can be overridden in reverse-proxy configurations.
  set \$real_scheme \$scheme;

  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default/assets;
    try_files \$uri @bbb-fe;
  }

  # Include specific rules for record and playback
  include /etc/bigbluebutton/nginx/*.nginx;
}
HERE

    if [[ ! -f /etc/nginx/ssl/ffdhe2048.pem ]]; then
      cat >/etc/nginx/ssl/ffdhe2048.pem <<"HERE"
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----
HERE
    fi
    if [[ -f /etc/nginx/ssl/dhp-4096.pem ]]; then
      rm /etc/nginx/ssl/dhp-4096.pem
    fi
  fi
# Create the default Welcome page BigBlueButton Frontend unless it exists.
if [[ ! -f /usr/share/bigbluebutton/nginx/default-fe.nginx && ! -f /usr/share/bigbluebutton/nginx/default-fe.nginx.disabled ]]; then
cat <<HERE > /usr/share/bigbluebutton/nginx/default-fe.nginx
# Default BigBlueButton Landing page.

location @bbb-fe {
  index  index.html index.htm;
  expires 1m;
}

HERE
fi

  # Configure rest of BigBlueButton Configuration for SSL
  xmlstarlet edit --inplace --update '//param[@name="wss-binding"]/@value' --value "$IP:7443" /opt/freeswitch/conf/sip_profiles/external.xml
 
  # shellcheck disable=SC1091
  eval "$(source /etc/bigbluebutton/bigbluebutton-release && declare -p BIGBLUEBUTTON_RELEASE)"
  if [[ $BIGBLUEBUTTON_RELEASE == 2.2.* ]] && [[ ${BIGBLUEBUTTON_RELEASE#*.*.} -lt 29 ]]; then
    sed -i "s/proxy_pass .*/proxy_pass https:\/\/$IP:7443;/g" /usr/share/bigbluebutton/nginx/sip.nginx
  else
    # Use nginx as proxy for WSS -> WS (see https://github.com/bigbluebutton/bigbluebutton/issues/9667)
    yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.media.sipjsHackViaWs true
    sed -i "s/proxy_pass .*/proxy_pass http:\/\/$IP:5066;/g" /usr/share/bigbluebutton/nginx/sip.nginx
    xmlstarlet edit --inplace --update '//param[@name="ws-binding"]/@value' --value "$IP:5066" /opt/freeswitch/conf/sip_profiles/external.xml
  fi

  sed -i 's/^bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties"
  if [ -f "$BBB_WEB_ETC_CONFIG" ]; then
    sed -i 's/^bigbluebutton.web.serverURL=http:/bigbluebutton.web.serverURL=https:/g' "$BBB_WEB_ETC_CONFIG"
  fi

  yq w -i /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml playback_protocol https
  chmod 644 /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml 

  # Update Greenlight (if installed) to use SSL
  for gl_dir in ~/greenlight $GL3_DIR;do
    if [ -f "$gl_dir"/.env ]; then
      if ! grep ^BIGBLUEBUTTON_ENDPOINT "$gl_dir"/.env | grep -q https; then
        if [[ -z $BIGBLUEBUTTON_URL ]]; then
          BIGBLUEBUTTON_URL=$(cat "$SERVLET_DIR/WEB-INF/classes/bigbluebutton.properties" "$CR_TMPFILE" "$BBB_WEB_ETC_CONFIG" | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}' | tail -n 1 )/bigbluebutton/
        fi

        sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" ~/greenlight/.env
        docker-compose -f "$gl_dir"/docker-compose.yml down
        docker-compose -f "$gl_dir"/docker-compose.yml up -d
      fi
    fi
  done

  TARGET=/usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml
  if [ -f $TARGET ]; then
    if grep -q kurentoIp $TARGET; then
      # 2.0
      yq w -i $TARGET kurentoIp "$IP"
    else
      # 2.2
      yq w -i $TARGET kurento[0].ip "$IP"
      yq w -i $TARGET freeswitch.ip "$IP"

      if [[ $BIGBLUEBUTTON_RELEASE == 2.2.* ]] && [[ ${BIGBLUEBUTTON_RELEASE#*.*.} -lt 29 ]]; then
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

  systemctl reload nginx
}

configure_coturn() {
  TURN_XML=/etc/bigbluebutton/turn-stun-servers.xml

  if [ -z "$COTURN" ]; then
    # the user didn't pass '-c', so use the local TURN server's host
    COTURN_HOST=$HOST
  fi

  cat <<HERE > $TURN_XML
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.springframework.org/schema/beans
        http://www.springframework.org/schema/beans/spring-beans-2.5.xsd">

    <!-- 
         We need turn0 for FireFox to workaround its limited ICE implementation.
         This is UDP connection.  Note that port 3478 must be open on this BigBlueButton
         and reachable by the client.

         Also, in 2.5, we previously defined turn:\$HOST:443?transport=tcp (not 'turns') 
         to workaround a bug in Safari's handling of Let's Encrypt. This bug is now fixed
         https://bugs.webkit.org/show_bug.cgi?id=219274, so we omit the 'turn' protocol over
         port 443.
     -->
    <bean id="turn0" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="$COTURN_SECRET"/>
        <constructor-arg index="1" value="turn:$COTURN_HOST:3478"/>
        <constructor-arg index="2" value="86400"/>
    </bean>
    <bean id="turn1" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="$COTURN_SECRET"/>
        <constructor-arg index="1" value="turns:$COTURN_HOST:443?transport=tcp"/>
        <constructor-arg index="2" value="86400"/>
    </bean>
    
    <bean id="stunTurnService"
            class="org.bigbluebutton.web.services.turn.StunTurnService">
        <property name="stunServers">
            <set>
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

  chown root:bigbluebutton "$TURN_XML"
  chmod 640 "$TURN_XML"
}


install_coturn() {
  apt-get update
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade

  need_pkg software-properties-common certbot

  need_pkg coturn

  if [ -n "$INTERNAL_IP" ]; then
    SECOND_ALLOWED_PEER_IP="allowed-peer-ip=$INTERNAL_IP"
  fi
  # check if this is still the default coturn config file. Replace it in this case.
  if grep "#static-auth-secret=north" /etc/turnserver.conf > /dev/null ; then
    COTURN_SECRET="$(openssl rand -base64 32)"
    cat <<HERE > /etc/turnserver.conf
listening-port=3478

listening-ip=${INTERNAL_IP:-$IP}
relay-ip=${INTERNAL_IP:-$IP}

min-port=32769
max-port=65535
verbose

fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=$COTURN_SECRET
realm=$HOST

keep-address-family

no-cli
no-tlsv1
no-tlsv1_1

# Block connections to IP ranges which shouldn't be reachable
no-loopback-peers
no-multicast-peers


# we only need to allow peer connections from the machine itself (from mediasoup or freeswitch).
denied-peer-ip=0.0.0.0-255.255.255.255
denied-peer-ip=::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
allowed-peer-ip=$IP
$SECOND_ALLOWED_PEER_IP

HERE
    chown root:turnserver /etc/turnserver.conf
    chmod 640 /etc/turnserver.conf
  else
    # fetch secret for later setting up in BBB turn config
    COTURN_SECRET="$(grep static-auth-secret= /etc/turnserver.conf |cut -d = -f 2-)"
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
# AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=
ExecStart=/usr/bin/turnserver -c /etc/turnserver.conf --pidfile= --no-stdout-log --simple-log --log-file /var/log/turnserver/turnserver.log
Restart=always
HERE

  systemctl daemon-reload
  systemctl restart coturn
  configure_coturn
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
