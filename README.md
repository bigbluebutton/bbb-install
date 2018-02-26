
# bbb-install 

Want to setup your own [BigBlueButton 2.0-beta](http://docs.bigbluebutton.org/2.0/20overview.html) (referred hereafter as BigBlueButton 2.0) server on a server that meets the [minimual server requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements)?  In many cases, if you just want to access the server by its external IP address, you can install BigBlueButton 2.0 with a single command

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 
~~~

The `bbb-install.sh` is a shell script that automates the [install steps](http://docs.bigbluebutton.org/2.0/20install.html#step-by-step-install) for installing BigBlueButton 2.0.  Depending on the internet connection for your server, you should have BigBlueButton 2.0 up and running in about 15 minutes.  

It contains a number of options (described below) that let you configure your setup.

## Overview

If you have a server that meets the [minimual server requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements) and that server has a single IP address with no firewall, then you can use `bbb-install.sh` to install the latest build of BigBlueButton 2.0 with a single command.  

If you setup a fully qualified domain name (FQDN), such as `bbb.my-server.com`, that resolves to the server, then you can use `bbb-install.sh` to also automate the installation of
  * a 4096 bit secure socket layers (SSL) certificate from Let's Encrypt, 
  * the latest developer build of the HTML5 client, and/or
  * the GreenLight front-end.

We recommend installing a SSL certificate for production BigBlueButton servers.  Chrome require HTTPS before allowing users to share their microphone via web real-time communications (WebRTC).

The source for the script is at [this github repository](https://github.com/bigbluebutton/bbb-install).  Wile you could clone this respoitory an execute `bbb-install.sh` at the command line, we host the script at `https://ubuntu.bigbluebutton.org/bbb-install.sh` so you can use `wget` to install BigBlueButton 2.0 with a single command on a new server.

### Server choices

Many companies, such as [Digital Ocean](https://www.digitalocean.com/), offer virtual and bare metal servers that provide a Ubuntu 16.04 64-bit server with single public IP address (no firewall).  In these cases, the script can automate the installation.  

If you are installing on an Amazon EC2 instance -- we recommend a c5.xlarge instance type (or faster) -- then there are a few additional steps to configure the settings on your firewall (given below).  

Aside from the support for Amazon EC2, if your server is behind NAT, we recommend going through the [step-by-step](http://docs.bigbluebutton.org/2.0/20install.html#step-by-step-install) for installing BigBlueButton.

### Intallation Video

To show setting BigBlueButton with `bbb-install.sh`, we created this [bbb-install.sh overview video](https://youtu.be/D1iYEwxzk0M).  In the video, we setup BigBlueButton 2.0 on a Digital Ocean droplet with a single command.

### Configuring the EC2 firewall
If you want to install BigBlueButton 2.0 on an Amazon's EC2 instance using this script, then before your run `bbb-install.sh` you first need to configure the server's security group (Amazon's term for a firewall) to allow incoming traffic on the following ports:

  * TCP/IP port 22 (for SSH)
  * TCP/IP ports 80/443 (for HTTP/HTTPS)
  * TCP/IP port 1935 (for RTMP)
  * UDP ports in the range 16384 - 32768 (for FreeSWITCH/HTML5 client RTP streams)

Here's a screen shot of what the server's security group configuration should look like to allow incoming traffice on the above ports:

![Security Group](images/security-group.png?raw=true "Security Group")

The script will detect the EC2 instance environment and automatically configure BigBlueButton to use the servers private/public address pairs.  As described above, you can use the server with only an IP address, but you should setup an Elastic IP for the server (so the IP does not change on reboot) and a FQDN for the server (so `bbb-install.sh` can use Let's Encrypt to install a SSL certificate for HTTPS).

We also created in [installation video on EC2](https://youtu.be/-E9WIrH_yTs) going through the above steps.

# Sample Usage

## Single IP address (no SSL)

To install BigBlueButton on a Ubuntu 16.04 64-bit server with an external IP address or on an EC2 instance, login as root and run the following command:

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

The script also installs the `bbb-demo` package, so you can immediately test out the install. 

If you want to remove the API demos, do the command

~~~
sudo apt-get purge bbb-demo
~~~

If you want to use this server with a front-end, such as Moodle, you can get the server's URL and shared secret with the command `sudo bbb-conf --secret`.

~~~
# bbb-conf --secret

       URL: http://xxx.xxx.xxx.xxx4/bigbluebutton/
    Secret: yyy

      Link to the API-Mate:
      http://mconf.github.io/api-mate/#server=http://xxx.xxx.xxx.xxx/bigbluebutton/&sharedSecret=yyy
~~~

Since the server does not have a SSL certificate, use FireFox for sharing audio (at the time of this writing, FireFox does not require SSL to use WebRTC audio).  However, Chrome *does* require a SSL certificate, so users will get an error when sharing their audio with WebRTC.
 
We recommend installing an SSL certificate (see next section).
 
## Install with SSL

Before `bbb-install.sh` can install a SSL certificate, you first need to configure a domain name, such as `bbb.my-server.com`, to resolve to the public IP address of your server.  That is, the command `dig bbb.my-server.com @8.8.8.8` should resolves to the public IP address of your server.  

Next, you need a valid e-mail address, such as `info@my-server.com`, to receive updates from Let's Encrypt.  

With these two pieces of information, you can use `bbb-install.sh` to automate the configuration of BigBlueButton server with an SSL certificate using the following command (here we using the sample hostname and e-mail in the command, but you would need to substitute your serverès hostname and your e-mail address):

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com -e info@my-server.com
~~~

The `bbb-install.sh` script will also install a cron job for you to automatically renew the Let's Encrypte certifcate so it doesn't expire. 

## Install latest build of HTML5 client

to try out the latest build of the latest developer build of the [HTML5 client](http://docs.bigbluebutton.org/html/html5-overview.html), use the `-t` option (the HTML5 client needs SSL installed on the server).

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -t
~~~

After a few minutes, youèll have the HTML5 client is installed.  You can tou can use an Android or iOS (iOS 11+) phone/tablet to access your BigBlueButton server at `https://bbb.my-server.com/demo/demo1.jsp` and join using the HTML5 client.  The BigBlueButton server will detect when you are connecting from a mobile browser and automatically load the HTML5 client instead of the default Flash client.  Note: the HTML5 client is under [active development](http://docs.bigbluebutton.org/html/html5-overview.html) and is not ready (yet) for production.

## Install GreenLight

If you want a more sophisticated front-end to your BigBlueButton server, you can install [GreenLight](http://docs.bigbluebutton.org/install/green-light.html) with the `-g` option (GreenLight needs SSL installed on the server).

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -g
~~~

You can go to `https://<hostname>/` (where <hostname> is the host name for your BigBlueButton server) to launch the GreenLight interface.  To give users the ability to create and manage recorded meetings, See the GreenLight documentation for [setting up OAuth2 authentication](http://docs.bigbluebutton.org/install/green-light.html#6-configure-oauth2-optional).

## Do everything with a single command

Lastly, you could do all the above with a single command:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com -e info@my-server.com -t -g
~~~

# Troubleshooting and Feedback

If you have feedback on the script, or need help using it, please post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) mailing list and we'll help you there.

If you encouner an error with this script, please open [GitHub issue](https://github.com/bigbluebutton/bbb-install/issues) and provide steps to reproduce the issue.


# Limitations

This script has the following limitations:

  * It will not configure your firewall 
  * Currently, HTML5 client does not launch from GreenLight

