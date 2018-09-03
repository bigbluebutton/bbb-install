
![bbb-install.sh](images/bbb-install.png?raw=true "bbb-install.sh")

# bbb-install

`bbb-install` is a BASH script that can install [BigBlueButton 2.0](http://docs.bigbluebutton.org/2.0/20overview.html) with a single command in about 15 minutes.  

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 
~~~

`bbb-install` requires that you run it as root on a Ubuntu 16.04 64-bit server that meets the [minimal requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements).  If the server is behind firewall, such as on an AWS EC2 instance, you'll need to update the firewall settings to allow the needed ports before BigBlueButton will run correctly.

The above command finishes you'll see a message that the API demos are installed to let you quickly test your server.

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

To test, launch FireFox -- you need to use FireFox as does not require the installation of a secure socket layer (SSL) certificate for WebRTC -- open the above URL, enter your name and click Join.   

This single command will get you going with a BigBlueButton server that you can access with an IP address.  The sections below go into details of how `bbb-install.sh` works and the configuration options available.


## Overview

The `bbb-install.sh` is a shell script that automates the [installation steps](http://docs.bigbluebutton.org/2.0/20install.html#step-by-step-install) for BigBlueButton 2.0.  

You'll need a server that meets the [minimal server requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements).  This can be a dedicated or virtual server.  

Before running `bbb-install.sh`, we recommend you setup a fully qualified domain name (FQDN), such as `bbb.example.com`, that resolves to the external IP address of the server.  With a FQDN in place, you can use `bbb-install.sh` to also install

  * a 4096 bit secure socket layers (SSL) certificate from Let's Encrypt, 
  * the latest developer build of the HTML5 client, and 
  * the Green Light front-end.

We strongly recommend installing a SSL certificate for any production server.  Chrome and Safari both require the server to have an SSL certificate before they will let the user share audio or video using web real-time communications (WebRTC).

The full source code for the script is here [github](https://github.com/bigbluebutton/bbb-install).  To make it easy for anyone to run the script with a single command, we host the latest version of the script at `https://ubuntu.bigbluebutton.org/bbb-install.sh`.


### Server choices

Many companies, such as [Digital Ocean](https://www.digitalocean.com/), offer both virtual and bare metal servers that provide you with an Ubuntu 16.04 64-bit server with single public IP address and no firewall.  

Other companies, such as [ScaleWay](https://www.scaleway.com/) and [Google Compute Engine](https://cloud.google.com/compute/) offer servers that are setup behind network address translation (NAT).  That is, they have both an internal and external IP address.  When installing on these servers, the `bbb-install.sh` will detect the internal/external addresses and configures BigBlueButton accordingly.  

However, if your server is behind a firewall, such as on Amazon EC2 instance, you will need to manually configure the firewall (see steps below).  

Finally, if you find `bbb-install.sh` is unable to configure server behind NAT, we recommend going through the [step-by-step](http://docs.bigbluebutton.org/2.0/20install.html#step-by-step-install) for installing BigBlueButton.  (Going through the steps is also a good way to understand more about how BigBlueButton works).


### Configuring the firewall

If you want to install BigBlueButton 2.0 on a server behind a firewall, such an Amazon's EC2 instance (we recommend a c5.xlarge instance type or faster), you first need to configure the firewall to allow incoming traffic on the following ports:

  * TCP/IP port 22 (for SSH)
  * TCP/IP ports 80/443 (for HTTP/HTTPS)
  * TCP/IP port 1935 (for RTMP)
  * UDP ports in the range 16384 - 32768 (for FreeSWITCH/HTML5 client RTP streams)

Amazon calls the firewall for EC2 a 'security group'.   Here's a screen shot of what the EC2 security group configuration should look like to allow incoming traffic on the above ports:

![Security Group](images/security-group.png?raw=true "Security Group")

If you reboot an EC2 instance Amazon will give it a new external IP address (which means you'll need to update the DNS entry for its FQDN).  You should also assign the server an Elastic IP so the IP address does not change on reboot.   

Since installation on EC2 is common, we created this [installation video on EC2](https://youtu.be/-E9WIrH_yTs) to walk through the above steps.

### Installation Videos

It's easier to install on Digital Ocean as there is no default firewall.  We put together this [bbb-install.sh on Digital Ocean](https://youtu.be/D1iYEwxzk0M) video for a walk-through of the configuration options.

See [Install using bbb-install.sh on EC2](https://youtu.be/-E9WIrH_yTs) for a walkabout of installing BigBlueButton 2.0 on Amazon EC2 using `bbb-install.sh`.

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

That's it.  The installation should finish with the following message:

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

The script also installs the `bbb-demo` package, so you can immediately test out the install.  If you want to remove the API demos, do the command

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

Since the server does not have a SSL certificate, use must FireFox for sharing audio (at the time of this writing, FireFox does not require SSL to use WebRTC audio).  However, Chrome *does* require a SSL certificate, so users will get an error when sharing their audio with WebRTC.
 
We recommend installing an SSL certificate (see next section).
 
## Install with SSL

Before `bbb-install.sh` can install a SSL certificate, you first need to configure a domain name, such as `bbb.example.com`, that resolves to the public IP address of your server.  That is, the command `dig bbb.example.com @8.8.8.8` should resolves to the public IP address of your server.  

Note: we're using `bbb.example.com` as an example hostname, you would substitute your real hostname in commands below.

Next, you need a valid e-mail address, such as `info@example.com`, to receive updates from Let's Encrypt.  

With these two pieces of information, you can use `bbb-install.sh` to automate the configuration of BigBlueButton server with an SSL certificate using the following command (here we using the sample hostname and e-mail in the command, but you would need to substitute your server's hostname and your e-mail address):

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com
~~~

The `bbb-install.sh` script will also install a cron job that automatically news the Let's Encrypt certificate so it doesn't expire.  Cool.


## Install latest build of HTML5 client

To try out the latest build of the latest build of the [HTML5 client](http://docs.bigbluebutton.org/html/html5-overview.html), add the `-t` option along with the options to install an SSL certificate (the HTML5 client needs SSL certificate installed on the server).

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t
~~~

After a few minutes, you'll have the HTML5 client installed.  Use an Android (6.0+) or iOS (iOS 11+) mobile phone or tablet to access your BigBlueButton.  The BigBlueButton server will detect when you are connecting from a mobile browser and automatically load the HTML5 client instead of the default Flash client.  

Note: the HTML5 client is under [active development](http://docs.bigbluebutton.org/html/html5-overview.html) and is not ready (yet) for production.


## Install Green Light

If you want to add a front-end to your BigBlueButton server where users can easily create meetings and invite others, you can install [GreenLight](http://docs.bigbluebutton.org/install/green-light.html) by adding the `-g` option along with the options to install an SSL certificate (Green Light needs SSL installed on the server).

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -g
~~~

You can go to `https://bbb.example.com/` to launch the Green Light interface.  To give users the ability to create and manage recorded meetings, See the Green Light documentation for [setting up OAuth2 authentication](http://docs.bigbluebutton.org/install/greenlight-v2.html#configuring-greenlight-20).

## Do everything with a single command

If you have a server with a FQDN you can install everything with a single command:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.example.com -e info@example.com -t -g
~~~

# Troubleshooting and Feedback

## Green Light not running

If after the initial installation Green Light does not run (you get a 500 error when accessing it), you can restart Green Light with the commands [here](http://docs.bigbluebutton.org/install/greenlight-v2.html#if-you-ran-greenlight-using-docker-run).


## Getting Help
If you have feedback on the script, or need help using it, please post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) mailing list and we'll help you there.

If you encounter an error with this script, please open [GitHub issue](https://github.com/bigbluebutton/bbb-install/issues) and provide steps to reproduce the issue.


# Limitations

If you are running your BigBlueButton behind a firewall, such as on EC2, this script will not configure your firewall. 


