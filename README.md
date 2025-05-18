# Home Assistant Add-on: qBittorrent-Wireguard

_qBittorrent and WireGuard with automatic Port Forwarding for ProtonVPN._

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg

## [qBittorrent](https://github.com/qbittorrent/qBittorrent) and WireGuard

Addon runs [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox (headless) version 5.1.0 client while connecting to WireGuard with iptables killswitch to prevent IP leakage when the tunnel goes down.

## Specs and Features
* Base: Alpine Linux
* Supports amd64 and arm64 architectures.
* [qBittorrent](https://github.com/qbittorrent/qBittorrent) from the official Docker repo (qbittorrentofficial/qbittorrent-nox:5.1.0-1)
* Uses the Wireguard VPN software.
* IP tables killswitch to prevent IP leaking when VPN connection fails.
* Configurable UID and GID for config files and /share/qBittorrent for qBittorrent.
* BitTorrent port 8999 exposed by default.
* Automatically restarts the qBittorrent process in the event of it crashing.
* Adds [VueTorrent](https://github.com/VueTorrent/VueTorrent) (alternate web UI) which can be enabled (or not) by the user.
* Works with Proton VPN's port forward VPN servers to automatically enable forwarding in your container, and automatically sets the connection port in qBittorrent to match the forwarded port.


## Credits
* [tenseiken/docker-qbittorrent-wireguard](https://github.com/tenseiken/docker-qbittorrent-wireguard)
* [DyonR/docker-qBittorrentvpn](https://github.com/DyonR/docker-qbittorrentvpn)
* [MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
* [DyonR/jackettvpn](https://github.com/DyonR/jackettvpn)
