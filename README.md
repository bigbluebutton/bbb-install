<img width="1012" alt="bbb-install-banner" src="https://user-images.githubusercontent.com/1273169/141152865-f497c883-6c96-41c6-9040-613b0858878a.png">

### Note:

Please use `bbb-install.sh` to install or upgrade BigBlueButton.

For example use `bbb-install.sh` with the parameter `-v focal-270` to install BigBlueButton 2.7 or upgrade to that release. Check https://docs.bigbluebutton.org for the latest production ready release of BigBlueButton.

There are checks within the scripts that will inform you if the upgrade is not possible (i.e. operating system changed between the releases, or some really significant changes were made that prevent us from supporting an upgrade).
etc.

# bbb-install

To help you set up a new BigBlueButton server (or upgrade from an earlier version of BigBlueButton where applicable), `bbb-install.sh` is a shell script that automates the installation/upgrade steps  (view the [source](https://github.com/bigbluebutton/bbb-install/blob/master/bbb-install.sh) to see all the details).   Depending on your server's internet connection, `bbb-install.sh` can fully install and configure BigBlueButton on a server that meets the [minimum production use requirements](https://docs.bigbluebutton.org/administration/install#minimum-server-requirements) in under 30 minutes.

The full source code for the installation scripts can be found [here](https://github.com/bigbluebutton/bbb-install).


So, to install the latest iteration of BigBlueButton 2.7 on a new 64-bit Ubuntu 20.04 server with a public IP address, a hostname (such as `bbb.example.com`) that resolves to the public IP address, and an email address (such as `info@example.com`), log into your new server via SSH and run the following command as root.

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -w -v focal-270 -s bbb.example.com -e info@example.com
~~~

This command pulls down the latest version of `bbb-install.sh` from BigBlueButton 2.7 branch , sends it to the Bash shell interpreter, and installs BigBlueButton using the parameters provided:

  * `-w` installs the uncomplicated firewall (UFW) to restrict access to TCP/IP ports 22, 80, and 443, and UDP ports in range 16384-32768.
  * `-v focal-270` installs the latest iteration of BigBlueButton 2.7.x .
  * `-s` sets the server's hostname to be `bbb.example.com`.
  * `-e` provides an email address for Let's Encrypt to generate a valid SSL certificate for the host.

The hostname `bbb.example.com` and email address `info@example.com` are just sample parameters.  The following sections walk you through the details on using `bbb-install.sh` to set up/upgrade your BigBlueButton server.

Note: BigBlueButton meetings will run in a web browser.  The browsers now require the use of HTTPS before allowing access to resources such as your webcam, microphone, or screen (for screen sharing) when using the browser's built-in real-time communications (WebRTC) libraries which is the case for BigBlueButton meetings.  In other terms, if you try to install BigBlueButton without specifying the `-s` and `-e` parameters, the client will not load.

Note: If your server is also behind an external firewall -- such as behind a corporate firewall or behind an AWS Security Group -- you will need to manually configure the external firewall to forward [specific internet connections](#configuring-the-external-firewall) to the BigBlueButton server before you can launch the client.

The following sections go through in more detail setting up a new BigBlueButton server.

## Getting ready

Before running `bbb-install.sh`, you need to:

  * read through all the documentation in this page.
  * ensure that your server meets the [minimal server requirements](https://docs.bigbluebutton.org/administration/install#minimum-server-requirements).
  To provision your server your can check some [known choices](#server-choices) -- you may also need to further [configure external firewalls](#configuring-the-external-firewall).
  * configure a fully qualified domain name (FQDN), such as `bbb.example.com`, that resolves to the external IP address of your server.

To set up your FQDN, purchase a domain name from a domain name registrar or a web hosting provider, such as [GoDaddy](https://godaddy.com) or [Network Solutions](https://networksolutions.com).  Once purchased, follow the steps indicated by your provider to create an `A Record` for your FQDN that resolves to the public IP address of your server.  (Check the provider's documentation for details on how to set up the `A Record`.)

With your FQDN in place, you can then pass a few additional parameters to `bbb-install.sh` to have it:

  * request and install a 4096-bit TLS/SSL certificate from Let's Encrypt (we love Let's Encrypt) (**required**).
  * install a firewall to restrict access to only the needed ports (**recommended**).
  * [install and configure Greenlight](#install-greenlight) to provide a simple front-end for users to enable them to set up rooms, hold online sessions, and manage recordings (**optional**).
  * [install and configure BigBlueButton LTI framework](#install-bigbluebutton-lti-framework) to integrate your BigBlueButton server to any Learning Tools Interoperability (LTI) certified platform (that's the majority of known Learning Management Systems (LMS)!) (**optional**). 

Note:
 Everything from installing to [updating the system](#update-the-system) can be achieved through the `bbb-install.sh` command and their options.
 You can check the full list of the [command options](#command-options) and what they offer!
 You can [do everything in one command](#doing-everything-with-a-single-command).

 After installation you may want to know [what to do next](#next-steps).
 If having a problem when running the command? you can look [here](#troubleshooting).
 
 If having a question, a problem or wanting to know more you can [connect with community](#getting-help).
 You can also check the list of some [common limitations and caveats](#limitations)

### Server choices

There are many hosting companies that can provide you with dedicated virtual and bare-metal servers to run BigBlueButton.  We list a few popular choices below (we are not making any recommendation here, just listing some of the more popular choices).

For quick setup, [Digital Ocean](https://www.digitalocean.com/) offers both virtual servers with Ubuntu 20.04 64-bit and a single public IP address (no firewall).  [Hetzner](https://hetzner.cloud/) offers dedicated servers with single IP address.

Other popular choices, such as [ScaleWay](https://www.scaleway.com/) (choose either Bare Metal or Pro servers) and [Google Compute Engine](https://cloud.google.com/compute/), offer servers that are set up behind network address translation (NAT).  That is, they have both an internal and external IP address.  When installing on these servers, the `bbb-install.sh` will detect the internal/external addresses and configure BigBlueButton accordingly.  

Another popular choice is [Amazon Elastic Compute Cloud](https://aws.amazon.com/ec2).  We recommend a `c5.2xlarge` or `c5a.2xlarge` (or larger) instance.  All EC2 servers are, by default, behind a firewall (which Amazon calls a `security group`).  You will need to manually configure the security group before installing BigBlueButton on EC2 and, in a similar manner, on Azure and Google Compute Engine (GCE).  (See screen shots in next section.)

Finally, if `bbb-install.sh` is unable to configure your server behind NAT, we recommend going through docs on [Configure Firewall](https://docs.bigbluebutton.org/administration/firewall-configuration#overview).


### Configuring the external firewall

If you install BigBlueButton on a server behind an external firewall, such an Amazon's EC2 security group, you need to configure the external firewall to forward incoming traffic on the following ports:

  * TCP/IP port 22 (for SSH)
  * TCP/IP ports 80/443 (for HTTP/HTTPS)
  * UDP ports in the range 16384 - 32768 (for FreeSWITCH/HTML5 client RTP streams)

If you are using EC2, you should also assign the server an [Elastic IP address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html) to prevent it from getting a new IP address on reboot.

On Microsoft Azure, when you create an instance you need to add the following inbound port rules to enable incoming connections on ports 80, 443, and UDP port range 16384-32768:

![Azure Cloud ](images/azure-firewall.png?raw=true "Azure 80, 443, and UDP 16384-32768")

On Google Compute Engine, when you create an instance you need to enable traffic on port 80 and 443.

![Google Compute Engine 80-443](images/gce-80-443.png?raw=true "GCE 80 and 443")

After the instance is created, you need to add a firewall rule to allow incoming UDP traffic on the port range 16384-32768.

![Google Compute Engine Firewall](images/gce-firewall.png?raw=true "GCE Firewall")

We make a distinction here between the firewall installed with `-w` and the external firewall on a separate server.  Even with an external firewall, it is good practice to still install the UFW firewall on the BigBlueButton server.


## Command options

You can get help by passing the `-h` option.

~~~
Script for installing a BigBlueButton 2.7 server in under 30 minutes. It also supports upgrading a BigBlueButton server to version 2.7 (from version 2.6.0+ or an earlier 2.7.x version)

This script also supports installation of a coturn (TURN) server on a separate server.

USAGE:
    wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- [OPTIONS]

OPTIONS (install BigBlueButton):

  -v <version>           Install given version of BigBlueButton (e.g. 'focal-270') (required)

  -s <hostname>          Configure server with <hostname>
  -e <email>             Email for Let's Encrypt certbot

  -x                     Use Let's Encrypt certbot with manual dns challenges

  -g                     Install Greenlight version 3
  -k                     Install Keycloak version 20

  -t <key>:<secret>      Install BigBlueButton LTI framework tools and add/update LTI consumer credentials <key>:<secret>

  -c <hostname>:<secret> Configure with coturn server at <hostname> using <secret> (instead of built-in TURN server)

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
~~~

Before `bbb-install.sh` can install a SSL/TLS certificate, you will need to provide two pieces of information:
   * A fully qualified domain name (FQDN), such as `bbb.example.com`, that resolves to the public IP address of your server
   * An email address

When you have set up the FQDN, check that it correctly resolves to the external IP address of the server using the `dig` command.

~~~
dig bbb.example.com @8.8.8.8
~~~

Note: we're using `bbb.example.com` as an example hostname and `info@example.com` as an example email address.  You need to substitute your real hostname and email.

With just these two pieces of information (FQDN and email address) you can use `bbb-install.sh` to automate the configuration of the BigBlueButton server with a TLS/SSL certificate.  For example, to install BigBlueButton with a TLS/SSL certificate from Let's Encrypt using `bbb.example.com` and `info@example.com`, enter the following command:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.

The `bbb-install.sh` script will also install a cron job that automatically renews the Let's Encrypt certificate so it doesn't expire.  Cool!


### Installing in a private network

The default installation is meant to be for servers that are publicly available. This is because Let's Encrypt requires to access your system in order to automatically validate the FQDN provided.

When installing BigBlueButton in a private network, it is possible to validate the FQDN manually, by adding the option `-x` to the command line. As in:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -x [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.


Confirm the use of the email account.

```
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about our work
encrypting the web, EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o:
```

Confirm the use of the IP address
```
Are you OK with your IP being logged?
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o:
```

A challenge will be generated and shown in the console.

```
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please deploy a DNS TXT record under the name
_acme-challenge.bbb.example.com with the following value:

0bIA-3-RqbRo2EfbYTkuKk7xq2mzszUgVlr6l1OWjW8

Before continuing, verify the record is deployed.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Press Enter to Continue
```

Before hitting Enter, create a TXT record in the DNS with the challenge that was generated.

```
_acme-challenge.bbb.example.com.  TXT   "0bIA-3-RqbRo2EfbYTkuKk7xq2mzszUgVlr6l1OWjW8"   60
```

The downside of this is that because Let's Encrypt SSL certificates expire after 90 days, it will be necessary to manually update the certificates. In that case an email is sent a few days before the expiration and the next command has to be executed through the console.

```
certbot --email info@example.com --agree-tos -d bbb.example.com --deploy-hook 'systemctl restart nginx' --no-bootstrap --manual-public-ip-logging-ok --manual --preferred-challenges dns --server https://acme-v02.api.letsencrypt.org/directory certonly
```

### Install Greenlight

[Greenlight](https://docs.bigbluebutton.org/greenlight/v3/install) is an open-source, LGPL-3.0 licensed web application that allows organizations to quickly set up a complete web conferencing platform using their existing BigBlueButton server. It is user-friendly for both regular and advanced users.

Greenlight is BigBlueButton's official room manager, if you like to get a quick insight on its core features you can check our [official BigBlueButton demo](https://demo.bigbluebutton.org/). 

Greenlight offers BigBlueButton personal rooms, stable and user friendly join links, recordings management, protected rooms that requires access codes and/or for authenticated access only, pre-upload presentations, shared access, full control and customization of the platform at ease (Check Greenlight administrator below),...    

Greenlight is also equipped with local authentication out of the box. This means that authentication is managed internally within the platform and does not require any external servers or services for identity management.
 If willing to use some identity protocols and/or services Greenlight got you covered!
Check [Greenlight External Authentication](https://docs.bigbluebutton.org/greenlight/v3/external-authentication) for documentation on how to add in support for a wide variety of authentication protocols and APIs to your platform through [Keycloak](https://www.keycloak.org/) or any [OpenID connect](https://openid.net/connect/) provider!

More on Greenlight can be found [here](https://docs.bigbluebutton.org/greenlight/v3/install) 

To [install Greenlight](https://docs.bigbluebutton.org/greenlight/v3/install#bbb-install-script) you can simply use the `bbb-install.sh` command `-g` option:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -g [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.


To install Keycloak just use the `-k` option with `-g`:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -g -k [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.

A successful installation/upgrade is confirmed through a message displayed on the console.
The message will also provide the link to access and configure Greenlight and the next steps that may you want to follow.
By default, for a FQDN of `bbb.example.com` you'd access https://bbb.example.com/ and https://bbb.example.com/keycloak **if you've installed Keycloak**.

When accessing the link to your Greenlight deployment a result similar to the following screenshot is expected: 

![image](https://user-images.githubusercontent.com/29759616/231534866-23afa78e-4f7a-4a2d-be92-e3a560354078.png)

You can then sign-up and have an account
![image](https://user-images.githubusercontent.com/29759616/231537382-813c752f-5ff0-45fa-b8e1-c4052361c202.png)
![image](https://user-images.githubusercontent.com/29759616/231537452-8c67d5aa-441d-4529-ada4-ecb0f5f82758.png)

Need more control?

After installation, you can become an [administrator](https://docs.bigbluebutton.org/greenlight/v3/install/#creating-an-admin-account-1) unlocking the full power of Greenlight to further manage and control the entire platform through:
 - Managing all of its resources such as users, recordings, rooms, roles ...
 - Managing all of its settings (allowing/denying sessions to be recorded, limiting allowed rooms maximum number per role, changing the registration method, ...) configuring Greenlight to meet your business requirements!
 - Customizing the deployment by changing the: Logo, theme, policies, terms and conditions!
 - ...
 
 Once signing-in as an administrator you'd be able to access the administrator panel:
 
![image](https://user-images.githubusercontent.com/29759616/231612718-7ea4e5c6-cfde-47dc-baaf-2f4ae48d4561.png)
![image](https://user-images.githubusercontent.com/29759616/231538444-c2050a28-db1d-4716-ab44-b41751938487.png)
![image](https://user-images.githubusercontent.com/29759616/231538019-29897447-317a-4614-940c-5babb45d5e87.png)
![image](https://user-images.githubusercontent.com/29759616/231538027-141d199a-7697-4504-b083-c5adcb544d2a.png)

 
 No need to be a BigBlueButton guru or a developer to use and customize Greenlight!

#### Updates

Updating Greenlight is done simply through re-running the `bbb-install.sh` anytime while using the `-g` option:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -g [options]
~~~

Note: You don't need to re-use the `-k` to update Keycloak if already installed, using `-g` updates both of Greenlight and Keycloak as the latter is considered as a dependency to the project. 

#### Source
You can find the source for the Greenlight project [here](https://github.com/bigbluebutton/greenlight).
You can open tickets to highlight issues or to request new features.
You can become a contributor also!


### Install BigBlueButton LTI framework 

[LTI](https://www.imsglobal.org/activity/learning-tools-interoperability) is an acronym for Learning Tools Interoperability, which was developed by the [1EdTech](https://www.1edtech.org/) (Also known as IMS Global Learning Consortium). Its main objective is to establish standardized connections between learning systems, such as Learning Management Systems (LMS), and external service tools.

BigBlueButton is LTI 1.0 certified and can be seamlessly integrated into the majority of LMS systems or any LTI compatible platforms through its LTI framework.

The BigBlueButton LTI framework is a microservice LGPL-3.0 licensed project that enables the easy integration of your BigBlueButton server through the LTI protocol when direct integration through the [BigBlueButton API](https://docs.bigbluebutton.org/development/api) isn't possible.

Please check the list of known platforms that support BigBlueButton integration natively [here](https://bigbluebutton.org/schools/integrations/) before deciding to use LTI.

The BBB LTI framework is formed by a collection of services: The LTI Broker which is the entrypoint to the LTI framework and the only required LTI protocol aware component that bridges the LTI tools with the LTI protocol and a one or more LTI applications or tools where each provides one specific service or functionality through the usage of the BigBlueButton API like the LTI rooms application which abstracts and uses the BigBlueButton API to offer consumer platforms personnel managed rooms and recordings.

The Broker is a Web Application that acts as a LTI Broker for connecting Tool Consumers (like Moodle) with BigBlueButton Tools (like LTI rooms application) through the LTI protocol and the LTI tools are web applications that acts as a bridge between the consumers and BigBlueButton services. The most basic deployment of the framework therefore requires the collaboration of two applications, that is the Broker itself and a Tool such as the rooms application.


To install the LTI framework you can simply use the `bbb-install.sh` command `-t` option while providing a `KEY:SECRET` which you'll use when deploying the BigBlueButton LTI applications to your platform, for more details about the integration of a tool to your platform please refer to the official documentation of your solution:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -t MY_KEY:MY_SECRET [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.

Note: `MY_KEY` and `MY_SECRET` are only credentials used for demonstration purposes **only**, in production you need to substitute those values to some complex hard to guess values.
The security of your deployment is guaranteed by guarding those credentials private and not sharing them.

You can manage your LTI credentials through the `bbb-install.sh` command using the same option:

- To change the secret of a LTI credential re-run the same with the `-t` option while also using the same **KEY** but a new **SECRET**:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -t MY_KEY:MY_NEW_SECRET [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.


This overwrites the old secret, so expect a discontinuity in your integration of BigBlueButton through the LTI framework -- you need to update your deployment on the Tool consumer platform following its official documentation to use the new credentials.

- To add new credentials, re-run the same `bbb-install.sh` command with the `-t` option while also providing new pair of **KEY** and **SECRET**:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -t MY_NEW_KEY:MY_NEW_SECRET [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.

Old credentials will be intact so don't expect a discontinuity of your integration, you can start using the new credentials in new platforms.

A successful installation/upgrade is confirmed through a message displayed on the console.
The message will also provide the link to access and configure the LTI framework deployment.
By default, for a FQDN of `bbb.example.com` you'd access https://bbb.example.com/lti and you'd have a similar page to the following screenshot: 

![image](https://user-images.githubusercontent.com/29759616/231607217-7602738a-3a41-4884-90df-5b16764e7551.png)

Note: on your system `bbb.example.com` will be substituted with your FQDN.

#### Updates

Updating the LTI framework is done simply through re-running the `bbb-install.sh` anytime while using the `-t` option and providing credentials:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -t KEY:SECRET [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.

Notice the use of the same LTI credentials to avoid updating existing or adding new ones.

#### Source
You can find the source for the LTI broker [here](https://github.com/bigbluebutton/bbb-lti-broker) and the LTI rooms application [here](https://github.com/bigbluebutton/bbb-app-rooms).
You can open tickets to highlight issues or to request new features.
You can become a contributor also!

### Linking `/var/bigbluebutton` to another directory

The install script allows you to pass a path which will be used to create a symbolic link with `/var/bigbluebutton`:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -s bbb.example.com -e info@example.com -v focal-270 -w -m /mnt/test [options]
~~~

> [options] is a placeholder for one or more [options](#command-options) that you may use.

This allows users to store the contents of /`var/bigbluebutton`, which can get quite large, in a separate volume.

### Doing everything with a single command

If you want to set up BigBlueButton with a TLS/SSL certificate, [GreenLight](#install-greenlight), [Keycloak](https://docs.bigbluebutton.org/greenlight/v3/external-authentication#installing-keycloak) and [BigBlueButton LTI](#install-bigbluebutton-lti-framework) with LTI credentials `MY_KEY:MY_SECRET` , you can do this all with a single command:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -g -k -t MY_KEY:MY_SECRET
~~~

Note: You'd need to substitute your FQDN, email address and LTI credentials.

- `-g` will install the latest version of Greenlight v3.
- `-k` will install and configure Keycloak for Greenlight external authentication.
- `-t` will install the latest version the BigBlueButton LTI framework.

### Update the system
Furthermore, you can re-run the same `bbb-install.sh` command used for installation later to update your server to the latest version of BigBlueButton 2.7 along with any other installed applications like [Greenlight](#install-greenlight) or [BigBlueButton LTI](#install-bigbluebutton-lti-frameworkfo).

So to update the system in [Doing everything with a single command](#doing-everything-with-a-single-command) example you'd re-run the same command with the same options:

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -w -g -k -t MY_KEY:MY_SECRET
~~~

- `-g` will update Greenlight **and Keycloak** to the latest stable version.
- `-t` will update BigBlueButton LTI framework to the latest stable version.
- `-k` is optional and is only required to be used to resolve any encountered issues when installing Keycloak.

We announce BigBlueButton updates to the [bigbluebutton-dev](https://groups.google.com/forum/#!forum/bigbluebutton-dev) mailing list.


### Install a TURN server

Running the BigBlueButton client requires a wide range of UDP ports to be available for WebRTC communication.  However, in some network restricted sites or development environments, such as those behind NAT or a corporate firewall that restricts UDP connections, users may be unable to make outgoing UDP connections to your BigBlueButton server.

If you have setup your BigBlueButton on the internet, and you have users accessing the BigBlueButton server behind a restrictive firewall that blocks UDP connections, then setting up a separate TURN server will allow users to have the TURN server (connected via port 443) proxy their UDP-based WebRTC media (audio, webcam, and screen share) to the BigBlueButton server.

We recommend Ubuntu 20.04 as it has a newer version of [coturn](https://github.com/coturn/coturn) than Ubuntu 18.04.  The server does not need to be very powerful as it will only relay communications from the BigBlueButton client to the BigBlueButton server when necessary.  A dual core server on Digital Ocean should be sufficient for a dozen BigBlueButton servers.  

The server should have the following additional ports available:

| Ports         | Protocol      | Description |
| ------------- | ------------- | ----------- |
| 3478          | TCP/UDP       | coturn listening port |
| 80            | TCP           | HTTP required for Certbot |
| 443           | TCP/UDP       | TLS listening port |
| 32769-65535   | UDP           | relay ports range |


Before running `bbb-install.sh` to setup the TURN server (which installs and configures the `coturn` package), you need

  * A fully qualified domain name (FQDN) with 
    * an A record that resolves to the server's public IPV4 address
    * an AAAA record that resolves to the server's public IPV6 address
  * An email address for Let's Encrypt
  * A secret key (it can be an 8 to 16 character random string that you create).

With the above in place, you can set up a TURN server for BigBlueButton using the command

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -c <FQDN>:<SECRET> -e <EMAIL>
~~~

Note, we've omitted the `-v` option, which causes `bbb-install.sh` to just install and configure coturn.  For example, using `turn.example.com` as the FQDN, `1234abcd` as the shared secret, and `info@example.com` as the email address (you would need to substitute your own values), logging into the server via SSH and running the following command as root

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -c turn.example.com:1234abcd -e info@example.com
~~~

will do the following

  * Install the latest version of coturn available for Ubuntu 20.04
    * Provide a minimal configuration for `/etc/turnserver.conf`
    * Add a systemd override to ensure coturn can bind to port 443
    * Configure logging to `/var/log/turnserver/turnserver.log`
    * Add a logrotate configuration to keep the logs for 7 days
  * Setup a SSL certificate using Let's Encrypt
    * Add a deploy hook for Let's Encrypt to have coturn reload the certificates upon renewal 

With a SSL certificate in place, coturn can relay access to your BigBlueButton server via TCP/IP on port 443.  This means if a user is behind a restrictive firewall that blocks all outgoing UDP connections, the TURN server can accept connections from the user via TCP/IP on port 443 and relay the data to your BigBlueButton server via UDP.

After the TURN server is setup, you can configure your BigBlueButton server to use the TURN server by running the `bbb-install.sh` command again and add the parameter `-c <FQDN>:<SECRET>` (this tells `bbb-install.sh` to set up the configuration for the TURN server running at <FQDN> using the share secret <SECRET>.  For example,

~~~
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s bbb.example.com -e info@example.com -c turn.example.com:1234abcd
~~~

You can re-use a single TURN server for multiple BigBlueButton installations.


## Next steps
* You're out of sync and want to catch up with official releases, consider [updating your system](#update-the-system).

* You installed BigBlueButton but don't know how to easily use it for your online workloads?
 Have you [installed Greenlight](https://docs.bigbluebutton.org/greenlight/v3/install) BigBlueButton's first and biggest room manager?
 
* Are you using a Learning Management System (LMS) like [Moodle](https://moodle.org/)?
 Have you known that you can integrate your BigBlueButton server into your favorite LMS system either!
 Check [Integrations](https://bigbluebutton.org/schools/integrations/) to try find us on your solution marketplace!

 No luck? No worries!!

BigBlueButton is [LTI](https://www.imsglobal.org/activity/learning-tools-interoperability) 1.0 certified just follow the step on how to [install BigBlueButton LTI](#install-bigbluebutton-lti-framework)!
 Your users will feel that your platform has BigBlueButton embedded when it's not!
 Your same BigBlueButton server can be used by multiple LMS platforms, Greenlight, APIs and your custom applications simultaneously!
 
* You can also [customize](https://docs.bigbluebutton.org/administration/customize) and [configure](https://docs.bigbluebutton.org/administration/bbb-conf) your BigBlueButton server!

* Your business is growing fast (we're happy for you!) and your all in one deployment isn't doing well?
Want to have a premium deployment of BigBlueButton at scale supervised by **BigBlueButton experts**?
Check [the list of official commercial support providers](https://bigbluebutton.org/commercial-support/) that could save your day!

* You're becoming the expert then BigBlueButton, [Greenlight](#install-greenlight), [BigBlueButton LTI](#install-bigbluebutton-lti-framework) and even the `bbb-install.sh` are all open source so why don't join us and become a contributor that leaves the mark? Check [contributing to BigBlueButton](https://docs.bigbluebutton.org/support/faq/#contributing-to-bigbluebutton) for more details.
 You can also help others in their BigBlueButton journey by [joining the community](#getting-help).
 
 * BigBlueButton recordings are getting out of hand?
  Learn about [linking recordings directory to different locations](#linking-varbigbluebutton-to-another-directory).

 * You want to keep your system private but you need to have a valid Let's encrypt certificate [check this for more details](#installing-in-a-private-network).


## Troubleshooting

### Getting help

If you have feedback on the script, or need help using it, please post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) mailing list with details of the issue (and include related information such as steps to reproduce the error).

If you encounter an error with the script (such as it not completing or throwing an error), please open a [GitHub issue](https://github.com/bigbluebutton/bbb-install/issues) and provide steps to reproduce the issue.


## Limitations

If you are running your BigBlueButton behind a firewall, such as on EC2, this script will not configure your firewall.  You'll need to [configure the firewall](#configuring-the-external-firewall) manually.

If you are upgrading from a very old version BigBlueButton (running on an older Operating System), we recommend you set up a new server for BigBlueButton's latest stable version and copy over your configuration settings and [transfer recordings](https://docs.bigbluebutton.org/admin/customize.html#transfer-recordings) from the previous version.
