<img width="1012" alt="bbb-install-banner" src="https://user-images.githubusercontent.com/1273169/141152865-f497c883-6c96-41c6-9040-613b0858878a.png">

# bbb-install

`bbb-install.sh` is a shell script that installs, upgrades, and configures a BigBlueButton server in under 20 minutes. Use it on a fresh Ubuntu server that meets the [minimum requirements](https://docs.bigbluebutton.org/administration/install#minimum-server-requirements) and has a fully qualified domain name (FQDN) pointing to it.

## Quickstart

Log in as root to a fresh Ubuntu server and run:

```
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v4.0.x-release/bbb-install.sh | bash -s -- -v noble-400 -s bbb.example.com -e info@example.com -w
```

Substitute your own hostname and email. For the full list of flags and more example command lines:

```
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v4.0.x-release/bbb-install.sh | bash -s -- -h
```

The `-v` flag selects the version line, e.g. `noble-400` for BigBlueButton 4.0 on Ubuntu 24.04. Re-running the same command later upgrades to the latest iteration of that line; change `-v` to jump to a newer line.

## Before you run the script

There are three things the script cannot do for you.

### DNS

Configure an FQDN (such as `bbb.example.com`) with an A record resolving to your server's public IPv4 address. Verify before running:

```
dig bbb.example.com @8.8.8.8
```

HTTPS is required — browsers block access to microphone, camera, and screen-share over plain HTTP, so `-s` and `-e` are effectively mandatory for any usable install.

### Server sizing

BigBlueButton is CPU- and bandwidth-intensive. See the [minimum requirements](https://docs.bigbluebutton.org/administration/install#minimum-server-requirements) for guidance.

- **Dedicated public IP:** Digital Ocean, Hetzner.
- **Behind NAT:** Scaleway, Google Compute Engine, Amazon EC2 (`c5.2xlarge`+ recommended), Azure. `bbb-install.sh` detects internal/external addresses automatically, but you need to configure the external firewall yourself.

### External firewall

If your server is behind an external firewall (AWS security group, Azure NSG, GCP rules, corporate firewall), open the following inbound ports:

| Port           | Protocol | Purpose |
| -------------- | -------- | ------- |
| 22             | TCP      | SSH |
| 80, 443        | TCP      | HTTP / HTTPS |
| 16384 – 32768  | UDP      | FreeSWITCH / WebRTC media |

Amazon EC2 users should also assign an [Elastic IP](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html) so the server's address is stable across reboots.

Even with an external firewall in place, pass `-w` to install UFW on the BigBlueButton host itself — defense in depth.

<details>
<summary>Screenshots: Azure and GCE firewall rules</summary>

Microsoft Azure inbound rules:

![Azure firewall](images/azure-firewall.png?raw=true)

Google Compute Engine — allow 80/443 at instance creation:

![GCE 80-443](images/gce-80-443.png?raw=true)

Then add a firewall rule for UDP 16384-32768:

![GCE firewall](images/gce-firewall.png?raw=true)

</details>

## Common scenarios

Run `bbb-install.sh -h` for every flag and a copy-pasteable command for each of the scenarios below.

### Greenlight

[Greenlight](https://docs.bigbluebutton.org/greenlight/v3/install) is BigBlueButton's official room-manager web UI. Pass `-g` to install it; add `-k` to also install Keycloak for external authentication. After install, Greenlight is served at `https://<your-hostname>/`.

### BigBlueButton LTI framework

The [LTI framework](https://github.com/bigbluebutton/bbb-lti-broker) integrates BigBlueButton with any LTI 1.0 Learning Management System. Install with `-t <KEY>:<SECRET>`, where those values are used by your LMS to authenticate with the broker. Re-running with the same key rotates its secret; a new key adds another consumer. Check the [list of native integrations](https://bigbluebutton.org/schools/integrations/) first — many LMS platforms integrate directly without LTI.

### Private networks

For servers not reachable from the public internet, add `-x` to use Let's Encrypt's manual DNS-01 challenge. You'll be prompted to create a `_acme-challenge.<hostname>` TXT record during install. Certificates expire after 90 days and must be renewed manually — certbot emails you before expiry.

### External TURN server

Most deployments work with BigBlueButton's built-in TURN configuration. Set up a separate TURN server only if your users are behind restrictive firewalls that block UDP.

A TURN host needs its own FQDN (with A and AAAA records), its own email for Let's Encrypt, and a shared secret (any 8–16 character random string). The installation is two steps: (1) install coturn on a separate host with `-c <fqdn>:<secret> -e <email>` and no `-v`; (2) point BigBlueButton at it by re-running the BBB install with `-c <fqdn>:<secret>` appended. One TURN server can be shared across multiple BigBlueButton servers. See `-h` for the exact commands.

### Storing recordings on a separate volume

`/var/bigbluebutton` can grow large. Pass `-m /mnt/recordings` to symlink it to a separately-mounted volume.

## Upgrading

Re-run the same `bbb-install.sh` command you used to install. The script upgrades BigBlueButton and all installed add-ons (Greenlight, Keycloak, LTI) to the latest stable version of the same version line. To jump to a newer line, change `-v`.

Updates are announced on the [bigbluebutton-dev](https://groups.google.com/forum/#!forum/bigbluebutton-dev) mailing list.

## Troubleshooting

If the script fails or misbehaves, open a [GitHub issue](https://github.com/bigbluebutton/bbb-install/issues) with steps to reproduce.

For help with BigBlueButton itself, post to the [BigBlueButton Setup](https://bigbluebutton.org/support/community/) community.

## Limitations

- If you are behind an external firewall, `bbb-install.sh` won't configure it. See [External firewall](#external-firewall).
- Cross-major-OS upgrades are not supported. If you're moving from an older Ubuntu release, install on a fresh server and [transfer your recordings](https://docs.bigbluebutton.org/admin/customize.html#transfer-recordings).
