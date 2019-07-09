
![bbb-install.sh](images/bbb-install.png?raw=true "bbb-install.sh")

# bbb-install

`bbb-install.sh` is a BASH shell script that automates the step-by-step instructions for installing and configuring a BigBlueButton 2.2 server (referred hereafter as simply BigBlueButton 2.2). 

Depending on the speed of your server and your network, `bbb-install.sh` can have your BigBlueButton server ready for use in about 15 minutes.

For example, want to install BigBlueButton 2.2 on a Ubuntu 16.04 64-bit server with a public IP address, SSH into your server and run the following command as root:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220-beta
~~~

This command will download and run `bbb-install.sh` which, in turn, reads the `-v xenial-220-beta` to install BigBlueButton 2.2 and configure it using the server's public IP address.

Note: If your server is behind firewall -- such as behind a corporate firewall or behind an AWS Security Group -- you will need to manually configure the firewall to forward [specific internet connections](#configuring-the-firewall) to the BigBlueButton server before you can access it.

When the install will finish and you'll see a message that gives a URL to test your newly setup BigBlueButton server.

~~~
# Warning: The API demos are installed and accessible from:
#
#    http://xxx.xxx.xxx.xxx/demo/demo1.jsp
#
# These API demos allow anyone to access your server without authentication
# to create/manage meetings and recordings. They are for testing purposes only.
# If you are running a production system, remove them by running:
#
#    sudo apt-get purge bbb-demo
~~~

Since the default installation configures BigBlueButton using the server's external IP address, and not with hostname + transport level security (TLS) or secure socket layer (SSL) certificate, you won't be able to use WebRTC as browsers now require a TLS/SSL certificate.

When you open the URL, you should see a login to join the meeting `Demo Meeting`.

![bbb-install.sh](images/html5-join.png?raw=true "HTML5 Page")

Enter your name and click Join.  The BigBlueButton client should load and prompt you to join the audio.

![bbb-install.sh](images/html5.png?raw=true "HTML5 Client")

While this default setup is good for testing, you *really* want to have the server configured with a TLS/SSL certificate + hostname.  The sections below show how to do all this using a single `bbb-install.sh` command.


## Getting ready
Before running `bbb-install.sh`, we _strongly_ recommend that you

  * read through these docs, 
  * ensure your server meets the [minimal server requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements), and
  * setup a fully qualified domain name (FQDN), such as `bbb.example.com`, that resolves to the external IP address of your server.

To setup a FQDN, you need to purchase a domain name from a domain name system (DNS) provider, such as [GoDaddy](https://godaddy.com) or [Network Solutions](https://networksolutions.com), and use their tools to setup a FQDN (such as `bbb.example.com` that points to the public IP address of your server.  More specifically, you need to create an `A Record` that points to the public IP address.  Check the documentation of your DNS provider for details on how to do this.

With a FQDN domain name place, you can pass a few additional parameters to `bbb-install.sh` to have it

  * a 4096 bit TLS/SSL certificate from Let's Encrypt (we love Let's Encrypt), 
  * the latest build of the HTML5 client, and 
  * [Greenlight](http://docs.bigbluebutton.org/greenlight/gl-overview.html), a simple front-end that enables users to setup rooms, hold meetings, and manage recordings, and enables you (the administrator) to create and manage user accounts.

Also, when your server is configured with an TLS/SSL certificate, users can use FireFox and Chrome (recommend browsers) to share audio and video and screens using the browser's built-in support for web real-time communication (WebRTC). 

The full source code for `bbb-install.sh` is [here](https://github.com/bigbluebutton/bbb-install).  To make it easy for anyone to run the script with a single command, we host the latest version of the script at `https://ubuntu.bigbluebutton.org/bbb-install.sh`.


### Server choices

There are many hosting companies that will provide you both virtual and dedicated servers.  We list a few popular choices below.  Note: We are not making any recommendations here, just listing some of the popular choices.

For quick setup, [Digital Ocean](https://www.digitalocean.com/) offers both virtual servers with Ubuntu 16.04 64-bit and a single public IP address (no firewall).  [Hetzner](https://hetzner) offers dedicated servers with single IP address.

Other companies, such as [ScaleWay](https://www.scaleway.com/) (choose either Bare Metal or Pro servers) and [Google Compute Engine](https://cloud.google.com/compute/) offer servers that are setup behind network address translation (NAT).  That is, they have both an internal and external IP address.  When installing on these servers, the `bbb-install.sh` will detect the internal/external addresses and configure BigBlueButton accordingly.  

Another populare choice is [Amazon Elastic Compute Cloud](https://aws.amazon.com/ec2).  We recommend a `c5.xlarge` (or larger) instance.  All EC2 servers are, by default, is behind a firewall (which Amazon calls a `security group`). You will need to manually configure he security group before installing BigBlueButton (we provide steps in the next section).  

Finally, if `bbb-install.sh` is unable to configure your server behind NAT, we recommend going through the [step-by-step](http://docs.bigbluebutton.org/2.2/install.html) for installing BigBlueButton.  (Going through the steps is also a good way to understand more about how BigBlueButton works).


### Configuring the firewall

If you want to install BigBlueButton on a server behind a firewall, such an Amazon's EC2 instance, you first need to configure the firewall to forward incoming traffic on the following ports:

  * TCP/IP port 22 (for SSH)
  * TCP/IP ports 80/443 (for HTTP/HTTPS)
  * TCP/IP port 1935 (for RTMP)
  * UDP ports in the range 16384 - 32768 (for FreeSWITCH/HTML5 client RTP streams)

Amazon calls the firewall for EC2 a 'security group'.   Here's a screen shot how the EC2 security group configuration should look after configuring it to forward incoming traffic on the above ports:

![Security Group](images/security-group.png?raw=true "Security Group")

If you are using EC2, you need to assign your server an [Elastic IP address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html) to prevent it from getting a new IP address on reboot.

### Installation Videos

Using Digital Ocean as an example, put together this video to get you going quickly: [Using bbb-install.sh to setup BigBlueButton on Digital Ocean](https://youtu.be/D1iYEwxzk0M).

Using Amazon EC2, see [Install using bbb-install.sh on EC2](https://youtu.be/-E9WIrH_yTs).

# Command options

You can get help by passing the `-h` option.

~~~
$ wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -h
Installer script for setting up a BigBlueButton 2.2 server.

This script also supports installation of a separate coturn (TURN) server on a separate server.

USAGE:
    bbb-install.sh [OPTIONS]

OPTIONS (install BigBlueButton):

  -v <version>           Install given version of BigBlueButton (e.g. 'xenial-220-beta') (required)

  -s <hostname>          Configure server with <hostname>
  -e <email>             Email for Let's Encrypt certbot
  -g                     Install GreenLight

  -c <hostname>:<secret> Configure with coturn server at <hostname> using <secret>
  -g                     Install GreenLight

  -p <host>              Use apt-get proxy at <host>

  -h                     Print help

OPTIONS (install coturn):

  -c <hostname>:<secret> Configure coturn with <hostname> and <secret> (required)
  -e <email>             Email for Let's Encrypt certbot (required)


EXAMPLES

Setup a BigBlueButton server

    ./bbb-install.sh -v xenial-220-beta
    ./bbb-install.sh -v xenial-220-beta -s bbb.example.com -e info@example.com
    ./bbb-install.sh -v xenial-220-beta -s bbb.example.com -e info@example.com -g
    ./bbb-install.sh -v xenial-220-beta -s bbb.example.com -e info@example.com -g -c turn.example.com:1234324

Setup a coturn server

    ./bbb-install.sh -c turn.example.com:1234324 -e info@example.com

SUPPORT:
     Source: https://github.com/bigbluebutton/bbb-install
   Commnity: https://bigbluebutton.org/support

~~~

## Install and configure with an IP address only

To install BigBlueButton 2.2 (no hostname or TLS/SSL certificate):

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220-beta
~~~

That's it.  The installation should finish in about 15 minutes (depending on the server's internet connection) with the following message:

~~~
** Potential problems described below **

......
# Warning: The API demos are installed and accessible from:
#
#    http://xxx.xxx.xxx.xxx/demo/demo1.jsp
#
# These API demos allow anyone to access your server without authentication
# to create/manage meetings and recordings. They are for testing purposes only.
# If you are running a production system, remove them by running:
#
#    sudo apt-get purge bbb-demo
~~~

The script also installs the `bbb-demo` package so you can immediately test out the install.  If you want to remove the API demos, use the command

~~~
sudo apt-get purge bbb-demo
~~~

If you want to use this server with an third-party integration, such as Moodle, you can get the BigBlueButton server's hostname and shared secret with the command `sudo bbb-conf --secret`.

~~~
# bbb-conf --secret

       URL: http://xxx.xxx.xxx.xxx/bigbluebutton/
    Secret: yyy

      Link to the API-Mate:
      http://mconf.github.io/api-mate/#server=http://xxx.xxx.xxx.xxx/bigbluebutton/&sharedSecret=yyy
~~~

Since this default use of `bbb-install.sh` does not configure a SSL/TLS certificate, while you can login to the server, you won't be able to share audio/video as WebRTC requires a SSL/TLS certificate.

## Install with SSL/TLS

Before `bbb-install.sh` can install a SSL/TLS certificate, you will need to provide two pieces of information
   * a fully qualified domain name (FQDN), such as `bbb.example.com`, that resolves to the public IP address of your server, and 
   * an e-mail address.
   
When you have setup the FQDN, check that it correctly resolves to the external IP address of the server using the `dig` command.

~~~
dig bbb.example.com @8.8.8.8
~~~

Note: we're using `bbb.example.com` as an example hostname, you would substitute your real hostname for the check (and for the commands below).

With just these two pieces of information -- FQDN and e-mail address -- you can use `bbb-install.sh` to automate the configuration of BigBlueButton server with an TLS/SSL certificate.  For example, to install BigBlueButton 2.2 with a TLS/SSL certificate from Let's Encrypt using `bbb.example.com` and `info@example.com`, enter the command

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220-beta -s bbb.example.com -e info@example.com
~~~

(again, you would substitute `bbb.example.com` and `info@example.com` with your server's FQDN and your e-mail address).

The `bbb-install.sh` script will also install a cron job that automatically news the Let's Encrypt certificate so it doesn't expire.  Cool.


## Install Greenlight

[Greenlight](https://docs.bigbluebutton.org/greenlight/gl-overview.html) is a simple front-end for BigBlueButton written in Ruby on Rails.  It lets users create accounts, have permanent rooms, and manage their recordings.  It lets you, as the administrator, also manage the user accounts (such as approve or deny users).

You can install [Greenlight](http://docs.bigbluebutton.org/install/green-light.html) by adding the `-g` option.

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220-beta -s bbb.example.com -e info@example.com -g
~~~

Once Greenlight is installed, it redirects the default home page to Greenlight.  You can also configure GreenLight to use [OAuth2 authentication](http://docs.bigbluebutton.org/greenlight/gl-customize.html).

To launch Greenlight, simply the URL of your server, such as `https://bbb.example.com/`.  You should see the Greenlight landing page.

![bbb-install.sh](images/greenlight.png?raw=true "Greenlight")


## Do everything with a single command

If you want to setup BigBlueButton 2.2 with a TLS/SSL certificate, HTML5 client, and GreenLight, you can do this all with a single command:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220-beta -s bbb.example.com -e info@example.com -g
~~~

Furthermore, you can re-run the same command later to update your server to the latest version of BigBlueButton 2.2.  We announce updates to BigBlueButton to the [bigbluebutton-dev](https://groups.google.com/forum/#!forum/bigbluebutton-dev) mailing list.


# Install a TURN server

You can use `bbb-install.sh` to automate the steps to [setup a TURN server for BigBlueButton](http://docs.bigbluebutton.org/install/install.html#setup-a-turn-server).  

Note: This step is optional, but recommended if your BigBlueButton server is publically available on the internet and will be accessed by users who may be behind restrictive firewalls.

BigBlueButton normally requires a wide range of UDP ports to be available for WebRTC communication. In some network restricted sites or development environments, such as those behind NAT or a firewall that restricts outgoing UDP connections, users may be unable to make outgoing UDP connections to your BigBlueButton server.  

The TURN protocol is designed to allow UDP-based communication flows like WebRTC to bypass NAT or firewalls by having the client connect to the TURN server, and then have the TURN server connect to the destination on their behalf.

You need a separate server (not the BigBlueButton server) to setup as a TURN server, specifically you need

  * a Ubuntu 18.04 server with a public IP address

We recommend Ubuntu 18.04 as it has a later version of [coturn](https://github.com/coturn/coturn) than Ubuntu 16.04.  Also, this TURN server does not need to be very powerful as it will only relay communications from the BigBlueButton client to the BigBlueButton server when necessary.  A dual core server on Digital Ocean, for example, which offers servers with public IP addresses, is a good choce.

Next, to configure the TURN server you need:
  
  * a fully qualified domain name (FQDN) with a DNS entry that resolves to the external public IP address of the TURN server, 
  * a e-mail addres for Let's Encrypt, and
  * a secret key (it can be 8 to 16 character random string that you create).

With the above information, you can setup a TURN server for BigBlueButton using `bbb-install.sh` as follows

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -c <FQDN>:<SECRET> -e <EMAIL>
~~~

Note, we've omitted the `-v` option, which causes `bbb-install.sh` to just install and cofigure coturn.  For example, using `turn.example.com` as the FQDN, `1234abcd` as the shared secret, and `info@example.com` as the email addres, you can setup a TURN server for BigBlueButton using the command

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -c turn.example.com:1234abcd -e info@example.com
~~~

`bbb-install.sh` uses Let's Encrypt to configure coturn to use a SSL certificate.  With a SSL certificate in place, coturn can relay access to your BigBlueButton server via TCP/IP on port 443.  This means if a user is behind a restrictive firewall that blocks all outgoing UDP connections, the TURN server can accept connections from the user via TCP/IP on port 443 and relay the data to your BigBlueButton server via UDP.

With the TURN server in place, you can configure your BigBlueButton server to use the TURN server by running the `bbb-install.sh` command again and adding the same `-c <FQDN>:<SECRET>`.  For example, 

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220-beta -s bbb.example.com -e info@example.com -g -c turn.example.com:1234abcd
~~~

You can re-use a single TURN server for multiple BigBlueButton installations.

# Next Steps

If you intend to use this server for production you should uninstall the API demos using the command

~~~
apt-get purge bbb-demo
~~~

You can also do a number of [customizations](http://docs.bigbluebutton.org/2.2/customize.html) to your server as well.

## Troubleshooting

### Greenlight not running

If on first install Greenlight gives you a `500 error` when accessing it, you can [restart Greenlight](http://docs.bigbluebutton.org/install/greenlight-v2.html#if-you-ran-greenlight-using-docker-run).

### tomcat7 not running 

If on the initial install you see

~~~
# Not running:  tomcat7 or grails LibreOffice
~~~

just run `sudo bbb-conf --check` again.  Tomcat7 may take a bit longer to start up and isn't running when the first time you run `sudo bbb-conf --check`.

### Getting Help

If you have feedback on the script, or need help using it, please post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) mailing list with details of the issue (and include related information such as steps to reproduce the error).

If you encounter an error with the script (such as it not completing or throwing an error), please open [GitHub issue](https://github.com/bigbluebutton/bbb-install/issues) and provide steps to reproduce the issue.


# Limitations

If you are running your BigBlueButton behind a firewall, such as on EC2, this script will not configure your firewall.  You'll need to [configure the firewall](#configuring-the-firewall) manually.


