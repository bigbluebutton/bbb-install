
# bbb-install 
The `bbb-install.sh` script automates the [steps to install](/2.0/20install.html) BigBlueButton 2.0-beta (referred hereafter as BigBlueButton 2.0) on a Ubuntu 16.04 64-bit server that has a single public IP address.

Why the requirement of the server having a single public IP address?  If you intend to install BigBlueButton 2.0 on a server behind a firewall, then there are additional steps (which are covered in detail in the [install documentation](/2.0/20install.html), that are beyond the scope of an installation
 script.  

Still, many hosting providers -- both bare metal and virtual -- give you servers with a single public IP address (Digital Ocean is an example of such provider). For these servers, you can use `bbb-install.sh` to setup a new BigBlueButton server in a few minutes.

Furthermore, if you configure a fully qualified domain name (FQDN), such as `bbb.my-server.com`, to resolve to the public IP address of your server, then the script can use Let's Encrypt to install a secure socket layers (SSL) certificate and configure BigBlueButton to server content via HTTPS.  Chome (and soon FireFox) will require the website to support HTTPS before it enables sharing of audio via web real-time communications (WebRTC).

## Overview

If you have a  server that meets the [minimual server requirements](http://docs.bigbluebutton.org/install/install.html#minimum-server-requirements) and has a single IP address, then you can use `bbb-install.sh` to install the latest build of BigBlueButton 2.0 with a single command.

Furthermore, if you have a fully qualified domain name (FQDN), such as `bbb.my-server.com`, that resolves to the server, then you can use `bbb-install.sh` to install
  * an SSL certificate from Let's Encrypt, 
  * the latest developer build of the HTML5 client, and/or
  * the GreenLight front-end.

We also put together this [YouTube Video Overview of bbb-install.sh](https://youtu.be/D1iYEwxzk0M) to walk through using the script.

## Usage

To run this script, you can fork [this github repository](https://github.com/bigbluebutton/bbb-install) an execute `bbb-install.sh`.  We've also hosted the script at `https://ubuntu.bigbluebutton.org/bbb-install.sh` so you can use `wget` install BigBlueButton 2.0 with a single command on any server that meets the above requirements.

To install BigBlueButton with server's external IP address:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 
~~~

That's it.  Depending on the server's internet connection, after about 10 minutes, you'll have the latest build of BigBlueButton 2.0 running on the server.  The installation should finish with the message

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

Since we didn't specify a hostname for the installation, the `bbb-install.sh` script will configure BigBlueButton to use the servers public IP address.  The script also installs the `bbb-demo` package, so you can immediately test out the install.

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


While the core BigBlueButton server can run using just an IP address, you really want to have the server configured with a hostname and SSL certificate.  

Let's say you have configured the domain name `bbb.my-server.com` to resolve to the public IP address of your server.  That is, the command `dig bbb.my-server.com @8.8.8.8` resolves to the IP address of your server.  And you have a valid e-mail address, such as `info@my-server.com`, to receive updates from Let's Encrypt.  Then, with these two pieces of information, you can use `bbb-install.sh` to configure BigBlueButton server with an SSL certificate with a single command.

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com -e info@my-server.com
~~~

The `bbb-install.sh` script will also install a cron job for you to automatically renew the Let's Encrypte certifcate so it doesn't expire. 

Later on, you can install the latest developer build of the [HTML5 client](http://docs.bigbluebutton.org/html/html5-overview.html)  with the `-t` option (the HTML5 client needs SSL installed on the server).

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -t
~~~

After the HTML5 client is installed, you can use an Android or iOS (iOS 11+) phone/tablet to access your BigBlueButton server at `https://bbb.my-server.com/demo/demo1.jsp` and join using the HTML5 client.  BigBlueButton will detect the mobile browser and automatically load the HTML5 client instead of the default Flash client.  Note: the HTML5 client is under [active development](http://docs.bigbluebutton.org/html/html5-overview.html) and is not ready (yet) for production.

If you want a more sophisticated front-end to your BigBlueButton server, you can install [GreenLight](http://docs.bigbluebutton.org/install/green-light.html) with the `-g` option (GreenLight needs SSL installed on the server).

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -g
~~~

Finally, you could do all the above with a single command:

~~~
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-200 -s bbb.my-server.com -e info@my-server.com -t -g
~~~

# Troubleshooting and Feedback

If you have feedback on the script, or need help using it, please post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) mailing list and we'll help you there.

If you encouner an error with this script, please open an [issue](https://github.com/bigbluebutton/bbb-install/issues) and provide steps to reproduce the issue.


# Limitations

This script has the following limitations:

  * It will not configure your firewall (hence the requirement that your server have a single public IP address)
  * Currently, HTML5 client does not launch from GreenLight
