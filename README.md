
![bbb-install.sh](images/bbb-install.png?raw=true "bbb-install.sh")

# bbb-install

`bbb-install.sh` is a BASH shell script that lets you install [BigBlueButton 2.0](http://docs.bigbluebutton.org/overview/overview.html) with a single command in about 15 minutes.

For example, to install BigBlueButton 2.0 on an Ubuntu 16.04 64-bit server, login to the server and run the following command as root:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 
~~~

This will download the `bbb-install.sh` script and execute it with the parameter `-v xenial-200`.  

If the server is behind firewall -- such as behind a corporate firewall or behind an AWS Security Group -- you will need to configure the firewall to forward [specific internet connections](#configuring-the-firewall) to the BigBlueButton server before users can access it.

When the script finishes, you should see a message that gives you a URL to login and test BigBlueButton.

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

To test the server, open the URL using FireFox.  Why FireFox?  In this basic setup the server does not have a secure socket layer (SSL) certificate.  Fortunately, FireFox allows you to use web real-time connection (WebRTC) without an SSL certificate.

![bbb-install.sh](images/index.png?raw=true "Index Page")

You should see the default welcome page.  Enter your name and click Join.  BigBlueButton 2.0 should then load and prompt you to join the audio.

![bbb-install.sh](images/join-audio.png?raw=true "Join Audio")

At this point you have a full BigBlueButton server ready to use. But, While this basic setup is good for testing and development, you'll really want to configure the server with a fully qualified domain name (FQDN) and a SSL certificate for better security.  

The sections below show how to do this using `bbb-install.sh` and a few additional parameters.


## Overview

`bbb-install.sh` is a BASH shell script that automates the [step-by-step installation steps](http://docs.bigbluebutton.org/install/install.html) for installing and configuring BigBlueButton 2.0. 

Of course, going through the step-by-step instructions is recommended if you want to understand what `bbb-install.sh` is doing.  But if you want to setup a production ready server with SSL certificate, `bbb-install.sh` can save you a lot of time.

Before running the script, we strongly recommend you do two steps

  * ensure the server meets the [minimal server requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements), and
  * setup a fully qualified domain name (FQDN), such as `bbb.example.com`, that resolves to the external IP address of your server.

To setup the domain name, you need to use a domain name registry (DNS), such as [GoDaddy](https://godaddy.com) or [Network Solutions](https://networksolutions.com)  to create an `A Record` that points to the external IP address of your server.  Your DNS provider will provide lots of documentation on how to do this.

With a FQDN and DNS entry in place,  you can then use `bbb-install.sh` to install

  * a 4096 bit secure socket layers (SSL) certificate from Let's Encrypt (we love Let's Encrypt), 
  * the latest build of the HTML5 client, and 
  * the Green Light front-end to enable users to create accounts and manage rooms.

When BigBlueButton is configured with an SSL certificate, the browsers Chrome and Safari will let users share their audio and video using WebRTC.  

The full source code `bbb-install.sh` is [here](https://github.com/bigbluebutton/bbb-install).  To make it easy for anyone to run the script with a single command, we host the latest version of the script at `https://ubuntu.bigbluebutton.org/bbb-install.sh`.


### Server choices

There are many hosting companies that will provide you both virtual and dedicated servers.

For example, [Digital Ocean](https://www.digitalocean.com/) offers both virtual and bare metal servers that provide you with an Ubuntu 16.04 64-bit server with single public IP address and no firewall. 

Other companies, such as [ScaleWay](https://www.scaleway.com/) (choose either Bare Metal or Pro servers) and [Google Compute Engine](https://cloud.google.com/compute/) offer servers that are setup behind network address translation (NAT).  That is, they have both an internal and external IP address.  When installing on these servers, the `bbb-install.sh` will detect the internal/external addresses and configures BigBlueButton accordingly.  

However, if your server is behind a firewall, such as on Amazon EC2 instance, you will need to manually configure the firewall (see steps below).  

Finally, if `bbb-install.sh` is unable to configure your server behind NAT, we recommend going through the [step-by-step](http://docs.bigbluebutton.org/2.0/20install.html#step-by-step-install) for installing BigBlueButton.  (Going through the steps is also a good way to understand more about how BigBlueButton works).


### Configuring the firewall

If you want to install BigBlueButton 2.0 on a server behind a firewall, such an Amazon's EC2 instance (we recommend a c5.xlarge instance type or faster), you first need to configure the firewall to forward incoming traffic on the following ports:

  * TCP/IP port 22 (for SSH)
  * TCP/IP ports 80/443 (for HTTP/HTTPS)
  * TCP/IP port 1935 (for RTMP)
  * UDP ports in the range 16384 - 32768 (for FreeSWITCH/HTML5 client RTP streams)

Amazon calls the firewall for EC2 a 'security group'.   Here's a screen shot how the EC2 security group configuration should look after configuring it to forward incoming traffic on the above ports:

![Security Group](images/security-group.png?raw=true "Security Group")

If you are using EC2, you need to assign your server an [Elastic IP address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html) to prevent it from getting a new IP address on reboot.

### Installation Videos

It's easier to install on Digital Ocean as there is no default firewall.  We put together this [bbb-install.sh on Digital Ocean](https://youtu.be/D1iYEwxzk0M) video for a walk-through of the configuration options.

See [Install using bbb-install.sh on EC2](https://youtu.be/-E9WIrH_yTs) for a walk-through of installing BigBlueButton 2.0 on Amazon EC2 using `bbb-install.sh`.

# Command options

You can get help by passing the `-h` option.

~~~
$ wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -h
BigBlueButton 2.0 installer script

USAGE:
    bbb-install.sh [OPTIONS]

OPTIONS:

  -v <version>     Install given version of BigBlueButton (e.g. 'xenial-200') (required)

  -s <hostname>    Configure server with <hostname>
  -e <email>       Install SSL certificate from Let's Encrypt using <email>

  -t               Install HTML5 client (currently under development)
  -g               Install Green Light

  -p <host>        Use apt-get proxy at <host>

  -h               Print help

EXAMPLES:

    ./bbb-install.sh -v xenial-200
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com
    ./bbb-install.sh -v xenial-200 -s bbb.example.com -e info@example.com -t -g

SUPPORT:
     Source: https://github.com/bigbluebutton/bbb-install
   Community: https://bigbluebutton.org/support
~~~

## Install and configure with an IP address (no SSL)

To install BigBlueButton on a Ubuntu 16.04 64-bit server, login as root and run the following command:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 
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

Since this use of `bbb-install.sh` does not configure a SSL certificate, use must FireFox for sharing audio (at the time of this writing, FireFox does not require SSL to use WebRTC audio).  However, Chrome *does* require a SSL certificate, so users will get an error when sharing their audio with WebRTC.
 
We recommend installing an SSL certificate (see next section).
 
## Install with SSL

Before `bbb-install.sh` can install a SSL certificate, you first need to configure a domain name, such as `bbb.example.com`, that resolves to the public IP address of your server.  If you have setup a domain name, you can check that it correctly resolves to the external IP address of the server using the `dig` command.

~~~
dig bbb.example.com @8.8.8.8
~~~

Note: we're using `bbb.example.com` as an example hostname, you would substitute your real hostname in commands below.

To receive updates from Let's Encrypt, you need to provide a valid e-mail address.

With just these two pieces of information -- FQDN and e-mail address -- you can use `bbb-install.sh` to automate the configuration of BigBlueButton server with an SSL certificate.  For example, using the sample hostname and e-mail in the command, to install BigBlueButton 2.0 with a SSL certificate from Let's Encrypt, use the following command (again, you would substitute `bbb.example.com` and `info@example.com` with your servers FQDN and your e-mail address):

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com
~~~

The `bbb-install.sh` script will also install a cron job that automatically news the Let's Encrypt certificate so it doesn't expire.  Cool.


## Install latest build of HTML5 client

To try out the latest of the latest build of the [HTML5 client](http://docs.bigbluebutton.org/html/html5-overview.html), add the `-t` option.

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t
~~~

After a few minutes, you'll have the HTML5 client installed.  Use an Android (6.0+) or iOS (iOS 11+) mobile phone or tablet to access your BigBlueButton server.  BigBlueButton detects when you are connecting from a mobile browser and automatically load the HTML5 client.

BigBlueButton will automatically launch the HTML5 client if the browser does not support Flash, such as when accessing the server using an iOS (iOS 11+) or Android (version 6.0+) phone or tablet.  Since `bbb-install.sh` installs the API demos, you can force the loading of the HTML5 client by opening the URL `https://<hostname>/demo/demoHTML5.jsp`, entering your name, and clicking Join.

![bbb-install.sh](images/html5-join.png?raw=true "HTML5 Page")

Enter your name and click Join.  The HTML5 client will then load and join you into Demo Meeting.

![bbb-install.sh](images/html5.png?raw=true "HTML5 Client")


## Install Green Light

[Green Light](https://github.com/bigbluebutton/greenlight) is front-end for BigBlueButton written in Ruby on Rails.  It lets users create accounts, have permanent rooms, and manage their recordings.

You can install [GreenLight](http://docs.bigbluebutton.org/install/green-light.html) by adding the `-g` option.

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -g
~~~

Once GreenLight is installed, opening the hostname for the server, such as `https://bbb.example.com/`, automatically opens Green Light.  You can also configure GreenLight to use [OAuth2 authentication](http://docs.bigbluebutton.org/install/greenlight-v2.html#configuring-greenlight-20).

To launch GreenLight, simply the URL of your server, such as https://bbb.example.com/.  You should see the GreenLight landing page.

![bbb-install.sh](images/greenlight.png?raw=true "Green Light")

## Do everything with a single command

If you want to setup BigBlueButton 2.0 with a SSL certificate, HTML5 client, and GreenLight, you can do this with a single command.

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t -g
~~~

For all the commands given above, you can re-run the same command later to update your version of BigBlueButton 2.0 to the latest release.  We announce updates to BigBlueButton to the [bigbluebutton-dev](https://groups.google.com/forum/#!forum/bigbluebutton-dev) mailing list.


# Next Steps

If you intend to use this server for production you should uninstall the API demos using the command

~~~
apt-get purge bbb-demo
~~~

## Troubleshooting

### Green Light not running

If on first install Green Light gives you a `500 error` when accessing it, you can [restart Green Light](http://docs.bigbluebutton.org/install/greenlight-v2.html#if-you-ran-greenlight-using-docker-run).

### Getting Help

If you have feedback on the script, or need help using it, please post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) mailing list with details of the issue (and include related information such as steps to reproduce the error).

If you encounter an error with the script (such as it not completing or throwing an error), please open [GitHub issue](https://github.com/bigbluebutton/bbb-install/issues) and provide steps to reproduce the issue.


# Limitations

If you are running your BigBlueButton behind a firewall, such as on EC2, this script will not configure your firewall.  You'll need to [configure the firewall](#configuring-the-firewall) manually.


